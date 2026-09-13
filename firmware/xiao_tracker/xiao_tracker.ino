/*
  ==============================================================
  XIAO nRF52840 Sense - Phase 2 Workout Tracker
  ==============================================================
  Protocol Version: 2.0.0

  Features:
    - 20-byte binary BLE protocol (matches mobile app)
    - 5 GATT characteristics: DeviceInfo, Motion, SetState, Control, ControlAck
    - Workout state machine: idle → counting → paused → ended
    - Bidirectional command/ACK protocol
    - Duplicate-command protection (4-slot ACK cache)
    - Non-blocking gyroscope calibration
    - Timestamp-based active duration tracking
    - 1 Hz heartbeat SetState notifications
    - setStreaming opcode to start/stop motion notifications
    - Rep counting gated by workout state (counting only)
    - 50 Hz IMU sampling with gyroscope bias calibration

  Board:
    Seeed Studio XIAO nRF52840 Sense

  Libraries:
    Seeed Arduino LSM6DS3
    ArduinoBLE

  IMPORTANT:
    Keep the XIAO completely still for ~3 seconds after startup
    while the gyroscope calibrates.
  ==============================================================
*/

#include <ArduinoBLE.h>
#include <LSM6DS3.h>
#include <Wire.h>
#include <math.h>

// ============================================================
// IMU
// ============================================================

LSM6DS3 myIMU(I2C_MODE, 0x6A);

// ============================================================
// SAMPLING
// ============================================================

const uint32_t SAMPLE_RATE_HZ = 50;
const uint32_t SAMPLE_INTERVAL_US = 1000000UL / SAMPLE_RATE_HZ;

uint32_t previousSampleUs = 0;

// ============================================================
// SERIAL OPTIONS
// ============================================================

const bool SERIAL_SHOW_TIME = false;

// ============================================================
// FIRMWARE VERSION
// ============================================================

const uint8_t FW_MAJOR = 2;
const uint8_t FW_MINOR = 0;
const uint8_t FW_PATCH = 0;

// ============================================================
// BLE UUIDs (match mobile app BleUuids)
// ============================================================

#define SERVICE_UUID        "9f7c0001-7b6a-4f7d-9e2a-3c1d5b8a6200"
#define DEVICE_INFO_UUID    "9f7c0002-7b6a-4f7d-9e2a-3c1d5b8a6200"
#define MOTION_UUID         "9f7c0003-7b6a-4f7d-9e2a-3c1d5b8a6200"
#define SET_STATE_UUID      "9f7c0004-7b6a-4f7d-9e2a-3c1d5b8a6200"
#define CONTROL_UUID        "9f7c0005-7b6a-4f7d-9e2a-3c1d5b8a6200"
#define CONTROL_ACK_UUID    "9f7c0006-7b6a-4f7d-9e2a-3c1d5b8a6200"

// ============================================================
// BLE Service & Characteristics
// ============================================================

BLEService workoutService(SERVICE_UUID);

BLECharacteristic deviceInfoChar(DEVICE_INFO_UUID, BLERead, 20);
BLECharacteristic motionChar(MOTION_UUID, BLENotify, 20);
BLECharacteristic setStateChar(SET_STATE_UUID, BLERead | BLENotify, 20);
BLECharacteristic controlChar(CONTROL_UUID, BLEWrite, 20);
BLECharacteristic controlAckChar(CONTROL_ACK_UUID, BLENotify, 20);

// ============================================================
// WORKOUT STATE MACHINE
// ============================================================

enum WorkoutState : uint8_t {
  STATE_IDLE              = 0,
  STATE_COUNTING          = 1,
  STATE_PAUSED            = 2,
  STATE_ENDED             = 3,
  STATE_CALIBRATING       = 4,
  STATE_CALIBRATION_FAILED = 5
};

WorkoutState currentState = STATE_IDLE;
uint16_t stateRevision = 0;

// ============================================================
// PROTOCOL OPCODES
// ============================================================

enum Opcode : uint8_t {
  OPCODE_NONE           = 0,
  OPCODE_START_SET      = 1,
  OPCODE_PAUSE_SET      = 2,
  OPCODE_RESUME_SET     = 3,
  OPCODE_END_SET        = 4,
  OPCODE_CALIBRATE      = 5,
  OPCODE_SET_STREAMING  = 6
};

// ============================================================
// CONTROL RESULT CODES
// ============================================================

