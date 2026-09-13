import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ble/ble_transport.dart';
import '../core/ble/flutter_ble_transport.dart';
import '../core/ble/mock_ble_transport.dart';
import '../core/logging/diagnostic_logger.dart';
import '../core/time/clock.dart';
import '../features/live_motion/domain/sensor_pipeline.dart';

final clockProvider = Provider<Clock>((ref) {
  return const SystemClock();
});

final diagnosticLoggerProvider = Provider<DiagnosticLogger>((ref) {
  return DiagnosticLogger();
});

final bleTransportProvider = Provider<BleTransport>((ref) {
  const trackerMode = String.fromEnvironment('TRACKER_MODE', defaultValue: 'mock');

  final BleTransport transport = (trackerMode == 'real')
      ? FlutterBleTransport()
      : MockBleTransport();

  ref.onDispose(() {
    transport.dispose();
  });
  return transport;
});

final sensorPipelineProvider = Provider<SensorPipeline>((ref) {
  return SensorPipeline();
});
