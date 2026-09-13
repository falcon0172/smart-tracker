import '../../../core/ble/ble_transport.dart';
import '../../../core/protocol/protocol_models.dart';

abstract class DeviceRepository {
  Stream<TransportConnectionState> get connectionStateStream;
  Stream<MotionSample> get motionStream;
  Stream<SetSnapshot> get setStateStream;
  Stream<ControlAck> get controlAckStream;

  TransportConnectionState get currentConnectionState;
  DeviceInfo? get currentDeviceInfo;
  SetSnapshot? get currentSetSnapshot;

  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(String deviceId);
  Future<void> disconnect();

  Future<void> sendCommand(ControlCommand command);
}
