import 'package:csv/csv.dart';

import '../protocol/protocol_models.dart';

class CsvExporter {
  CsvExporter._();

  static const String csvHeaders =
      'recording_id,set_id,connection_epoch,sequence,device_time_ms,received_utc,ax_g,ay_g,az_g,gx_deg_s,gy_deg_s,gz_deg_s,flags';

  static String exportMotionSamplesToCsv({
    required String recordingId,
    required String setId,
    required int connectionEpoch,
    required List<MotionSample> samples,
  }) {
    final List<List<dynamic>> rows = [];

    // Header row
    rows.add([
      'recording_id',
      'set_id',
      'connection_epoch',
      'sequence',
      'device_time_ms',
      'received_utc',
      'ax_g',
      'ay_g',
      'az_g',
      'gx_deg_s',
      'gy_deg_s',
      'gz_deg_s',
      'flags'
    ]);

    for (final sample in samples) {
      final flagsInt = (sample.isCalibrated ? 1 : 0) | (sample.isClipped ? 2 : 0);

      rows.add([
        _sanitizeCsvValue(recordingId),
        _sanitizeCsvValue(setId),
        connectionEpoch,
        sample.sequence,
        sample.deviceUptimeMs,
        sample.receivedUtc.toIso8601String(),
        sample.accelXG,
        sample.accelYG,
        sample.accelZG,
        sample.gyroXDegS,
        sample.gyroYDegS,
        sample.gyroZDegS,
        flagsInt,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static String _sanitizeCsvValue(String input) {
    if (input.isEmpty) return input;
    // Neutralize spreadsheet formula injection (=, +, -, @, \t, \r)
    final firstChar = input[0];
    if (firstChar == '=' ||
        firstChar == '+' ||
        firstChar == '-' ||
        firstChar == '@' ||
        firstChar == '\t' ||
        firstChar == '\r') {
      return "'$input";
    }
    return input;
  }
}