enum ResultCode : uint8_t {
  RESULT_APPLIED          = 0,
  RESULT_INVALID_STATE    = 1,
  RESULT_UNSUPPORTED      = 2,
  RESULT_INVALID_ARGUMENT = 3,
  RESULT_WRONG_BOOT       = 4,
  RESULT_BUSY             = 5,
  RESULT_INTERNAL_ERROR   = 6
};

// ============================================================
// DEVICE IDENTITY
// ============================================================

uint32_t bootId = 0;
uint32_t stableDeviceId = 0;

// ============================================================
// SET TRACKING
// ============================================================

uint32_t wireSetId = 0;
uint32_t cumulativeReps = 0;

// Timestamp-based duration tracking (Req #4)
uint32_t countingEnteredMs = 0;
uint32_t accumulatedDurationMs = 0;

// Heartbeat timer (Req #5)
uint32_t lastHeartbeatMs = 0;

// Motion streaming (Req #7)
bool motionStreamingEnabled = true;

// Motion sequence counter
uint16_t motionSequence = 0;

// Calibration flag
bool isCalibrated = false;

// ============================================================
// DUPLICATE-COMMAND CACHE (Req #2)
// ============================================================

struct CachedAck {
  uint16_t commandId;
  uint8_t  frame[20];
  bool     valid;
};

CachedAck ackCache[4] = {{0, {0}, false}, {0, {0}, false}, {0, {0}, false}, {0, {0}, false}};
uint8_t ackCacheIndex = 0;

// ============================================================
// NON-BLOCKING CALIBRATION STATE (Req #6)
// ============================================================

bool   calibInProgress = false;
int    calibSampleCount = 0;
double calibSum[3]    = {0, 0, 0};
double calibSumSq[3]  = {0, 0, 0};

// ============================================================
// GYROSCOPE CALIBRATION
// ============================================================

const int CALIBRATION_SAMPLES = 150;

float gyroBias[3]  = {0, 0, 0};
float gyroNoise[3] = {0, 0, 0};

// ============================================================
// GYROSCOPE FILTER
// ============================================================

float filteredGyro[3] = {0, 0, 0};

const float FILTER_ALPHA = 0.70;

// ============================================================
// REP DETECTION
// ============================================================

enum RepState {
  WAITING_FOR_MOVEMENT,
  MOVING_UP,
  MOVING_DOWN
};

RepState repState = WAITING_FOR_MOVEMENT;

int activeAxis = -1;
int upDirection = 1;

float startThreshold[3];
float stopThreshold[3];

uint32_t repStartTime = 0;
uint32_t phaseStartTime = 0;

float peakUp = 0;
float peakDown = 0;

int movementConfirm = 0;
int reverseConfirm = 0;
int stableConfirm = 0;
int candidateAxis = -1;
int candidateDirection = 1;

const int START_CONFIRM_SAMPLES = 3;
const int REVERSE_CONFIRM_SAMPLES = 3;
const int STABLE_CONFIRM_SAMPLES = 5;

const uint32_t MIN_PHASE_TIME_MS = 250;
const uint32_t MIN_REP_TIME_MS = 700;
const uint32_t MAX_REP_TIME_MS = 10000;

// ============================================================
// UTILITY
// ============================================================

int16_t safeInt16(float value) {
  if (value > 32767.0) return 32767;
  if (value < -32768.0) return -32768;
  return (int16_t)round(value);
}

// ============================================================
// ACTIVE DURATION HELPER (Req #4)
// Single source of truth — timestamp-based
// ============================================================

uint32_t getActiveDurationMs() {
  if (currentState == STATE_COUNTING) {
    return accumulatedDurationMs + (millis() - countingEnteredMs);
  }
  return accumulatedDurationMs;
}

// ============================================================
// FRAME ENCODING — DeviceInfo (20 bytes)
// ============================================================

