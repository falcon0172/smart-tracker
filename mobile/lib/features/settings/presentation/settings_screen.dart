import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _usePounds = false;
  String _loadConvention = 'kg per dumbbell';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Display Weight in Pounds (lb)'),
              subtitle: const Text(
                  'Converts weight displays at boundaries without doubling values'),
              value: _usePounds,
              onChanged: (val) {
                setState(() => _usePounds = val);
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Default Load Convention'),
              subtitle: Text(_loadConvention),
              trailing: DropdownButton<String>(
                value: _loadConvention,
                items: const [
                  DropdownMenuItem(
                    value: 'kg per dumbbell',
                    child: Text('kg per dumbbell (Unilateral)'),
                  ),
                  DropdownMenuItem(
                    value: 'total load',
                    child: Text('total external load'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _loadConvention = val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear All Offline Workout Data'),
              subtitle: const Text('Deletes local SQLite storage and private recordings'),
              onTap: () {
                _showDeleteConfirmationDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Data Erasure'),
        content: const Text(
            'This action will erase all locally saved workouts, sets, and diagnostic recordings. This operation cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Local workout data cleared.')),
              );
            },
            child: const Text('Delete Data'),
          ),
        ],
      ),
    );
  }
}
