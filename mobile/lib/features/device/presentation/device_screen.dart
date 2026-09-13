import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/ble/ble_transport.dart';

class DeviceScreen extends ConsumerWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleTransport = ref.watch(bleTransportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Connection'),
      ),
      body: StreamBuilder<TransportConnectionState>(
        stream: bleTransport.connectionStateStream,
        initialData: bleTransport.currentConnectionState,
        builder: (context, snapshot) {
          final state = snapshot.data ?? TransportConnectionState.disconnected;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusCard(context, bleTransport, state, bleTransport.isMockMode),
                const SizedBox(height: 16),
                _buildPermissionBanner(),
                const SizedBox(height: 16),
                const Text(
                  'Available Devices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildDeviceList(context, bleTransport, state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, BleTransport transport,
      TransportConnectionState state, bool isMock) {
    Color badgeColor;
    String statusText;

    switch (state) {
      case TransportConnectionState.ready:
        badgeColor = Colors.green;
        statusText = 'Connected & Protocol Ready';
        break;
      case TransportConnectionState.scanning:
        badgeColor = Colors.orange;
        statusText = 'Scanning for XIAO Tracker...';
        break;
      case TransportConnectionState.connecting:
      case TransportConnectionState.discovering:
      case TransportConnectionState.negotiating:
        badgeColor = Colors.cyan;
        statusText = 'Negotiating GATT Connection...';
        break;
      default:
        badgeColor = Colors.red;
        statusText = 'Disconnected';
        break;
    }

    final isConnected = state == TransportConnectionState.ready ||
        state == TransportConnectionState.connecting ||
        state == TransportConnectionState.discovering ||
        state == TransportConnectionState.negotiating;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: badgeColor, radius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusText,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isConnected)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.bluetooth_disabled, size: 18),
                    label: const Text('Disconnect'),
                    onPressed: () => transport.disconnect(),
                  ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mode:', style: TextStyle(color: Colors.grey)),
                Chip(
                  label: Text(isMock ? 'SIMULATED MOCK' : 'REAL BLE'),
                  backgroundColor:
                      isMock ? Colors.amber.shade900 : Colors.blue.shade900,
                ),
              ],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Target Service:', style: TextStyle(color: Colors.grey)),
                Text('6f4c0001-b5a3-...',
                    style: TextStyle(fontFamily: 'monospace')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.cyan),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bluetooth permissions are required to scan for the XIAO nRF52840 Sense hardware.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, BleTransport transport,
      TransportConnectionState state) {
    return StreamBuilder<List<DiscoveredDevice>>(
      stream: transport.scanResultsStream,
      initialData: const [],
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];

        if (devices.isEmpty && state == TransportConnectionState.disconnected) {
          return Center(
            child: ElevatedButton.icon(
              onPressed: () => transport.startScan(),
              icon: const Icon(Icons.search),
              label: const Text('Scan for XIAO Tracker'),
            ),
          );
        }

        return ListView.builder(
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final dev = devices[index];
            final isConnected = state == TransportConnectionState.ready;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth, color: Colors.cyan),
                title: Text(dev.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: ${dev.id} | RSSI: ${dev.rssi} dBm'),
                trailing: isConnected
                    ? OutlinedButton(
                        onPressed: () => transport.disconnect(),
                        child: const Text('Disconnect'),
                      )
                    : ElevatedButton(
                        onPressed: () => transport.connect(dev.id),
                        child: const Text('Connect'),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
