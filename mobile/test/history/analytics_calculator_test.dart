import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tracker/core/protocol/protocol_models.dart';
import 'package:smart_tracker/features/history/domain/analytics_calculator.dart';

void main() {
  group('AnalyticsCalculator', () {
    test('calculate returns empty analytics for empty samples or zero reps', () {
      final analytics = AnalyticsCalculator.calculate([], 0);
      expect(analytics.totalReps, equals(0));
      expect(analytics.peakGyroDegS, equals(0.0));
      expect(analytics.peakAccelG, equals(0.0));
    });

    test('calculate computes peak values and tempo correctly', () {
      final samples = [
        MotionSample(
          protocolVersion: 1,
          isCalibrated: true,
          isClipped: false,
          sequence: 1,
          deviceUptimeMs: 1000,
          accelXG: 0.0,
          accelYG: 1.0,
          accelZG: 0.0,
          gyroXDegS: 10.0,
          gyroYDegS: 20.0,
          gyroZDegS: 0.0,
          receivedUtc: DateTime.now(),
        ),
        MotionSample(
          protocolVersion: 1,
          isCalibrated: true,
          isClipped: false,
          sequence: 2,
          deviceUptimeMs: 3000,
          accelXG: 0.5,
          accelYG: 1.2,
          accelZG: 0.0,
          gyroXDegS: 40.0,
          gyroYDegS: 30.0,
          gyroZDegS: 0.0,
          receivedUtc: DateTime.now(),
        ),
      ];

      final analytics = AnalyticsCalculator.calculate(samples, 1);
      expect(analytics.totalReps, equals(1));
      expect(analytics.peakGyroDegS, greaterThan(40.0));
      expect(analytics.peakAccelG, greaterThan(1.2));
      expect(analytics.avgRepDurationSec, equals(2.0));
    });
  });
}