void encodeDeviceInfo(uint8_t buf[20]) {
  memset(buf, 0, 20);
  buf[0] = 1;                                        // Protocol version
  buf[1] = 0x07;                                     // Capability mask: motion + setControl + calibration
  buf[2] = (uint8_t)(SAMPLE_RATE_HZ & 0xFF);         // Sample rate LE low
  buf[3] = (uint8_t)((SAMPLE_RATE_HZ >> 8) & 0xFF);  // Sample rate LE high
  // Boot ID (bytes 4-7, LE)
  buf[4] = (uint8_t)(bootId & 0xFF);
  buf[5] = (uint8_t)((bootId >> 8) & 0xFF);
  buf[6] = (uint8_t)((bootId >> 16) & 0xFF);
  buf[7] = (uint8_t)((bootId >> 24) & 0xFF);
  // Stable Device ID (bytes 8-11, LE)
  buf[8]  = (uint8_t)(stableDeviceId & 0xFF);
  buf[9]  = (uint8_t)((stableDeviceId >> 8) & 0xFF);
  buf[10] = (uint8_t)((stableDeviceId >> 16) & 0xFF);
  buf[11] = (uint8_t)((stableDeviceId >> 24) & 0xFF);
  // Firmware version
  buf[12] = FW_MAJOR;
  buf[13] = FW_MINOR;
  buf[14] = FW_PATCH;
  buf[15] = 0;  // Reserved
  // Supported profile mask (bytes 16-19, LE) — bit 1 = Curl Profile 1
  uint32_t profileMask = 0x02;
  buf[16] = (uint8_t)(profileMask & 0xFF);
  buf[17] = (uint8_t)((profileMask >> 8) & 0xFF);
  buf[18] = (uint8_t)((profileMask >> 16) & 0xFF);
  buf[19] = (uint8_t)((profileMask >> 24) & 0xFF);
}

// ============================================================
// FRAME ENCODING — Motion (20 bytes)
// ============================================================

void encodeMotionFrame(uint8_t buf[20], uint16_t seq, uint32_t uptimeMs,
                       float ax, float ay, float az,
                       float gx, float gy, float gz) {
  memset(buf, 0, 20);
  buf[0] = 1;  // Protocol version

  // Flags: bit 0 = calibrated, bit 1 = clipped
  uint8_t flags = 0;
  if (isCalibrated) flags |= 0x01;
  // Check if any axis is near saturation (accel > ±3.9g or gyro > ±3200 deg/s)
  if (fabs(ax) > 3.9 || fabs(ay) > 3.9 || fabs(az) > 3.9 ||
      fabs(gx) > 3200 || fabs(gy) > 3200 || fabs(gz) > 3200) {
    flags |= 0x02;
  }
  buf[1] = flags;

  // Sequence (bytes 2-3, LE)
  buf[2] = (uint8_t)(seq & 0xFF);
  buf[3] = (uint8_t)((seq >> 8) & 0xFF);

  // Uptime ms (bytes 4-7, LE)
  buf[4] = (uint8_t)(uptimeMs & 0xFF);
  buf[5] = (uint8_t)((uptimeMs >> 8) & 0xFF);
  buf[6] = (uint8_t)((uptimeMs >> 16) & 0xFF);
  buf[7] = (uint8_t)((uptimeMs >> 24) & 0xFF);

  // Accel X (bytes 8-9, int16 LE, g × 1000)
  int16_t axI = safeInt16(ax * 1000.0);
  buf[8]  = (uint8_t)(axI & 0xFF);
  buf[9]  = (uint8_t)((axI >> 8) & 0xFF);

  // Accel Y (bytes 10-11)
  int16_t ayI = safeInt16(ay * 1000.0);
  buf[10] = (uint8_t)(ayI & 0xFF);
  buf[11] = (uint8_t)((ayI >> 8) & 0xFF);

  // Accel Z (bytes 12-13)
  int16_t azI = safeInt16(az * 1000.0);
  buf[12] = (uint8_t)(azI & 0xFF);
  buf[13] = (uint8_t)((azI >> 8) & 0xFF);

  // Gyro X (bytes 14-15, int16 LE, deg/s × 10)
  int16_t gxI = safeInt16(gx * 10.0);
  buf[14] = (uint8_t)(gxI & 0xFF);
  buf[15] = (uint8_t)((gxI >> 8) & 0xFF);

  // Gyro Y (bytes 16-17)
  int16_t gyI = safeInt16(gy * 10.0);
  buf[16] = (uint8_t)(gyI & 0xFF);
  buf[17] = (uint8_t)((gyI >> 8) & 0xFF);

  // Gyro Z (bytes 18-19)
  int16_t gzI = safeInt16(gz * 10.0);
  buf[18] = (uint8_t)(gzI & 0xFF);
  buf[19] = (uint8_t)((gzI >> 8) & 0xFF);
}

// ============================================================
// FRAME ENCODING — SetState (20 bytes)
// ============================================================

