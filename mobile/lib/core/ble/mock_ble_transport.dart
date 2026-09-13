import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../protocol/ble_uuids.dart';
import '../protocol/protocol_models.dart';
import 'ble_transport.dart';

class MockBleTransport implements BleTransport {
  final _adapterStateController = StreamController<BleAdapterState>.broadcast();
  final _connectionStateController =
      StreamController<TransportConnectionState>.broadcast();
  final _scanResultsController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  final Map<String, StreamController<List<int>>> _notificationControllers = {};

  TransportConnectionState _connectionState =
      TransportConnectionState.disconnected;
  BleAdapterState _adapterState = BleAdapterState.poweredOn;

  Timer? _scanTimer;
  Timer? _motionTimer;

  // Mock board state
  final int _bootId = 0x11223344;
  final int _stableDeviceId = 0xAABBCCDD;
  int _sequence = 0;
  int _deviceUptimeMs = 1000;

  SetStateEnum _currentState = SetStateEnum.idle;
  int _stateRevision = 1;
  int _wireSetId = 0;
  int _cumulativeReps = 0;
  int _activeDurationMs = 0;

  double _curlPhase = 0.0;

  MockBleTransport() {
    _adapterStateController.add(_adapterState);
    _connectionStateController.add(_connectionState);
  }

  @override
  Stream<BleAdapterState> get adapterStateStream => _adapterStateController.stream;
  @override
  Stream<TransportConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  @override
  Stream<List<DiscoveredDevice>> get scanResultsStream => _scanResultsController.stream;

  @override
  BleAdapterState get currentAdapterState => _adapterState;
  @override
  TransportConnectionState get currentConnectionState => _connectionState;
  @override
  bool get isMockMode => true;

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    _setConnectionState(TransportConnectionState.scanning);
    _scanResultsController.add([
      const DiscoveredDevice(
        id: 'MOCK_XIAO_SENSE_01',
        name: 'XIAO-Tracker (SIMULATED)',
        rssi: -58,
      ),
    ]);

