import 'dart:typed_data';
import '../errors/app_failure.dart';
import 'protocol_models.dart';

class PacketDecoder {
  PacketDecoder._();

  static const int expectedFrameSize = 20;
  static const int expectedProtocolVersion = 1;

  static MotionSample decodeMotion(List<int> bytes, {DateTime? receiptUtc}) {
    _validateLengthAndVersion(bytes, 'Motion');
    final buffer = Uint8List.fromList(bytes).buffer;
    final byteData = ByteData.view(buffer);

    final flags = byteData.getUint8(1);
    final isCalibrated = (flags & 0x01) != 0;
    final isClipped = (flags & 0x02) != 0;

    final sequence = byteData.getUint16(2, Endian.little);
    final deviceUptimeMs = byteData.getUint32(4, Endian.little);

    final accelXRaw = byteData.getInt16(8, Endian.little);
    final accelYRaw = byteData.getInt16(10, Endian.little);
    final accelZRaw = byteData.getInt16(12, Endian.little);

    final gyroXRaw = byteData.getInt16(14, Endian.little);
    final gyroYRaw = byteData.getInt16(16, Endian.little);
    final gyroZRaw = byteData.getInt16(18, Endian.little);

    return MotionSample(
      protocolVersion: expectedProtocolVersion,
      isCalibrated: isCalibrated,
      isClipped: isClipped,
      sequence: sequence,
      deviceUptimeMs: deviceUptimeMs,
      accelXG: accelXRaw / 1000.0,
      accelYG: accelYRaw / 1000.0,
      accelZG: accelZRaw / 1000.0,
      gyroXDegS: gyroXRaw / 10.0,
      gyroYDegS: gyroYRaw / 10.0,
      gyroZDegS: gyroZRaw / 10.0,
      receivedUtc: receiptUtc ?? DateTime.now().toUtc(),
    );
  }

  /// Decodes 16-byte motion packet from existing Arduino sketch (timestamp + 6x int16 axes)
  static MotionSample decodeSketchMotion(List<int> bytes, {DateTime? receiptUtc}) {
    if (bytes.length != 16) {
      throw MalformedPacketFailure(
          'Sketch motion frame must be exactly 16 bytes, got ${bytes.length}');
    }
    final buffer = Uint8List.fromList(bytes).buffer;
    final byteData = ByteData.view(buffer);

    final deviceUptimeMs = byteData.getUint32(0, Endian.little);
    final accelXRaw = byteData.getInt16(4, Endian.little);
    final accelYRaw = byteData.getInt16(6, Endian.little);
    final accelZRaw = byteData.getInt16(8, Endian.little);
    final gyroXRaw = byteData.getInt16(10, Endian.little);
    final gyroYRaw = byteData.getInt16(12, Endian.little);
    final gyroZRaw = byteData.getInt16(14, Endian.little);

    return MotionSample(
      protocolVersion: 1,
      isCalibrated: true,
      isClipped: false,
      sequence: 0,
      deviceUptimeMs: deviceUptimeMs,
      accelXG: accelXRaw / 1000.0,
      accelYG: accelYRaw / 1000.0,
      accelZG: accelZRaw / 1000.0,
      gyroXDegS: gyroXRaw / 10.0,
      gyroYDegS: gyroYRaw / 10.0,
      gyroZDegS: gyroZRaw / 10.0,
      receivedUtc: receiptUtc ?? DateTime.now().toUtc(),
    );
  }

  /// Decodes 2-byte uint16 rep count from existing Arduino sketch
  static int decodeSketchRepCount(List<int> bytes) {
    if (bytes.length != 2) {
      throw MalformedPacketFailure(
          'Sketch rep count frame must be 2 bytes, got ${bytes.length}');
    }
    final buffer = Uint8List.fromList(bytes).buffer;
    return ByteData.view(buffer).getUint16(0, Endian.little);
  }

  static DeviceInfo decodeDeviceInfo(List<int> bytes) {
    _validateLengthAndVersion(bytes, 'DeviceInfo');
    final buffer = Uint8List.fromList(bytes).buffer;
    final byteData = ByteData.view(buffer);

    final capabilityMask = byteData.getUint8(1);
    final sampleRateHz = byteData.getUint16(2, Endian.little);
    final bootId = byteData.getUint32(4, Endian.little);
    final stableDeviceId = byteData.getUint32(8, Endian.little);
    final firmwareMajor = byteData.getUint8(12);
    final firmwareMinor = byteData.getUint8(13);
    final firmwarePatch = byteData.getUint8(14);
    final supportedProfileMask = byteData.getUint32(16, Endian.little);

    return DeviceInfo(
      protocolVersion: expectedProtocolVersion,
      capabilityMask: capabilityMask,
      sampleRateHz: sampleRateHz,
      bootId: bootId,
      stableDeviceId: stableDeviceId,
      firmwareMajor: firmwareMajor,
      firmwareMinor: firmwareMinor,
      firmwarePatch: firmwarePatch,
      supportedProfileMask: supportedProfileMask,
    );
  }

  static SetSnapshot decodeSetState(List<int> bytes) {
    _validateLengthAndVersion(bytes, 'SetState');
    final buffer = Uint8List.fromList(bytes).buffer;
    final byteData = ByteData.view(buffer);

    final rawState = byteData.getUint8(1);
    final stateRevision = byteData.getUint16(2, Endian.little);
    final bootId = byteData.getUint32(4, Endian.little);
    final wireSetId = byteData.getUint32(8, Endian.little);
    final cumulativeReps = byteData.getUint32(12, Endian.little);
    final activeDurationMs = byteData.getUint32(16, Endian.little);

    return SetSnapshot(
      protocolVersion: expectedProtocolVersion,
      state: SetStateEnum.fromInt(rawState),
      stateRevision: stateRevision,
      bootId: bootId,
      wireSetId: wireSetId,
      cumulativeReps: cumulativeReps,
      activeDurationMs: activeDurationMs,
    );
  }

  static ControlAck decodeControlAck(List<int> bytes) {
    _validateLengthAndVersion(bytes, 'ControlAck');
    final buffer = Uint8List.fromList(bytes).buffer;
    final byteData = ByteData.view(buffer);

    final rawOpcode = byteData.getUint8(1);
    final commandId = byteData.getUint16(2, Endian.little);
    final bootId = byteData.getUint32(4, Endian.little);
    final wireSetId = byteData.getUint32(8, Endian.little);
    final rawResult = byteData.getUint8(12);
    final rawState = byteData.getUint8(13);
    final cumulativeReps = byteData.getUint32(16, Endian.little);

    return ControlAck(
      protocolVersion: expectedProtocolVersion,
      opcode: OpcodeEnum.fromInt(rawOpcode),
      commandId: commandId,
      bootId: bootId,
      wireSetId: wireSetId,
      resultCode: ControlResultCode.fromInt(rawResult),
      currentState: SetStateEnum.fromInt(rawState),
      cumulativeReps: cumulativeReps,
    );
  }

  static void _validateLengthAndVersion(List<int> bytes, String frameType) {
    if (bytes.length != expectedFrameSize) {
      throw MalformedPacketFailure(
          '$frameType frame must be exactly $expectedFrameSize bytes, got ${bytes.length}');
    }
    if (bytes[0] != expectedProtocolVersion) {
      throw IncompatibleProtocolFailure(
          '$frameType frame version mismatch: expected $expectedProtocolVersion, got ${bytes[0]}');
    }
  }
}
