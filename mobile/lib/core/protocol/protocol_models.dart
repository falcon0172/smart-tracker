enum SetStateEnum {
  idle,
  counting,
  paused,
  ended,
  calibrating,
  calibrationFailed;

  static SetStateEnum fromInt(int value) {
    if (value >= 0 && value < SetStateEnum.values.length) {
      return SetStateEnum.values[value];
    }
    return SetStateEnum.idle;
  }
}

enum OpcodeEnum {
  none(0),
  startSet(1),
  pauseSet(2),
  resumeSet(3),
  endSet(4),
  calibrate(5),
  setStreaming(6);

  final int rawValue;
  const OpcodeEnum(this.rawValue);

  static OpcodeEnum fromInt(int value) {
    for (final op in OpcodeEnum.values) {
      if (op.rawValue == value) return op;
    }
    return OpcodeEnum.none;
  }
}

enum ControlResultCode {
  applied(0),
  invalidState(1),
  unsupported(2),
  invalidArgument(3),
  wrongBoot(4),
  busy(5),
  internalError(6);

  final int rawValue;
  const ControlResultCode(this.rawValue);

  static ControlResultCode fromInt(int value) {
    for (final res in ControlResultCode.values) {
      if (res.rawValue == value) return res;
    }
    return ControlResultCode.internalError;
  }
}

class MotionSample {
  final int protocolVersion;
  final bool isCalibrated;
  final bool isClipped;
  final int sequence;
  final int deviceUptimeMs;
  final double accelXG;
  final double accelYG;
  final double accelZG;
  final double gyroXDegS;
  final double gyroYDegS;
  final double gyroZDegS;
  final DateTime receivedUtc;

  const MotionSample({
    required this.protocolVersion,
    required this.isCalibrated,
    required this.isClipped,
    required this.sequence,
    required this.deviceUptimeMs,
    required this.accelXG,
    required this.accelYG,
    required this.accelZG,
    required this.gyroXDegS,
    required this.gyroYDegS,
    required this.gyroZDegS,
    required this.receivedUtc,
  });

  @override
  String toString() =>
      'MotionSample(seq: $sequence, uptime: ${deviceUptimeMs}ms, accel: [${accelXG.toStringAsFixed(2)}, ${accelYG.toStringAsFixed(2)}, ${accelZG.toStringAsFixed(2)}])';
}

class DeviceInfo {
  final int protocolVersion;
  final int capabilityMask;
  final int sampleRateHz;
  final int bootId;
  final int stableDeviceId;
  final int firmwareMajor;
  final int firmwareMinor;
  final int firmwarePatch;
  final int supportedProfileMask;

  const DeviceInfo({
    required this.protocolVersion,
    required this.capabilityMask,
    required this.sampleRateHz,
    required this.bootId,
    required this.stableDeviceId,
    required this.firmwareMajor,
    required this.firmwareMinor,
    required this.firmwarePatch,
    required this.supportedProfileMask,
  });

  bool get supportsMotionNotifications => (capabilityMask & 0x01) != 0;
  bool get supportsSetControl => (capabilityMask & 0x02) != 0;
  bool get supportsCalibration => (capabilityMask & 0x04) != 0;
  bool get supportsCurlProfile1 => (supportedProfileMask & 0x02) != 0;

  String get firmwareVersionString =>
      '$firmwareMajor.$firmwareMinor.$firmwarePatch';
}

class SetSnapshot {
  final int protocolVersion;
  final SetStateEnum state;
  final int stateRevision;
  final int bootId;
  final int wireSetId;
  final int cumulativeReps;
  final int activeDurationMs;

  const SetSnapshot({
    required this.protocolVersion,
    required this.state,
    required this.stateRevision,
    required this.bootId,
    required this.wireSetId,
    required this.cumulativeReps,
    required this.activeDurationMs,
  });
}

class ControlCommand {
  final int protocolVersion;
  final OpcodeEnum opcode;
  final int commandId;
  final int expectedBootId;
  final int wireSetId;
  final int argument;

  const ControlCommand({
    this.protocolVersion = 1,
    required this.opcode,
    required this.commandId,
    required this.expectedBootId,
    required this.wireSetId,
    this.argument = 0,
  });
}

class ControlAck {
  final int protocolVersion;
  final OpcodeEnum opcode;
  final int commandId;
  final int bootId;
  final int wireSetId;
  final ControlResultCode resultCode;
  final SetStateEnum currentState;
  final int cumulativeReps;

  const ControlAck({
    required this.protocolVersion,
    required this.opcode,
    required this.commandId,
    required this.bootId,
    required this.wireSetId,
    required this.resultCode,
    required this.currentState,
    required this.cumulativeReps,
  });
}