    _scanTimer?.cancel();
    _scanTimer = Timer(timeout, () {
      if (_connectionState == TransportConnectionState.scanning) {
        _setConnectionState(TransportConnectionState.disconnected);
      }
    });
  }

  @override
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    if (_connectionState == TransportConnectionState.scanning) {
      _setConnectionState(TransportConnectionState.disconnected);
    }
  }

  @override
  Future<void> connect(String deviceId,
      {Duration timeout = const Duration(seconds: 15)}) async {
    await stopScan();
    _setConnectionState(TransportConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 200));

    _setConnectionState(TransportConnectionState.discovering);
    await Future.delayed(const Duration(milliseconds: 200));

    _setConnectionState(TransportConnectionState.negotiating);
    await Future.delayed(const Duration(milliseconds: 200));

    _setConnectionState(TransportConnectionState.ready);
    _startMotionGenerator();
  }

  @override
  Future<void> disconnect() async {
    _stopMotionGenerator();
    _currentState = SetStateEnum.idle;
    _cumulativeReps = 0;
    _curlPhase = 0.0;
    _setConnectionState(TransportConnectionState.disconnected);
  }

  @override
  Future<List<int>> readCharacteristic(String characteristicUuid) async {
    if (characteristicUuid == BleUuids.deviceInfo) {
      return _encodeDeviceInfo();
    } else if (characteristicUuid == BleUuids.setState) {
      return _encodeSetState();
    }
    throw Exception('Unknown mock characteristic: $characteristicUuid');
  }

  @override
  Future<void> writeCharacteristic(
      String characteristicUuid, List<int> bytes) async {
    if (characteristicUuid == BleUuids.control) {
      _handleControlWrite(bytes);
      return;
    }
    throw Exception('Unsupported write characteristic: $characteristicUuid');
  }

  @override
  Stream<List<int>> subscribeToNotifications(String characteristicUuid) {
    _notificationControllers[characteristicUuid] ??=
        StreamController<List<int>>.broadcast();
    return _notificationControllers[characteristicUuid]!.stream;
  }

  @override
  Future<void> unsubscribeNotifications(String characteristicUuid) async {
    await _notificationControllers[characteristicUuid]?.close();
    _notificationControllers.remove(characteristicUuid);
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _motionTimer?.cancel();
    _adapterStateController.close();
    _connectionStateController.close();
    _scanResultsController.close();
    for (final controller in _notificationControllers.values) {
      controller.close();
    }
  }

  void _setConnectionState(TransportConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void _startMotionGenerator() {
    _motionTimer?.cancel();
    // 50 Hz timer = 20ms interval
    _motionTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      _generateAndEmitMotionSample();
    });
  }

  void _stopMotionGenerator() {
    _motionTimer?.cancel();
    _motionTimer = null;
  }

  void _generateAndEmitMotionSample() {
    if (_connectionState != TransportConnectionState.ready) return;

    _sequence = (_sequence + 1) & 0xFFFF;
    _deviceUptimeMs += 20;

    double axG = 0.0;
    double ayG = 1.0; // Gravity on Y-axis baseline
    double azG = 0.0;

    double gxDegS = 0.0;
    double gyDegS = 0.0;
    double gzDegS = 0.0;

    if (_currentState == SetStateEnum.counting) {
      _activeDurationMs += 20;
      _curlPhase += 0.08; // Curl rep cycle

      // Simulate dumbbell curl sinusoidal motion
      axG = 0.3 * math.sin(_curlPhase);
      ayG = 1.0 + 0.6 * math.cos(_curlPhase);
      azG = 0.2 * math.sin(_curlPhase * 2);

      gxDegS = 45.0 * math.sin(_curlPhase);
      gyDegS = 15.0 * math.cos(_curlPhase);
      gzDegS = 10.0 * math.sin(_curlPhase * 0.5);

      // Increment rep count when rep cycle completes
      if (_curlPhase >= 2 * math.pi) {
        _curlPhase -= 2 * math.pi;
        _cumulativeReps += 1;
        _stateRevision += 1;
        _emitSetStateNotification();
      }
    } else {
      // Slight sensor noise during stillness
      axG = (math.Random().nextDouble() - 0.5) * 0.02;
      ayG = 1.0 + (math.Random().nextDouble() - 0.5) * 0.02;
      azG = (math.Random().nextDouble() - 0.5) * 0.02;
    }

    final frame = Uint8List(20);
    final bd = ByteData.view(frame.buffer);

    bd.setUint8(0, 1); // Protocol Version = 1
    bd.setUint8(1, 0x01); // Flags: bit0 calibrated
    bd.setUint16(2, _sequence, Endian.little);
    bd.setUint32(4, _deviceUptimeMs, Endian.little);

    bd.setInt16(8, (axG * 1000).round(), Endian.little);
    bd.setInt16(10, (ayG * 1000).round(), Endian.little);
    bd.setInt16(12, (azG * 1000).round(), Endian.little);

    bd.setInt16(14, (gxDegS * 10).round(), Endian.little);
    bd.setInt16(16, (gyDegS * 10).round(), Endian.little);
    bd.setInt16(18, (gzDegS * 10).round(), Endian.little);

    _notificationControllers[BleUuids.motion]?.add(frame.toList());
  }

  void _handleControlWrite(List<int> bytes) {
    if (bytes.length != 20 || bytes[0] != 1) return;

    final bd = ByteData.view(Uint8List.fromList(bytes).buffer);
    final rawOpcode = bd.getUint8(1);
    final commandId = bd.getUint16(2, Endian.little);
    final wireSetId = bd.getUint32(8, Endian.little);
    final opcode = OpcodeEnum.fromInt(rawOpcode);

    ControlResultCode result = ControlResultCode.applied;

    switch (opcode) {
      case OpcodeEnum.startSet:
        _currentState = SetStateEnum.counting;
        _wireSetId = wireSetId;
        _cumulativeReps = 0;
        _activeDurationMs = 0;
        _stateRevision += 1;
        break;
      case OpcodeEnum.pauseSet:
        if (_currentState == SetStateEnum.counting) {
          _currentState = SetStateEnum.paused;
          _stateRevision += 1;
        }
        break;
      case OpcodeEnum.resumeSet:
        if (_currentState == SetStateEnum.paused) {
          _currentState = SetStateEnum.counting;
          _stateRevision += 1;
        }
        break;
      case OpcodeEnum.endSet:
        _currentState = SetStateEnum.ended;
        _stateRevision += 1;
        break;
      case OpcodeEnum.calibrate:
        if (_currentState == SetStateEnum.idle) {
          _currentState = SetStateEnum.calibrating;
          _stateRevision += 1;
          Timer(const Duration(milliseconds: 500), () {
            _currentState = SetStateEnum.idle;
            _stateRevision += 1;
            _emitSetStateNotification();
          });
        }
        break;
      default:
        break;
    }

    _emitSetStateNotification();

    // Emit ControlAck notification
    final ackFrame = Uint8List(20);
    final ackBd = ByteData.view(ackFrame.buffer);
    ackBd.setUint8(0, 1);
    ackBd.setUint8(1, rawOpcode);
    ackBd.setUint16(2, commandId, Endian.little);
    ackBd.setUint32(4, _bootId, Endian.little);
    ackBd.setUint32(8, _wireSetId, Endian.little);
    ackBd.setUint8(12, result.rawValue);
    ackBd.setUint8(13, _currentState.index);
    ackBd.setUint16(14, 0, Endian.little);
    ackBd.setUint32(16, _cumulativeReps, Endian.little);

    _notificationControllers[BleUuids.controlAck]?.add(ackFrame.toList());
  }

  List<int> _encodeDeviceInfo() {
    final frame = Uint8List(20);
    final bd = ByteData.view(frame.buffer);
    bd.setUint8(0, 1);
    bd.setUint8(1, 0x07); // Supports motion, set control, calibration
    bd.setUint16(2, 50, Endian.little);
    bd.setUint32(4, _bootId, Endian.little);
    bd.setUint32(8, _stableDeviceId, Endian.little);
    bd.setUint8(12, 1);
    bd.setUint8(13, 0);
    bd.setUint8(14, 0);
    bd.setUint8(15, 0);
    bd.setUint32(16, 0x02, Endian.little); // Supports curl profile 1
    return frame.toList();
  }

  List<int> _encodeSetState() {
    final frame = Uint8List(20);
    final bd = ByteData.view(frame.buffer);
    bd.setUint8(0, 1);
    bd.setUint8(1, _currentState.index);
    bd.setUint16(2, _stateRevision, Endian.little);
    bd.setUint32(4, _bootId, Endian.little);
    bd.setUint32(8, _wireSetId, Endian.little);
    bd.setUint32(12, _cumulativeReps, Endian.little);
    bd.setUint32(16, _activeDurationMs, Endian.little);
    return frame.toList();
  }

  void _emitSetStateNotification() {
    _notificationControllers[BleUuids.setState]?.add(_encodeSetState());
  }
}
