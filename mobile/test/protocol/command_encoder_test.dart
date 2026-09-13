import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tracker/core/protocol/command_encoder.dart';
import 'package:smart_tracker/core/protocol/protocol_models.dart';

void main() {
  group('CommandEncoder — 20-Byte BLE v1 Encoder', () {
    test('encodeControl — START_SET opcode', () {
      const command = ControlCommand(
        protocolVersion: 1,
        opcode: OpcodeEnum.startSet,
        commandId: 42,
        expectedBootId: 0x11223344,
        wireSetId: 7,
        argument: 1, // Curl Profile 1
      );

      final bytes = CommandEncoder.encodeControl(command);
      expect(bytes.length, equals(20));

      final bd = ByteData.view(Uint8List.fromList(bytes).buffer);
      expect(bd.getUint8(0), equals(1)); // Version
      expect(bd.getUint8(1), equals(1)); // START_SET opcode
      expect(bd.getUint16(2, Endian.little), equals(42));
      expect(bd.getUint32(4, Endian.little), equals(0x11223344));
      expect(bd.getUint32(8, Endian.little), equals(7));
      expect(bd.getUint32(12, Endian.little), equals(1));
      expect(bd.getUint32(16, Endian.little), equals(0)); // Reserved
    });

    test('encodeControl — END_SET opcode', () {
      const command = ControlCommand(
        protocolVersion: 1,
        opcode: OpcodeEnum.endSet,
        commandId: 43,
        expectedBootId: 0x11223344,
        wireSetId: 7,
      );

      final bytes = CommandEncoder.encodeControl(command);
      final bd = ByteData.view(Uint8List.fromList(bytes).buffer);
      expect(bd.getUint8(1), equals(4)); // END_SET opcode
      expect(bd.getUint16(2, Endian.little), equals(43));
    });
  });
}