void encodeSetState(uint8_t buf[20]) {
  memset(buf, 0, 20);
  buf[0] = 1;  // Protocol version
  buf[1] = (uint8_t)currentState;

  // State revision (bytes 2-3, LE)
  buf[2] = (uint8_t)(stateRevision & 0xFF);
  buf[3] = (uint8_t)((stateRevision >> 8) & 0xFF);

  // Boot ID (bytes 4-7, LE)
  buf[4] = (uint8_t)(bootId & 0xFF);
  buf[5] = (uint8_t)((bootId >> 8) & 0xFF);
  buf[6] = (uint8_t)((bootId >> 16) & 0xFF);
  buf[7] = (uint8_t)((bootId >> 24) & 0xFF);

  // Wire Set ID (bytes 8-11, LE)
  buf[8]  = (uint8_t)(wireSetId & 0xFF);
  buf[9]  = (uint8_t)((wireSetId >> 8) & 0xFF);
  buf[10] = (uint8_t)((wireSetId >> 16) & 0xFF);
  buf[11] = (uint8_t)((wireSetId >> 24) & 0xFF);

  // Cumulative reps (bytes 12-15, LE)
  buf[12] = (uint8_t)(cumulativeReps & 0xFF);
  buf[13] = (uint8_t)((cumulativeReps >> 8) & 0xFF);
  buf[14] = (uint8_t)((cumulativeReps >> 16) & 0xFF);
  buf[15] = (uint8_t)((cumulativeReps >> 24) & 0xFF);

  // Active duration ms (bytes 16-19, LE)
  uint32_t dur = getActiveDurationMs();
  buf[16] = (uint8_t)(dur & 0xFF);
  buf[17] = (uint8_t)((dur >> 8) & 0xFF);
  buf[18] = (uint8_t)((dur >> 16) & 0xFF);
  buf[19] = (uint8_t)((dur >> 24) & 0xFF);
}

// ============================================================
// FRAME ENCODING — ControlAck (20 bytes)
// ============================================================

void encodeControlAck(uint8_t buf[20], uint8_t opcode, uint16_t cmdId, uint8_t resultCode) {
  memset(buf, 0, 20);
  buf[0] = 1;  // Protocol version
  buf[1] = opcode;

  // Command ID (bytes 2-3, LE)
  buf[2] = (uint8_t)(cmdId & 0xFF);
  buf[3] = (uint8_t)((cmdId >> 8) & 0xFF);

  // Boot ID (bytes 4-7, LE)
  buf[4] = (uint8_t)(bootId & 0xFF);
  buf[5] = (uint8_t)((bootId >> 8) & 0xFF);
  buf[6] = (uint8_t)((bootId >> 16) & 0xFF);
  buf[7] = (uint8_t)((bootId >> 24) & 0xFF);

  // Wire Set ID (bytes 8-11, LE)
  buf[8]  = (uint8_t)(wireSetId & 0xFF);
  buf[9]  = (uint8_t)((wireSetId >> 8) & 0xFF);
  buf[10] = (uint8_t)((wireSetId >> 16) & 0xFF);
  buf[11] = (uint8_t)((wireSetId >> 24) & 0xFF);

  // Result code
  buf[12] = resultCode;
  // Current state
  buf[13] = (uint8_t)currentState;
  // Reserved (bytes 14-15)
  buf[14] = 0;
  buf[15] = 0;

  // Cumulative reps (bytes 16-19, LE)
  buf[16] = (uint8_t)(cumulativeReps & 0xFF);
  buf[17] = (uint8_t)((cumulativeReps >> 8) & 0xFF);
  buf[18] = (uint8_t)((cumulativeReps >> 16) & 0xFF);
  buf[19] = (uint8_t)((cumulativeReps >> 24) & 0xFF);
}

// ============================================================
// NOTIFICATION HELPERS
// ============================================================

void notifySetState() {
  uint8_t buf[20];
  encodeSetState(buf);
  setStateChar.writeValue(buf, 20);
}

void sendControlAck(uint8_t opcode, uint16_t cmdId, uint8_t resultCode) {
  uint8_t buf[20];
  encodeControlAck(buf, opcode, cmdId, resultCode);
  controlAckChar.writeValue(buf, 20);

  // Cache this ACK for duplicate protection (Req #2)
  ackCache[ackCacheIndex].commandId = cmdId;
  memcpy(ackCache[ackCacheIndex].frame, buf, 20);
  ackCache[ackCacheIndex].valid = true;
  ackCacheIndex = (ackCacheIndex + 1) % 4;
}

// ============================================================
// DUPLICATE-COMMAND CHECK (Req #2)
// Returns true if duplicate found (and re-sends cached ACK)
// ============================================================

