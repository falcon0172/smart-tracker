import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tracker/core/ble/ble_transport.dart';
import 'package:smart_tracker/core/ble/mock_ble_transport.dart';
import 'package:smart_tracker/core/protocol/ble_uuids.dart';
import 'package:smart_tracker/core/protocol/packet_decoder.dart';

void main() {
  group('MockBleTransport — Simulator Engine', () {
    late MockBleTransport mockTransport;

    setUp(() {
      mockTransport = MockBleTransport();
    });

    tearDown(() {
      mockTransport.dispose();
    });

    test('isMockMode returns true', () {
      expect(mockTransport.isMockMode, isTrue);
    });

    test('connect transitions state machine to ready', () async {
      final states = <TransportConnectionState>[];
      mockTransport.connectionStateStream.listen(states.add);

      await mockTransport.connect('MOCK_XIAO_SENSE_01');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states, contains(TransportConnectionState.ready));
      expect(mockTransport.currentConnectionState,
          equals(TransportConnectionState.ready));
    });

    test('readCharacteristic DeviceInfo returns valid 20-byte payload', () async {
      await mockTransport.connect('MOCK_XIAO_SENSE_01');
      final bytes = await mockTransport.readCharacteristic(BleUuids.deviceInfo);

      expect(bytes.length, equals(20));
      final info = PacketDecoder.decodeDeviceInfo(bytes);
      expect(info.sampleRateHz, equals(50));
      expect(info.supportsCurlProfile1, isTrue);
    });

    test('motion notification stream emits 20-byte packets', () async {
      await mockTransport.connect('MOCK_XIAO_SENSE_01');

      final packet = await mockTransport
          .subscribeToNotifications(BleUuids.motion)
          .first;

      expect(packet.length, equals(20));
      final sample = PacketDecoder.decodeMotion(packet);
      expect(sample.protocolVersion, equals(1));
    });
  });
}
