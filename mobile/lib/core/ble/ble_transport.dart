import 'dart:async';

enum BleAdapterState { unknown, unsupported, unauthorized, poweredOff, poweredOn }

enum TransportConnectionState {
  disconnected,
  scanning,
  connecting,
  discovering,
  negotiating,
  ready,
  reconnecting,
  error
}

class DiscoveredDevice {
  final String id;
  final String name;
  final int rssi;

  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });
}

abstract class BleTransport {
  Stream<BleAdapterState> get adapterStateStream;
  Stream<TransportConnectionState> get connectionStateStream;
  Stream<List<DiscoveredDevice>> get scanResultsStream;

  BleAdapterState get currentAdapterState;
  TransportConnectionState get currentConnectionState;
  bool get isMockMode;

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)});
  Future<void> stopScan();

  Future<void> connect(String deviceId, {Duration timeout = const Duration(seconds: 15)});
  Future<void> disconnect();

  Future<List<int>> readCharacteristic(String characteristicUuid);
  Future<void> writeCharacteristic(String characteristicUuid, List<int> bytes);

  Stream<List<int>> subscribeToNotifications(String characteristicUuid);
  Future<void> unsubscribeNotifications(String characteristicUuid);

  void dispose();
}
