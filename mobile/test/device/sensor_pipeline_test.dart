import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tracker/core/protocol/protocol_models.dart';
import 'package:smart_tracker/features/live_motion/domain/sensor_pipeline.dart';

void main() {
  group('SensorPipeline — Stream Processing & Graph Windowing', () {
    late SensorPipeline pipeline;

    setUp(() {
      pipeline = SensorPipeline();
    });

    test('processSample updates series buffer and limits to 500 samples', () {
      final now = DateTime.utc(2026, 1, 1);
      for (int i = 0; i < 600; i++) {
        final sample = MotionSample(
          protocolVersion: 1,
          isCalibrated: true,
          isClipped: false,
          sequence: i + 1,
          deviceUptimeMs: (i + 1) * 20,
          accelXG: 0.1,
          accelYG: 1.0,
          accelZG: 0.0,
          gyroXDegS: 0.0,
          gyroYDegS: 0.0,
          gyroZDegS: 0.0,
          receivedUtc: now.add(Duration(milliseconds: i * 20)),
        );
        pipeline.processSample(sample);
      }

      expect(pipeline.seriesData.accelX.length,
          equals(SensorPipeline.maxWindowSamples));
      expect(pipeline.seriesData.accelX.length, equals(500));
    });

    test('detects sequence gaps', () {
      final now = DateTime.utc(2026, 1, 1);

      pipeline.processSample(MotionSample(
        protocolVersion: 1,
        isCalibrated: true,
        isClipped: false,
        sequence: 1,
        deviceUptimeMs: 20,
        accelXG: 0,
        accelYG: 1,
        accelZG: 0,
        gyroXDegS: 0,
        gyroYDegS: 0,
        gyroZDegS: 0,
        receivedUtc: now,
      ));

      // Jump to sequence 5 (gap of 3 samples)
      pipeline.processSample(MotionSample(
        protocolVersion: 1,
        isCalibrated: true,
        isClipped: false,
        sequence: 5,
        deviceUptimeMs: 100,
        accelXG: 0,
        accelYG: 1,
        accelZG: 0,
        gyroXDegS: 0,
        gyroYDegS: 0,
        gyroZDegS: 0,
        receivedUtc: now.add(const Duration(milliseconds: 80)),
      ));

      expect(pipeline.sequenceGaps, equals(3));
    });
  });
}