bool checkAndReplayDuplicate(uint16_t cmdId) {
  for (int i = 0; i < 4; i++) {
    if (ackCache[i].valid && ackCache[i].commandId == cmdId) {
      // Re-send cached ACK without re-executing the command
      controlAckChar.writeValue(ackCache[i].frame, 20);
      return true;
    }
  }
  return false;
}

// ============================================================
// RESET REP DETECTOR
// ============================================================

void resetRepDetector() {
  repState = WAITING_FOR_MOVEMENT;
  activeAxis = -1;
  movementConfirm = 0;
  reverseConfirm = 0;
  stableConfirm = 0;
  candidateAxis = -1;
  peakUp = 0;
  peakDown = 0;
}

// ============================================================
// REP DETECTOR (Req #3)
// Returns true when a complete rep is detected.
// Does NOT increment any counter internally.
// ============================================================

bool updateRepCounter(float gyro[3]) {
  uint32_t now = millis();

  if (repState == WAITING_FOR_MOVEMENT) {
    int strongestAxis = -1;
    float strongestScore = 0;

    for (int axis = 0; axis < 3; axis++) {
      float score = fabs(gyro[axis]) / startThreshold[axis];
      if (score > strongestScore) {
        strongestScore = score;
        strongestAxis = axis;
      }
    }

    if (strongestAxis >= 0 && strongestScore >= 1.0) {
      int direction = gyro[strongestAxis] >= 0 ? 1 : -1;

      if (strongestAxis == candidateAxis && direction == candidateDirection) {
        movementConfirm++;
      } else {
        candidateAxis = strongestAxis;
        candidateDirection = direction;
        movementConfirm = 1;
      }

      if (movementConfirm >= START_CONFIRM_SAMPLES) {
        activeAxis = candidateAxis;
        upDirection = candidateDirection;
        repState = MOVING_UP;
        repStartTime = now;
        phaseStartTime = now;
        peakUp = fabs(gyro[activeAxis]);
        reverseConfirm = 0;
        stableConfirm = 0;
      }
    } else {
      movementConfirm = 0;
      candidateAxis = -1;
    }
    return false;
  }

  float velocity = gyro[activeAxis] * upDirection;

  if (repState == MOVING_UP) {
    if (velocity > peakUp) peakUp = velocity;

    if (velocity < -startThreshold[activeAxis]) {
      reverseConfirm++;
    } else {
      reverseConfirm = 0;
    }

    if (reverseConfirm >= REVERSE_CONFIRM_SAMPLES && now - phaseStartTime >= MIN_PHASE_TIME_MS) {
      repState = MOVING_DOWN;
      phaseStartTime = now;
      peakDown = velocity;
      stableConfirm = 0;
      return false;
    }

    if (now - repStartTime > MAX_REP_TIME_MS) {
      resetRepDetector();
    }
    return false;
  }

  if (repState == MOVING_DOWN) {
    if (velocity < peakDown) peakDown = velocity;

    if (fabs(velocity) < stopThreshold[activeAxis]) {
      stableConfirm++;
    } else {
      stableConfirm = 0;
    }

    bool validTiming = (now - repStartTime >= MIN_REP_TIME_MS) && (now - phaseStartTime >= MIN_PHASE_TIME_MS);
    bool validDirection = (peakUp >= startThreshold[activeAxis]) && (peakDown <= -startThreshold[activeAxis]);

    if (stableConfirm >= STABLE_CONFIRM_SAMPLES && validTiming && validDirection) {
      resetRepDetector();
      return true;  // REP DETECTED — caller increments cumulativeReps
    }

    if (now - repStartTime > MAX_REP_TIME_MS) {
      resetRepDetector();
    }
  }

  return false;
}

// ============================================================
// BLOCKING GYROSCOPE CALIBRATION (startup only)
// ============================================================

void calibrateGyroscope() {
  Serial.println();
  Serial.println("================================");
  Serial.println("GYROSCOPE CALIBRATION");
  Serial.println("Keep XIAO completely still...");
  Serial.println("================================");

  double sum[3] = {0, 0, 0};
  double sumSquares[3] = {0, 0, 0};

  for (int i = 0; i < CALIBRATION_SAMPLES; i++) {
    float gx = myIMU.readFloatGyroX();
    float gy = myIMU.readFloatGyroY();
    float gz = myIMU.readFloatGyroZ();

    float values[3] = {gx, gy, gz};

    for (int axis = 0; axis < 3; axis++) {
      sum[axis] += values[axis];
      sumSquares[axis] += values[axis] * values[axis];
    }
    delay(20);
  }

  finishCalibration(sum, sumSquares);
}

