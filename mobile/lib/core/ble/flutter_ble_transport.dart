import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../protocol/ble_uuids.dart';
import 'ble_transport.dart';

class FlutterBleTransport implements BleTransport {
  final _adapterStateController = StreamController<BleAdapterState>.broadcast();
  final _connectionStateController =
      StreamController<TransportConnectionState>.broadcast();
  final _scanResultsController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  final Map<String, StreamController<List<int>>> _notificationControllers = {};
  final List<DiscoveredDevice> _discoveredDevices = [];

  TransportConnectionState _connectionState =
      TransportConnectionState.disconnected;
  BleAdapterState _adapterState = BleAdapterState.unknown;

  String? _connectedDeviceId;
  Timer? _scanTimer;

  FlutterBleTransport() {
    _initBle();
  }

  void _initBle() {
    UniversalBle.onAvailabilityChange = (state) {
      _adapterState = _mapAdapterState(state);
      _adapterStateController.add(_adapterState);
    };

    UniversalBle.onConnectionChange = (deviceId, isConnected, error) {
      if (!isConnected && deviceId == _connectedDeviceId) {
        _connectedDeviceId = null;
        _setConnectionState(TransportConnectionState.disconnected);
      }
    };

    UniversalBle.onScanResult = (result) {
      final name = result.name ?? 'XIAO-Workout';
      final existingIndex = _discoveredDevices.indexWhere((d) => d.id == result.deviceId);
      final dev = DiscoveredDevice(
        id: result.deviceId,
        name: name.isNotEmpty ? name : 'XIAO-Tracker',
        rssi: result.rssi ?? -60,
      );

      if (existingIndex >= 0) {
        _discoveredDevices[existingIndex] = dev;
      } else {
        _discoveredDevices.add(dev);
      }

      _scanResultsController.add(List.unmodifiable(_discoveredDevices));
    };

    UniversalBle.onValueChange = (deviceId, characteristicId, value, timestamp) {
      final key = characteristicId.toLowerCase();
      if (_notificationControllers.containsKey(key)) {
        _notificationControllers[key]!.add(value.toList());
      }
    };
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
  bool get isMockMode => false;

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    _discoveredDevices.clear();
    _setConnectionState(TransportConnectionState.scanning);

    await UniversalBle.startScan(
      scanFilter: ScanFilter(
        withServices: [
          BleUuids.sketchService,
          BleUuids.baseService,
        ],
      ),
    );

    _scanTimer?.cancel();
    _scanTimer = Timer(timeout, () {
      stopScan();
    });
  }

  @override
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    await UniversalBle.stopScan();
    if (_connectionState == TransportConnectionState.scanning) {
      _setConnectionState(TransportConnectionState.disconnected);
    }
  }

  @override
  Future<void> connect(String deviceId,
      {Duration timeout = const Duration(seconds: 15)}) async {
    await stopScan();
    _setConnectionState(TransportConnectionState.connecting);

    try {
      await UniversalBle.connect(deviceId);
      _connectedDeviceId = deviceId;
      _setConnectionState(TransportConnectionState.discovering);

      await UniversalBle.discoverServices(deviceId);
      _setConnectionState(TransportConnectionState.ready);
    } catch (e) {
      _setConnectionState(TransportConnectionState.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_connectedDeviceId != null) {
      await UniversalBle.disconnect(_connectedDeviceId!);
      _connectedDeviceId = null;
    }
    _setConnectionState(TransportConnectionState.disconnected);
  }

  @override
  Future<List<int>> readCharacteristic(String characteristicUuid) async {
    if (_connectedDeviceId == null) throw Exception('Not connected');
    final serviceUuid = _getServiceUuidForCharacteristic(characteristicUuid);

    final value = await UniversalBle.read(
      _connectedDeviceId!,
      serviceUuid,
      characteristicUuid,
    );
    return value;
  }

  @override
  Future<void> writeCharacteristic(
      String characteristicUuid, List<int> bytes) async {
    if (_connectedDeviceId == null) throw Exception('Not connected');
    final serviceUuid = _getServiceUuidForCharacteristic(characteristicUuid);

    await UniversalBle.write(
      _connectedDeviceId!,
      serviceUuid,
      characteristicUuid,
      Uint8List.fromList(bytes),
    );
  }

  @override
  Stream<List<int>> subscribeToNotifications(String characteristicUuid) {
    final key = characteristicUuid.toLowerCase();
    _notificationControllers[key] ??= StreamController<List<int>>.broadcast();

    if (_connectedDeviceId != null) {
      final serviceUuid = _getServiceUuidForCharacteristic(characteristicUuid);
      UniversalBle.subscribeNotifications(
        _connectedDeviceId!,
        serviceUuid,
        characteristicUuid,
      );
    }

    return _notificationControllers[key]!.stream;
  }

  @override
  Future<void> unsubscribeNotifications(String characteristicUuid) async {
    final key = characteristicUuid.toLowerCase();
    if (_connectedDeviceId != null) {
      final serviceUuid = _getServiceUuidForCharacteristic(characteristicUuid);
      await UniversalBle.unsubscribe(
        _connectedDeviceId!,
        serviceUuid,
        characteristicUuid,
      );
    }
    await _notificationControllers[key]?.close();
    _notificationControllers.remove(key);
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
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

  BleAdapterState _mapAdapterState(AvailabilityState state) {
    switch (state) {
      case AvailabilityState.poweredOn:
        return BleAdapterState.poweredOn;
      case AvailabilityState.poweredOff:
        return BleAdapterState.poweredOff;
      case AvailabilityState.unauthorized:
        return BleAdapterState.unauthorized;
      case AvailabilityState.unsupported:
        return BleAdapterState.unsupported;
      default:
        return BleAdapterState.unknown;
    }
  }

  String _getServiceUuidForCharacteristic(String characteristicUuid) {
    final lower = characteristicUuid.toLowerCase();
    if (lower == BleUuids.sketchMotion.toLowerCase() ||
        lower == BleUuids.sketchRep.toLowerCase()) {
      return BleUuids.sketchService;
    }
    return BleUuids.baseService;
  }
}
