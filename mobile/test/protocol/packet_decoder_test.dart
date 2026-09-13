import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tracker/core/errors/app_failure.dart';
import 'package:smart_tracker/core/protocol/packet_decoder.dart';
import 'package:smart_tracker/core/protocol/protocol_models.dart';

void main() {
  group('PacketDecoder — 20-Byte BLE v1 Decoder', () {
    test('decodeMotion — valid stationary frame', () {
      // 20 bytes frame: version=1, flags=1, seq=1, uptime=100, accel=(1000, 0, 0), gyro=(0,0,0)
      final bytes = Uint8List(20);
      final bd = ByteData.view(bytes.buffer);
      bd.setUint8(0, 1);
      bd.setUint8(1, 0x01); // calibrated=true, clipped=false
      bd.setUint16(2, 1, Endian.little);
      bd.setUint32(4, 100, Endian.little);
      bd.setInt16(8, 1000, Endian.little); // 1.0 g
      bd.setInt16(10, 0, Endian.little);
      bd.setInt16(12, 0, Endian.little);
      bd.setInt16(14, 0, Endian.little);
      bd.setInt16(16, 0, Endian.little);
      bd.setInt16(18, 0, Endian.little);

      final sample = PacketDecoder.decodeMotion(bytes.toList());

      expect(sample.protocolVersion, equals(1));
      expect(sample.isCalibrated, isTrue);
      expect(sample.isClipped, isFalse);
      expect(sample.sequence, equals(1));
      expect(sample.deviceUptimeMs, equals(100));
      expect(sample.accelXG, equals(1.0));
      expect(sample.accelYG, equals(0.0));
      expect(sample.accelZG, equals(0.0));
    });

    test('decodeMotion — negative values and clipping flag', () {
      final bytes = Uint8List(20);
      final bd = ByteData.view(bytes.buffer);
      bd.setUint8(0, 1);
      bd.setUint8(1, 0x03); // calibrated=true, clipped=true
      bd.setUint16(2, 2, Endian.little);
      bd.setUint32(4, 200, Endian.little);
      bd.setInt16(8, -1000, Endian.little); // -1.0 g
      bd.setInt16(10, 2000, Endian.little); // 2.0 g
      bd.setInt16(12, -500, Endian.little); // -0.5 g
      bd.setInt16(14, -450, Endian.little); // -45.0 deg/s
      bd.setInt16(16, 900, Endian.little); // 90.0 deg/s
      bd.setInt16(18, -10, Endian.little); // -1.0 deg/s

      final sample = PacketDecoder.decodeMotion(bytes.toList());

      expect(sample.isClipped, isTrue);
      expect(sample.accelXG, equals(-1.0));
      expect(sample.accelYG, equals(2.0));
      expect(sample.accelZG, equals(-0.5));
      expect(sample.gyroXDegS, equals(-45.0));
      expect(sample.gyroYDegS, equals(90.0));
      expect(sample.gyroZDegS, equals(-1.0));
    });

    test('decodeMotion — invalid frame size throws MalformedPacketFailure', () {
      expect(
        () => PacketDecoder.decodeMotion(Uint8List(19).toList()),
        throwsA(isA<MalformedPacketFailure>()),
      );
      expect(
        () => PacketDecoder.decodeMotion(Uint8List(21).toList()),
        throwsA(isA<MalformedPacketFailure>()),
      );
    });

    test('decodeMotion — invalid protocol version throws IncompatibleProtocolFailure', () {
      final bytes = Uint8List(20);
      bytes[0] = 2; // Unsupported version
      expect(
        () => PacketDecoder.decodeMotion(bytes.toList()),
        throwsA(isA<IncompatibleProtocolFailure>()),
      );
    });

    test('decodeDeviceInfo — valid frame', () {
      final bytes = Uint8List(20);
      final bd = ByteData.view(bytes.buffer);
      bd.setUint8(0, 1);
      bd.setUint8(1, 0x07);
      bd.setUint16(2, 50, Endian.little);
      bd.setUint32(4, 0x11223344, Endian.little);
      bd.setUint32(8, 0xAABBCCDD, Endian.little);
      bd.setUint8(12, 1);
      bd.setUint8(13, 0);
      bd.setUint8(14, 0);
      bd.setUint32(16, 0x02, Endian.little);

      final info = PacketDecoder.decodeDeviceInfo(bytes.toList());

      expect(info.sampleRateHz, equals(50));
      expect(info.bootId, equals(0x11223344));
      expect(info.stableDeviceId, equals(0xAABBCCDD));
      expect(info.firmwareVersionString, equals('1.0.0'));
      expect(info.supportsCurlProfile1, isTrue);
    });

    test('decodeSetState — valid frame', () {
      final bytes = Uint8List(20);
      final bd = ByteData.view(bytes.buffer);
      bd.setUint8(0, 1);
      bd.setUint8(1, 1); // counting
      bd.setUint16(2, 5, Endian.little);
      bd.setUint32(4, 0x11223344, Endian.little);
      bd.setUint32(8, 10, Endian.little);
      bd.setUint32(12, 15, Endian.little);
      bd.setUint32(16, 30000, Endian.little);

      final snapshot = PacketDecoder.decodeSetState(bytes.toList());

      expect(snapshot.state, equals(SetStateEnum.counting));
      expect(snapshot.stateRevision, equals(5));
      expect(snapshot.wireSetId, equals(10));
      expect(snapshot.cumulativeReps, equals(15));
      expect(snapshot.activeDurationMs, equals(30000));
    });

    test('decodeSketchMotion — 16-byte Arduino sketch frame', () {
      final bytes = Uint8List(16);
      final bd = ByteData.view(bytes.buffer);
      bd.setUint32(0, 5000, Endian.little); // timestamp
      bd.setInt16(4, 68, Endian.little); // 0.068 g -> 68
      bd.setInt16(6, 1000, Endian.little); // 1.0 g -> 1000
      bd.setInt16(8, 0, Endian.little);
      bd.setInt16(10, 450, Endian.little); // 45.0 deg/s -> 450
      bd.setInt16(12, -150, Endian.little); // -15.0 deg/s
      bd.setInt16(14, 0, Endian.little);

      final sample = PacketDecoder.decodeSketchMotion(bytes.toList());

      expect(sample.deviceUptimeMs, equals(5000));
      expect(sample.accelXG, closeTo(0.068, 0.001));
      expect(sample.accelYG, equals(1.0));
      expect(sample.gyroXDegS, equals(45.0));
      expect(sample.gyroYDegS, equals(-15.0));
    });

    test('decodeSketchRepCount — 2-byte Arduino sketch rep count', () {
      final bytes = Uint8List(2);
      final bd = ByteData.view(bytes.buffer);
      bd.setUint16(0, 12, Endian.little);

      final reps = PacketDecoder.decodeSketchRepCount(bytes.toList());
      expect(reps, equals(12));
    });
  });
}
