import 'dart:typed_data';
import 'protocol_models.dart';

class CommandEncoder {
  CommandEncoder._();

  static List<int> encodeControl(ControlCommand command) {
    final buffer = Uint8List(20);
    final byteData = ByteData.view(buffer.buffer);

    byteData.setUint8(0, command.protocolVersion);
    byteData.setUint8(1, command.opcode.rawValue);
    byteData.setUint16(2, command.commandId, Endian.little);
    byteData.setUint32(4, command.expectedBootId, Endian.little);
    byteData.setUint32(8, command.wireSetId, Endian.little);
    byteData.setUint32(12, command.argument, Endian.little);
    byteData.setUint32(16, 0, Endian.little); // Reserved zero

    return buffer.toList();
  }
}
