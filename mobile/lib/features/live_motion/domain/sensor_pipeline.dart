import 'dart:collection';
import '../../../core/protocol/protocol_models.dart';

class AxisSeriesData {
  final List<double> accelX = [];
  final List<double> accelY = [];
  final List<double> accelZ = [];

  final List<double> gyroX = [];
  final List<double> gyroY = [];
  final List<double> gyroZ = [];

  void clear() {
    accelX.clear();
    accelY.clear();
    accelZ.clear();
    gyroX.clear();
    gyroY.clear();
    gyroZ.clear();
  }
}

class SensorPipeline {
  static const int maxWindowSamples = 500; // 10 seconds at 50 Hz

  final AxisSeriesData seriesData = AxisSeriesData();
  final Queue<DateTime> _sampleReceiptTimes = Queue<DateTime>();

  int? _lastSequence;
  int _sequenceGaps = 0;
  int _duplicatePackets = 0;
  double _observedHz = 0.0;
  bool _isFrozen = false;

  int get sequenceGaps => _sequenceGaps;
  int get duplicatePackets => _duplicatePackets;
  double get observedHz => _observedHz;
  bool get isFrozen => _isFrozen;

  void toggleFreeze() {
    _isFrozen = !_isFrozen;
  }

  void processSample(MotionSample sample) {
    // Sequence gap detection
    if (_lastSequence != null) {
      final expectedSeq = (_lastSequence! + 1) & 0xFFFF;
      if (sample.sequence == _lastSequence) {
        _duplicatePackets++;
        return;
      } else if (sample.sequence != expectedSeq) {
        final gap = (sample.sequence - expectedSeq) & 0xFFFF;
        _sequenceGaps += gap;
      }
    }
    _lastSequence = sample.sequence;

    // Calculate rolling observed Hz over last 1 second window
    final now = sample.receivedUtc;
    _sampleReceiptTimes.addLast(now);
    while (_sampleReceiptTimes.isNotEmpty &&
        now.difference(_sampleReceiptTimes.first).inMilliseconds > 1000) {
      _sampleReceiptTimes.removeFirst();
    }
    _observedHz = _sampleReceiptTimes.length.toDouble();

    // Update rolling graph window buffer if not frozen
    if (!_isFrozen) {
      _appendSample(seriesData.accelX, sample.accelXG);
      _appendSample(seriesData.accelY, sample.accelYG);
      _appendSample(seriesData.accelZ, sample.accelZG);

      _appendSample(seriesData.gyroX, sample.gyroXDegS);
      _appendSample(seriesData.gyroY, sample.gyroYDegS);
      _appendSample(seriesData.gyroZ, sample.gyroZDegS);
    }
  }

  void _appendSample(List<double> list, double value) {
    list.add(value);
    if (list.length > maxWindowSamples) {
      list.removeAt(0);
    }
  }

  void reset() {
    _lastSequence = null;
    _sequenceGaps = 0;
    _duplicatePackets = 0;
    _observedHz = 0.0;
    _sampleReceiptTimes.clear();
    seriesData.clear();
  }
}
