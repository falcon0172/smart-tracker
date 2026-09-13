import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tracker/core/logging/csv_exporter.dart';
import 'package:smart_tracker/core/protocol/protocol_models.dart';

void main() {
  group('CsvExporter — CSV Motion Data Exporter', () {
    test('exportMotionSamplesToCsv generates header and rows', () {
      final sample = MotionSample(
        protocolVersion: 1,
        isCalibrated: true,
        isClipped: false,
        sequence: 1,
        deviceUptimeMs: 1000,
        accelXG: 0.1,
        accelYG: 0.98,
        accelZG: 0.0,
        gyroXDegS: 1.5,
        gyroYDegS: -2.0,
        gyroZDegS: 0.0,
        receivedUtc: DateTime.utc(2026, 9, 13, 12, 0, 0),
      );

      final csv = CsvExporter.exportMotionSamplesToCsv(
        recordingId: 'REC_123',
        setId: 'SET_456',
        connectionEpoch: 1757764800,
        samples: [sample],
      );

      expect(csv, contains('recording_id,set_id,connection_epoch,sequence'));
      expect(csv, contains('REC_123,SET_456,1757764800,1,1000'));
      expect(csv, contains('0.1,0.98,0.0,1.5,-2.0,0.0,1'));
    });

    test('neutralizes formula injection characters', () {
      final sample = MotionSample(
        protocolVersion: 1,
        isCalibrated: true,
        isClipped: false,
        sequence: 1,
        deviceUptimeMs: 1000,
        accelXG: 0,
        accelYG: 1,
        accelZG: 0,
        gyroXDegS: 0,
        gyroYDegS: 0,
        gyroZDegS: 0,
        receivedUtc: DateTime.utc(2026, 9, 13),
      );

      final csv = CsvExporter.exportMotionSamplesToCsv(
        recordingId: '=cmd|\'/C calc\'!A0',
        setId: '+SET_DANGEROUS',
        connectionEpoch: 1,
        samples: [sample],
      );

      expect(csv, contains("'\=cmd|\'/C calc\'!A0"));
      expect(csv, contains("'\+SET_DANGEROUS"));
    });
  });
}
