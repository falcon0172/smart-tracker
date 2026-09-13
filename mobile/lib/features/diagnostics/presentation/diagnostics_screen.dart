import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.watch(diagnosticLoggerProvider);
    final entries = logger.entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics & Event Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Logs',
            onPressed: () {
              logger.clear();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Log Entries:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${entries.length} / ${logger.maxEntries}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Text('No diagnostic logs recorded yet.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[entries.length - 1 - index];
                        return Card(
                          child: ListTile(
                            dense: true,
                            title: Text('[${entry.tag}] ${entry.message}',
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 12)),
                            subtitle: Text(entry.timestamp.toIso8601String(),
                                style: const TextStyle(fontSize: 10)),
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
