abstract class AppFailure implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const AppFailure(this.message, {this.code, this.cause});

  @override
  String toString() => 'AppFailure[$code]: $message';
}

class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure([super.message = 'Bluetooth permissions denied'])
      : super(code: 'PERMISSION_DENIED');
}

class BluetoothOffFailure extends AppFailure {
  const BluetoothOffFailure([super.message = 'Bluetooth adapter is powered off'])
      : super(code: 'BLUETOOTH_OFF');
}

class ConnectionTimeoutFailure extends AppFailure {
  const ConnectionTimeoutFailure([super.message = 'Connection attempt timed out'])
      : super(code: 'CONNECTION_TIMEOUT');
}

class IncompatibleProtocolFailure extends AppFailure {
  const IncompatibleProtocolFailure(super.message)
      : super(code: 'INCOMPATIBLE_PROTOCOL');
}

class MalformedPacketFailure extends AppFailure {
  const MalformedPacketFailure(super.message)
      : super(code: 'MALFORMED_PACKET');
}

class CommandTimeoutFailure extends AppFailure {
  const CommandTimeoutFailure(super.message)
      : super(code: 'COMMAND_TIMEOUT');
}

class DeviceRestartedFailure extends AppFailure {
  const DeviceRestartedFailure([super.message = 'Device restart detected during set'])
      : super(code: 'DEVICE_RESTARTED');
}

class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {super.cause})
      : super(code: 'STORAGE_FAILURE');
}
