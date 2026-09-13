import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/protocol/ble_uuids.dart';
import '../../../core/protocol/packet_decoder.dart';

class LiveMotionScreen extends ConsumerStatefulWidget {
  const LiveMotionScreen({super.key});

  @override
  ConsumerState<LiveMotionScreen> createState() => _LiveMotionScreenState();
}

class _LiveMotionScreenState extends ConsumerState<LiveMotionScreen> {
  StreamSubscription? _motionSubscription;

  bool _showAx = true;
  bool _showAy = true;
  bool _showAz = true;
  bool _showGx = true;
  bool _showGy = true;
  bool _showGz = true;

  bool _isRawRecording = false;

  @override
  void initState() {
    super.initState();
    final transport = ref.read(bleTransportProvider);
    final pipeline = ref.read(sensorPipelineProvider);

    _motionSubscription =
        transport.subscribeToNotifications(BleUuids.motion).listen((bytes) {
      try {
        final sample = PacketDecoder.decodeMotion(bytes);
        pipeline.processSample(sample);
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        ref
            .read(diagnosticLoggerProvider)
            .error('MotionScreen', 'Decode error: $e');
      }
    });
  }

  @override
  void dispose() {
    _motionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = ref.watch(sensorPipelineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Motion Stream (50 Hz)'),
        actions: [
          IconButton(
            icon: Icon(
              pipeline.isFrozen ? Icons.play_arrow : Icons.pause,
              color: pipeline.isFrozen ? Colors.amber : Colors.cyan,
            ),
            tooltip: pipeline.isFrozen ? 'Unfreeze Graph' : 'Freeze Graph',
            onPressed: () {
              setState(() {
                pipeline.toggleFreeze();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _buildTelemetryHeader(pipeline),
            const SizedBox(height: 12),
            _buildToggleBar(),
            const SizedBox(height: 12),
            _buildChartCard(
              title: '3-Axis Accelerometer (g)',
              series1: _showAx ? pipeline.seriesData.accelX : [],
              series2: _showAy ? pipeline.seriesData.accelY : [],
              series3: _showAz ? pipeline.seriesData.accelZ : [],
              minY: -3.0,
              maxY: 3.0,
            ),
            const SizedBox(height: 12),
            _buildChartCard(
              title: '3-Axis Gyroscope (deg/s)',
              series1: _showGx ? pipeline.seriesData.gyroX : [],
              series2: _showGy ? pipeline.seriesData.gyroY : [],
              series3: _showGz ? pipeline.seriesData.gyroZ : [],
              minY: -180.0,
              maxY: 180.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryHeader(pipeline) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Observed Rate: ${pipeline.observedHz.toStringAsFixed(1)} Hz',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
                ),
                Text(
                  'Sequence Gaps: ${pipeline.sequenceGaps} | Duplicates: ${pipeline.duplicatePackets}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            FilterChip(
              label: Text(_isRawRecording ? 'REC ON' : 'REC OFF'),
              selected: _isRawRecording,
              selectedColor: AppTheme.errorRose,
              onSelected: (val) {
                setState(() {
                  _isRawRecording = val;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleBar() {
    return Wrap(
      spacing: 6,
      children: [
        FilterChip(
          label: const Text('Ax'),
          selected: _showAx,
          selectedColor: AppTheme.axisX.withValues(alpha: 0.3),
          onSelected: (v) => setState(() => _showAx = v),
        ),
        FilterChip(
          label: const Text('Ay'),
          selected: _showAy,
          selectedColor: AppTheme.axisY.withValues(alpha: 0.3),
          onSelected: (v) => setState(() => _showAy = v),
        ),
        FilterChip(
          label: const Text('Az'),
          selected: _showAz,
          selectedColor: AppTheme.axisZ.withValues(alpha: 0.3),
          onSelected: (v) => setState(() => _showAz = v),
        ),
        FilterChip(
          label: const Text('Gx'),
          selected: _showGx,
          selectedColor: AppTheme.axisX.withValues(alpha: 0.3),
          onSelected: (v) => setState(() => _showGx = v),
        ),
        FilterChip(
          label: const Text('Gy'),
          selected: _showGy,
          selectedColor: AppTheme.axisY.withValues(alpha: 0.3),
          onSelected: (v) => setState(() => _showGy = v),
        ),
        FilterChip(
          label: const Text('Gz'),
          selected: _showGz,
          selectedColor: AppTheme.axisZ.withValues(alpha: 0.3),
          onSelected: (v) => setState(() => _showGz = v),
        ),
      ],
    );
  }

  Widget _buildChartCard({
    required String title,
    required List<double> series1,
    required List<double> series2,
    required List<double> series3,
    required double minY,
    required double maxY,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  lineBarsData: [
                    if (series1.isNotEmpty) _buildLineBarData(series1, AppTheme.axisX),
                    if (series2.isNotEmpty) _buildLineBarData(series2, AppTheme.axisY),
                    if (series3.isNotEmpty) _buildLineBarData(series3, AppTheme.axisZ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildLineBarData(List<double> values, Color color) {
    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 1.5,
      dotData: const FlDotData(show: false),
    );
  }
}