// ============================================================
// FINISH CALIBRATION (shared by blocking & non-blocking)
// ============================================================

void finishCalibration(double sum[3], double sumSquares[3]) {
  for (int axis = 0; axis < 3; axis++) {
    gyroBias[axis] = sum[axis] / CALIBRATION_SAMPLES;
    float variance = (sumSquares[axis] / CALIBRATION_SAMPLES) - gyroBias[axis] * gyroBias[axis];
    if (variance < 0) variance = 0;
    gyroNoise[axis] = sqrt(variance);

    startThreshold[axis] = max(1.0f, gyroNoise[axis] * 6.0f);
    stopThreshold[axis]  = max(0.35f, gyroNoise[axis] * 2.5f);
  }

  isCalibrated = true;

  Serial.println();
  Serial.println("Calibration complete.");

  Serial.print("GX bias: "); Serial.println(gyroBias[0], 3);
  Serial.print("GY bias: "); Serial.println(gyroBias[1], 3);
  Serial.print("GZ bias: "); Serial.println(gyroBias[2], 3);
  Serial.println();
  Serial.print("GX rep threshold: "); Serial.println(startThreshold[0], 3);
  Serial.print("GY rep threshold: "); Serial.println(startThreshold[1], 3);
  Serial.print("GZ rep threshold: "); Serial.println(startThreshold[2], 3);
  Serial.println();
}

// ============================================================
// CONTROL COMMAND HANDLER (BLE write callback)
// ============================================================

void onControlWritten(BLEDevice central, BLECharacteristic characteristic) {
  // Read the 20-byte control frame
  uint8_t cmdBuf[20];
  int len = characteristic.valueLength();
  if (len != 20) return;
  memcpy(cmdBuf, characteristic.value(), 20);

  // Parse fields
  uint8_t  version   = cmdBuf[0];
  uint8_t  opcode    = cmdBuf[1];
  uint16_t cmdId     = (uint16_t)cmdBuf[2] | ((uint16_t)cmdBuf[3] << 8);
  uint32_t expBootId = (uint32_t)cmdBuf[4]  | ((uint32_t)cmdBuf[5] << 8)  |
                       ((uint32_t)cmdBuf[6] << 16) | ((uint32_t)cmdBuf[7] << 24);
  uint32_t cmdWireSetId = (uint32_t)cmdBuf[8]  | ((uint32_t)cmdBuf[9] << 8)  |
                          ((uint32_t)cmdBuf[10] << 16) | ((uint32_t)cmdBuf[11] << 24);
  uint32_t argument  = (uint32_t)cmdBuf[12] | ((uint32_t)cmdBuf[13] << 8) |
                       ((uint32_t)cmdBuf[14] << 16) | ((uint32_t)cmdBuf[15] << 24);

  Serial.print("CMD: opcode="); Serial.print(opcode);
  Serial.print(" cmdId="); Serial.print(cmdId);
  Serial.print(" wireSetId="); Serial.println(cmdWireSetId);

  // Check protocol version
  if (version != 1) {
    sendControlAck(opcode, cmdId, RESULT_UNSUPPORTED);
    return;
  }

  // Duplicate-command check (Req #2)
  if (checkAndReplayDuplicate(cmdId)) {
    Serial.println("  -> Duplicate command, replayed cached ACK");
    return;
  }

  // Boot ID validation (skip for setStreaming which doesn't require it)
  if (opcode != OPCODE_SET_STREAMING && expBootId != bootId) {
    sendControlAck(opcode, cmdId, RESULT_WRONG_BOOT);
    notifySetState();
    Serial.println("  -> Wrong boot ID");
    return;
  }

  ResultCode result = RESULT_APPLIED;

  switch (opcode) {
    case OPCODE_START_SET:
      // Accept from IDLE or ENDED (Req #1)
      if (currentState != STATE_IDLE && currentState != STATE_ENDED) {
        result = RESULT_INVALID_STATE;
        break;
      }
      wireSetId = cmdWireSetId;
      cumulativeReps = 0;
      accumulatedDurationMs = 0;
      countingEnteredMs = millis();
      lastHeartbeatMs = millis();
      currentState = STATE_COUNTING;
      stateRevision++;
      resetRepDetector();
      Serial.println("  -> SET STARTED");
      break;

    case OPCODE_PAUSE_SET:
      if (currentState != STATE_COUNTING) {
        result = RESULT_INVALID_STATE;
        break;
      }
      // Accumulate elapsed counting time (Req #4)
      accumulatedDurationMs += (millis() - countingEnteredMs);
      currentState = STATE_PAUSED;
      stateRevision++;
      Serial.println("  -> SET PAUSED");
      break;

    case OPCODE_RESUME_SET:
      if (currentState != STATE_PAUSED) {
        result = RESULT_INVALID_STATE;
        break;
      }
      countingEnteredMs = millis();
      currentState = STATE_COUNTING;
      stateRevision++;
      Serial.println("  -> SET RESUMED");
      break;

    case OPCODE_END_SET:
      if (currentState != STATE_COUNTING && currentState != STATE_PAUSED) {
        result = RESULT_INVALID_STATE;
        break;
      }
      // Finalize duration
      if (currentState == STATE_COUNTING) {
        accumulatedDurationMs += (millis() - countingEnteredMs);
      }
      // State stays ENDED — no auto-reset to IDLE (Req #1)
      currentState = STATE_ENDED;
      stateRevision++;
      Serial.print("  -> SET ENDED, reps="); Serial.println(cumulativeReps);
      break;

    case OPCODE_CALIBRATE:
      if (currentState == STATE_CALIBRATING) {
        result = RESULT_BUSY;
        break;
      }
      if (currentState != STATE_IDLE) {
        result = RESULT_INVALID_STATE;
        break;
      }
      // Non-blocking calibration: set flag, main loop does the work (Req #6)
      calibInProgress = true;
      calibSampleCount = 0;
      memset(calibSum, 0, sizeof(calibSum));
      memset(calibSumSq, 0, sizeof(calibSumSq));
      currentState = STATE_CALIBRATING;
      stateRevision++;
      Serial.println("  -> CALIBRATION STARTED (non-blocking)");
      break;

    case OPCODE_SET_STREAMING:
      // Fully defined (Req #7): arg 1 = start, arg 0 = stop
      if (argument == 1) {
        motionStreamingEnabled = true;
        Serial.println("  -> STREAMING ON");
      } else if (argument == 0) {
        motionStreamingEnabled = false;
        Serial.println("  -> STREAMING OFF");
      } else {
        result = RESULT_INVALID_ARGUMENT;
      }
      // Does not change workout state
      break;

    default:
      result = RESULT_UNSUPPORTED;
      break;
  }

  // Send ACK (also caches it for duplicate protection)
  sendControlAck(opcode, cmdId, (uint8_t)result);

  // Notify SetState on state changes (Req #5)
  notifySetState();
}

