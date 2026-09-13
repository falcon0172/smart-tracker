/*
 ==============================================================
 XIAO nRF52840 Sense - Phase 1 Workout Tracker
 ==============================================================
 Features:
   - Accelerometer AX / AY / AZ
   - Gyroscope GX / GY / GZ
   - 50 Hz sampling
   - Gyroscope startup calibration
   - Serial Monitor / Serial Plotter
   - Bluetooth Low Energy
   - 16-byte binary motion packet
   - Rep counting on the XIAO
   - BLE rep-count notifications

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

// false = ideal for Serial Plotter
// true  = adds timestamp to Serial output
//
// The BLE packet ALWAYS contains timestamp regardless.
const bool SERIAL_SHOW_TIME = false;

// ============================================================
// BLE UUIDs
// ============================================================
//
// Motion characteristic:
//     16-byte motion packet
//
// Rep characteristic:
//     2-byte rep count
//

#define SERVICE_UUID "6F4C0001-B5A3-F393-E0A9-E50E24DCCA9E"
#define MOTION_CHAR_UUID "6F4C0002-B5A3-F393-E0A9-E50E24DCCA9E"
#define REP_CHAR_UUID "6F4C0003-B5A3-F393-E0A9-E50E24DCCA9E"

BLEService workoutService(SERVICE_UUID);

BLECharacteristic motionCharacteristic(
    MOTION_CHAR_UUID,
    BLERead | BLENotify,
    16
);

BLECharacteristic repCharacteristic(
    REP_CHAR_UUID,
    BLERead | BLENotify,
    2
);

// ============================================================
// BLE MOTION PACKET
// ============================================================
//
// 16 bytes:
//
// Timestamp = 4 bytes
// AX        = 2 bytes
// AY        = 2 bytes
// AZ        = 2 bytes
// GX        = 2 bytes
// GY        = 2 bytes
// GZ        = 2 bytes
//
// Accelerometer:
//     g × 1000
//
// Gyroscope:
//     degrees/sec × 10
//
// Example:
//
// AX = 0.068g
//
// transmitted:
//
// 0.068 × 1000 = 68
//
// ============================================================

struct __attribute__((packed)) MotionPacket {
  uint32_t timestamp;
  int16_t ax;
  int16_t ay;
  int16_t az;
  int16_t gx;
  int16_t gy;
  int16_t gz;
};

// ============================================================
// GYROSCOPE CALIBRATION
// ============================================================

const int CALIBRATION_SAMPLES = 150;

float gyroBias[3] = {0, 0, 0};
float gyroNoise[3] = {0, 0, 0};

// ============================================================
// GYROSCOPE FILTER
// ============================================================

float filteredGyro[3] = {0, 0, 0};

// Higher = smoother
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

uint16_t repCount = 0;

// Axis selected for current repetition:
// 0 = GX, 1 = GY, 2 = GZ
int activeAxis = -1;

// Direction of first half of rep
int upDirection = 1;

// Thresholds calculated from startup sensor noise
float startThreshold[3];
float stopThreshold[3];

// Timing
uint32_t repStartTime = 0;
uint32_t phaseStartTime = 0;

// Movement peaks
float peakUp = 0;
float peakDown = 0;

// Detection counters
int movementConfirm = 0;
int reverseConfirm = 0;
int stableConfirm = 0;
int candidateAxis = -1;
int candidateDirection = 1;

// Require several consecutive samples
const int START_CONFIRM_SAMPLES = 3;
const int REVERSE_CONFIRM_SAMPLES = 3;
const int STABLE_CONFIRM_SAMPLES = 5;

// Timing protection
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
// GYROSCOPE CALIBRATION
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

  for (int axis = 0; axis < 3; axis++) {
    gyroBias[axis] = sum[axis] / CALIBRATION_SAMPLES;
    float variance = (sumSquares[axis] / CALIBRATION_SAMPLES) - gyroBias[axis] * gyroBias[axis];
    if (variance < 0) variance = 0;
    gyroNoise[axis] = sqrt(variance);

    startThreshold[axis] = max(1.0f, gyroNoise[axis] * 6.0f);
    stopThreshold[axis] = max(0.35f, gyroNoise[axis] * 2.5f);
  }

  Serial.println();
  Serial.println("Calibration complete.");

  Serial.print("GX bias: ");
  Serial.println(gyroBias[0], 3);
  Serial.print("GY bias: ");
  Serial.println(gyroBias[1], 3);
  Serial.print("GZ bias: ");
  Serial.println(gyroBias[2], 3);

  Serial.println();
  Serial.print("GX rep threshold: ");
  Serial.println(startThreshold[0], 3);
  Serial.print("GY rep threshold: ");
  Serial.println(startThreshold[1], 3);
  Serial.print("GZ rep threshold: ");
  Serial.println(startThreshold[2], 3);
  Serial.println();
}

// ============================================================
// SEND REP COUNT OVER BLE
// ============================================================

void sendRepCount() {
  uint8_t repBytes[2];
  repBytes[0] = (uint8_t)(repCount & 0xFF);
  repBytes[1] = (uint8_t)((repCount >> 8) & 0xFF);

  repCharacteristic.writeValue(repBytes, 2);

  Serial.println();
  Serial.print(">>>> REP COUNT = ");
  Serial.println(repCount);
  Serial.println();
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
// REP DETECTOR
// ============================================================

void updateRepCounter(float gyro[3]) {
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
    return;
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
      return;
    }

    if (now - repStartTime > MAX_REP_TIME_MS) {
      resetRepDetector();
    }
    return;
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
      repCount++;
      sendRepCount();
      resetRepDetector();
      return;
    }

    if (now - repStartTime > MAX_REP_TIME_MS) {
      resetRepDetector();
    }
  }
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
  Serial.println("Phase 1 Integrated Firmware");
  Serial.println("===============================");

  if (myIMU.begin() != 0) {
    Serial.println("ERROR: IMU failed.");
    while (1) { delay(1000); }
  }

  Serial.println("IMU OK");

  calibrateGyroscope();

  if (!BLE.begin()) {
    Serial.println("ERROR: BLE failed.");
    while (1) { delay(1000); }
  }

  BLE.setLocalName("XIAO-Workout");
  BLE.setAdvertisedService(workoutService);
  workoutService.addCharacteristic(motionCharacteristic);
  workoutService.addCharacteristic(repCharacteristic);
  BLE.addService(workoutService);

  uint8_t initialRep[2] = {0, 0};
  repCharacteristic.writeValue(initialRep, 2);

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

  uint32_t currentUs = micros();

  if (currentUs - previousSampleUs < SAMPLE_INTERVAL_US) {
    return;
  }

  previousSampleUs += SAMPLE_INTERVAL_US;

  if (currentUs - previousSampleUs > SAMPLE_INTERVAL_US * 4) {
    previousSampleUs = currentUs;
  }

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

  updateRepCounter(filteredGyro);

  if (SERIAL_SHOW_TIME) {
    Serial.print("Time:");
    Serial.print(millis());
    Serial.print(",");
  }

  Serial.print("AX:"); Serial.print(ax, 4);
  Serial.print(",AY:"); Serial.print(ay, 4);
  Serial.print(",AZ:"); Serial.print(az, 4);
  Serial.print(",GX:"); Serial.print(gx, 4);
  Serial.print(",GY:"); Serial.print(gy, 4);
  Serial.print(",GZ:"); Serial.print(gz, 4);
  Serial.print(",REP:"); Serial.println(repCount);
  Serial.print("rishil is great");

  MotionPacket packet;
  packet.timestamp = millis();

  packet.ax = safeInt16(ax * 1000.0);
  packet.ay = safeInt16(ay * 1000.0);
  packet.az = safeInt16(az * 1000.0);

  packet.gx = safeInt16(gx * 10.0);
  packet.gy = safeInt16(gy * 10.0);
  packet.gz = safeInt16(gz * 10.0);

  motionCharacteristic.writeValue((uint8_t *)&packet, sizeof(packet));
}
