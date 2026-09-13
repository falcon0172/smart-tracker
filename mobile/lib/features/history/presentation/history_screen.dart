import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/services/haptics_service.dart';
import '../domain/set_analytics.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: () {
              HapticsService.buttonClick();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV Export ready. Selected sets exported.'),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.fitness_center, color: AppTheme.primaryCyan),
                title: const Text('Bicep Curl — 3 Sets Completed'),
                subtitle: const Text(
                    '2026-09-13 | Total Volume: 360 kg (10.0 kg/dumbbell)'),
                trailing: const Icon(Icons.analytics_outlined),
                onTap: () {
                  HapticsService.buttonClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryDetailScreen(
                        analytics: SetAnalytics(
                          totalReps: 12,
                          peakGyroDegS: 87.4,
                          peakAccelG: 1.62,
                          avgRepDurationSec: 1.85,
                          tempoConsistencyPercent: 94.2,
                          fatigueIndexPercent: 6.8,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