// ============================================================
// SETUP
// ============================================================

void setup() {
  Serial.begin(115200);
  delay(1500);

  Serial.println();
  Serial.println("===============================");
  Serial.println("XIAO WORKOUT TRACKER");
  Serial.println("Phase 2 Protocol v2.0.0");
  Serial.println("===============================");

  // ---- Generate Boot ID from real entropy (Req #9) ----
  uint32_t entropy = 0;
  for (int i = 0; i < 32; i++) {
    entropy = (entropy << 1) | (analogRead(A0) & 1);
    delayMicroseconds(50);
  }
  randomSeed(entropy ^ micros());
  bootId = (uint32_t)random() ^ (uint32_t)random();

  // Stable device ID from both FICR registers (Req #9)
  stableDeviceId = NRF_FICR->DEVICEID[0] ^ NRF_FICR->DEVICEID[1];

  Serial.print("Boot ID:   0x"); Serial.println(bootId, HEX);
  Serial.print("Device ID: 0x"); Serial.println(stableDeviceId, HEX);

  // ---- IMU Init ----
  if (myIMU.begin() != 0) {
    Serial.println("ERROR: IMU failed.");
    while (1) { delay(1000); }
  }
  Serial.println("IMU OK");

  // ---- Blocking calibration on startup ----
  calibrateGyroscope();

  // ---- BLE Init ----
  if (!BLE.begin()) {
    Serial.println("ERROR: BLE failed.");
    while (1) { delay(1000); }
  }

  BLE.setLocalName("XIAO-Tracker");
  BLE.setAdvertisedService(workoutService);

  // Add characteristics to service
  workoutService.addCharacteristic(deviceInfoChar);
  workoutService.addCharacteristic(motionChar);
  workoutService.addCharacteristic(setStateChar);
  workoutService.addCharacteristic(controlChar);
  workoutService.addCharacteristic(controlAckChar);

  BLE.addService(workoutService);

  // Register control write handler
  controlChar.setEventHandler(BLEWritten, onControlWritten);

  // Write initial DeviceInfo
  uint8_t diFrame[20];
  encodeDeviceInfo(diFrame);
  deviceInfoChar.writeValue(diFrame, 20);

  // Write initial SetState (idle)
  notifySetState();

  BLE.advertise();

  Serial.println();
  Serial.println("BLE advertising...");
  Serial.print("BLE address: ");
  Serial.println(BLE.address());
  Serial.println();
  Serial.println("Ready.");
  Serial.println();

  previousSampleUs = micros();
}

