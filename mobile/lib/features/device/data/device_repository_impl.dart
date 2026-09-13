import 'dart:async';
import '../../../core/ble/ble_transport.dart';
import '../../../core/logging/diagnostic_logger.dart';
import '../../../core/protocol/ble_uuids.dart';
import '../../../core/protocol/command_encoder.dart';
import '../../../core/protocol/packet_decoder.dart';
import '../../../core/protocol/protocol_models.dart';
import '../domain/device_repository.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  final BleTransport transport;
  final DiagnosticLogger logger;

  final _motionController = StreamController<MotionSample>.broadcast();
  final _setStateController = StreamController<SetSnapshot>.broadcast();
  final _controlAckController = StreamController<ControlAck>.broadcast();

  StreamSubscription? _motionSub;
  StreamSubscription? _setStateSub;
  StreamSubscription? _ackSub;

  DeviceInfo? _deviceInfo;
  SetSnapshot? _setSnapshot;

  DeviceRepositoryImpl({
    required this.transport,
    required this.logger,
  });

  @override
  Stream<TransportConnectionState> get connectionStateStream =>
      transport.connectionStateStream;

  @override
  Stream<MotionSample> get motionStream => _motionController.stream;
  @override
  Stream<SetSnapshot> get setStateStream => _setStateController.stream;
  @override
  Stream<ControlAck> get controlAckStream => _controlAckController.stream;

  @override
  TransportConnectionState get currentConnectionState =>
      transport.currentConnectionState;
  @override
  DeviceInfo? get currentDeviceInfo => _deviceInfo;
  @override
  SetSnapshot? get currentSetSnapshot => _setSnapshot;

  @override
  Future<void> startScan() => transport.startScan();
  @override
  Future<void> stopScan() => transport.stopScan();

  @override
  Future<void> connect(String deviceId) async {
    await transport.connect(deviceId);
    _setupSubscriptions();
    await _readInitialState();
  }

  @override
  Future<void> disconnect() async {
    _cancelSubscriptions();
    await transport.disconnect();
  }

  @override
  Future<void> sendCommand(ControlCommand command) async {
    final bytes = CommandEncoder.encodeControl(command);
    logger.info('DeviceRepository',
        'Sending opcode=${command.opcode.name} cmdId=${command.commandId}');
    await transport.writeCharacteristic(BleUuids.control, bytes);
  }

  void _setupSubscriptions() {
    _cancelSubscriptions();

    _motionSub =
        transport.subscribeToNotifications(BleUuids.motion).listen((bytes) {
      try {
        final sample = PacketDecoder.decodeMotion(bytes);
        _motionController.add(sample);
      } catch (e) {
        logger.error('DeviceRepo', 'Decode motion error: $e');
      }
    });

    _setStateSub =
        transport.subscribeToNotifications(BleUuids.setState).listen((bytes) {
      try {
        final snapshot = PacketDecoder.decodeSetState(bytes);
        _setSnapshot = snapshot;
        _setStateController.add(snapshot);
      } catch (e) {
        logger.error('DeviceRepo', 'Decode SetState error: $e');
      }
    });

    _ackSub = transport
        .subscribeToNotifications(BleUuids.controlAck)
        .listen((bytes) {
      try {
        final ack = PacketDecoder.decodeControlAck(bytes);
        _controlAckController.add(ack);
      } catch (e) {
        logger.error('DeviceRepo', 'Decode ControlAck error: $e');
      }
    });
  }

  Future<void> _readInitialState() async {
    try {
      final infoBytes =
          await transport.readCharacteristic(BleUuids.deviceInfo);
      _deviceInfo = PacketDecoder.decodeDeviceInfo(infoBytes);

      final stateBytes =
          await transport.readCharacteristic(BleUuids.setState);
      _setSnapshot = PacketDecoder.decodeSetState(stateBytes);
    } catch (e) {
      logger.error('DeviceRepo', 'Read initial state error: $e');
    }
  }

  void _cancelSubscriptions() {
    _motionSub?.cancel();
    _setStateSub?.cancel();
    _ackSub?.cancel();
  }
}
