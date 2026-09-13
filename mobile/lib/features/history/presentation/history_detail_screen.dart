import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/services/haptics_service.dart';
import '../domain/set_analytics.dart';

class HistoryDetailScreen extends StatelessWidget {
  final String workoutTitle;
  final SetAnalytics analytics;

  const HistoryDetailScreen({
    super.key,
    this.workoutTitle = 'Bicep Curl — Set 1 Analytics',
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(workoutTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              HapticsService.buttonClick();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Session analytics ready for export.')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOverallCard(),
              const SizedBox(height: 16),
              _buildMetricsGrid(),
              const SizedBox(height: 16),
              _buildFatigueCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Text(
            'TOTAL REPETITIONS',
            style: TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 1.2),
          ),
          Text(
            '${analytics.totalReps}',
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryCyan,
            ),
          ),
          const SizedBox(height: 8),
          Chip(
            label: Text(
              'TEMPO CONSISTENCY: ${analytics.tempoConsistencyPercent.toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.accentEmerald,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            'Peak Gyroscope',
            '${analytics.peakGyroDegS.toStringAsFixed(1)} °/s',
            Icons.speed,
            Colors.cyan,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            'Peak Acceleration',
            '${analytics.peakAccelG.toStringAsFixed(2)} g',
            Icons.bolt,
            Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFatigueCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_down, color: AppTheme.accentEmerald),
              SizedBox(width: 8),
              Text(
                'Rep Fatigue Index',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Velocity drop-off across set: ${analytics.fatigueIndexPercent.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (100.0 - analytics.fatigueIndexPercent) / 100.0,
            backgroundColor: Colors.red.shade900,
            color: AppTheme.accentEmerald,
          ),
        ],
      ),
    );
  }
}