// ============================================================
// MAIN LOOP
// ============================================================

void loop() {
  BLE.poll();

  // ---- Non-blocking calibration (Req #6) ----
  if (calibInProgress) {
    float gxRaw = myIMU.readFloatGyroX();
    float gyRaw = myIMU.readFloatGyroY();
    float gzRaw = myIMU.readFloatGyroZ();

    calibSum[0] += gxRaw;
    calibSum[1] += gyRaw;
    calibSum[2] += gzRaw;
    calibSumSq[0] += gxRaw * gxRaw;
    calibSumSq[1] += gyRaw * gyRaw;
    calibSumSq[2] += gzRaw * gzRaw;
    calibSampleCount++;

    if (calibSampleCount >= CALIBRATION_SAMPLES) {
      finishCalibration(calibSum, calibSumSq);
      calibInProgress = false;
      currentState = STATE_IDLE;
      stateRevision++;
      notifySetState();
      Serial.println("Non-blocking calibration complete.");
    }

    // Don't process motion during calibration — need device still
    delay(20);  // Match calibration sample interval
    return;
  }

  // ---- 50 Hz sampling gate ----
  uint32_t currentUs = micros();

  if (currentUs - previousSampleUs < SAMPLE_INTERVAL_US) {
    return;
  }

  previousSampleUs += SAMPLE_INTERVAL_US;

  if (currentUs - previousSampleUs > SAMPLE_INTERVAL_US * 4) {
    previousSampleUs = currentUs;
  }

  // ---- Read IMU ----
  float ax = myIMU.readFloatAccelX();
  float ay = myIMU.readFloatAccelY();
  float az = myIMU.readFloatAccelZ();

  float gxRaw = myIMU.readFloatGyroX();
  float gyRaw = myIMU.readFloatGyroY();
  float gzRaw = myIMU.readFloatGyroZ();

  float gx = gxRaw - gyroBias[0];
  float gy = gyRaw - gyroBias[1];
  float gz = gzRaw - gyroBias[2];

  float gyroCorrected[3] = {gx, gy, gz};

  for (int axis = 0; axis < 3; axis++) {
    filteredGyro[axis] = FILTER_ALPHA * filteredGyro[axis] + (1.0 - FILTER_ALPHA) * gyroCorrected[axis];
  }

  // ---- Rep detection — gated by state, single increment point (Req #3) ----
  if (currentState == STATE_COUNTING) {
    if (updateRepCounter(filteredGyro)) {
      cumulativeReps++;       // THE ONLY increment site
      stateRevision++;
      notifySetState();       // Immediate notification on rep (Req #5)
      Serial.print(">>>> REP COUNT = "); Serial.println(cumulativeReps);
    }
  }

  // ---- Heartbeat notification ~1Hz (Req #5) ----
  if ((currentState == STATE_COUNTING || currentState == STATE_PAUSED) &&
      (millis() - lastHeartbeatMs >= 1000)) {
    notifySetState();
    lastHeartbeatMs = millis();
  }

  // ---- Serial output ----
  if (SERIAL_SHOW_TIME) {
    Serial.print("Time:"); Serial.print(millis()); Serial.print(",");
  }

  Serial.print("AX:"); Serial.print(ax, 4);
  Serial.print(",AY:"); Serial.print(ay, 4);
  Serial.print(",AZ:"); Serial.print(az, 4);
  Serial.print(",GX:"); Serial.print(gx, 4);
  Serial.print(",GY:"); Serial.print(gy, 4);
  Serial.print(",GZ:"); Serial.print(gz, 4);
  Serial.print(",STATE:"); Serial.print((int)currentState);
  Serial.print(",REPS:"); Serial.println(cumulativeReps);

  // ---- Motion frame — gated by streaming flag (Req #7) ----
  if (motionStreamingEnabled) {
    uint8_t motionFrame[20];
    encodeMotionFrame(motionFrame, motionSequence, millis(), ax, ay, az, gx, gy, gz);
    motionChar.writeValue(motionFrame, 20);
  }

  motionSequence++;
}
