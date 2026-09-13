import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/protocol/ble_uuids.dart';
import '../../../core/protocol/command_encoder.dart';
import '../../../core/protocol/packet_decoder.dart';
import '../../../core/protocol/protocol_models.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  StreamSubscription? _setStateSubscription;
  StreamSubscription? _ackSubscription;

  SetSnapshot? _latestSetSnapshot;
  String _selectedExercise = 'Bicep Curl (Profile 1)';
  double _loadKg = 10.0;
  String _loadConvention = 'kg per dumbbell';

  int _commandSeq = 1;
  int _wireSetIdCounter = 1;

  @override
  void initState() {
    super.initState();
    final transport = ref.read(bleTransportProvider);

    _setStateSubscription =
        transport.subscribeToNotifications(BleUuids.setState).listen((bytes) {
      try {
        final snapshot = PacketDecoder.decodeSetState(bytes);
        if (mounted) {
          setState(() {
            _latestSetSnapshot = snapshot;
          });
        }
      } catch (e) {
        ref.read(diagnosticLoggerProvider).error('WorkoutScreen', '$e');
      }
    });

    _ackSubscription =
        transport.subscribeToNotifications(BleUuids.controlAck).listen((bytes) {
      try {
        final ack = PacketDecoder.decodeControlAck(bytes);
        ref
            .read(diagnosticLoggerProvider)
            .info('WorkoutScreen', 'ACK opcode ${ack.opcode.name} res=${ack.resultCode.name}');
      } catch (e) {
        ref.read(diagnosticLoggerProvider).error('WorkoutScreen', '$e');
      }
    });
  }

  @override
  void dispose() {
    _setStateSubscription?.cancel();
    _ackSubscription?.cancel();
    super.dispose();
  }

  void _sendControlCommand(OpcodeEnum opcode, {int argument = 0}) {
    final transport = ref.read(bleTransportProvider);
    final command = ControlCommand(
      protocolVersion: 1,
      opcode: opcode,
      commandId: _commandSeq++,
      expectedBootId: _latestSetSnapshot?.bootId ?? 0x11223344,
      wireSetId: _latestSetSnapshot?.wireSetId ?? _wireSetIdCounter,
      argument: argument,
    );

    final bytes = CommandEncoder.encodeControl(command);
    transport.writeCharacteristic(BleUuids.control, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _latestSetSnapshot;
    final currentState = snapshot?.state ?? SetStateEnum.idle;
    final repCount = snapshot?.cumulativeReps ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Workout Set'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildExerciseSelector(),
            const SizedBox(height: 12),
            _buildMountingGuidanceCard(),
            const SizedBox(height: 16),
            _buildRepCounterCard(repCount, currentState),
            const SizedBox(height: 16),
            _buildLoadEntryRow(),
            const Spacer(),
            _buildSetControlButtons(currentState),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Exercise:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _selectedExercise,
              dropdownColor: AppTheme.cardSurface,
              items: const [
                DropdownMenuItem(
                  value: 'Bicep Curl (Profile 1)',
                  child: Text('Bicep Curl (Firmware Profile 1)'),
                ),
                DropdownMenuItem(
                  value: 'Hammer Curl (Experimental)',
                  child: Text('Hammer Curl (Experimental)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedExercise = val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMountingGuidanceCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.vibration, color: AppTheme.primaryCyan),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mount board securely to upper dumbbell head. Maintain still initial posture before starting set.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepCounterCard(int repCount, SetStateEnum state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
        child: Column(
          children: [
            Text(
              '$repCount',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryCyan,
              ),
            ),
            const Text(
              'FIRMWARE DETECTED REPS',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Chip(
              label: Text(state.name.toUpperCase()),
              backgroundColor: state == SetStateEnum.counting
                  ? Colors.green.shade900
                  : Colors.amber.shade900,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadEntryRow() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Weight Load:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_loadConvention,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    if (_loadKg > 1.0) setState(() => _loadKg -= 1.0);
                  },
                ),
                Text(
                  '${_loadKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    setState(() => _loadKg += 1.0);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetControlButtons(SetStateEnum state) {
    if (state == SetStateEnum.idle || state == SetStateEnum.ended) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentEmerald,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: const Icon(Icons.play_arrow, color: Colors.black),
        label: const Text('START SET', style: TextStyle(color: Colors.black)),
        onPressed: () {
          _wireSetIdCounter++;
          _sendControlCommand(OpcodeEnum.startSet, argument: 1); // Profile 1
        },
      );
    } else if (state == SetStateEnum.counting) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningAmber,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.pause, color: Colors.black),
              label: const Text('PAUSE', style: TextStyle(color: Colors.black)),
              onPressed: () => _sendControlCommand(OpcodeEnum.pauseSet),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRose,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.stop, color: Colors.white),
              label: const Text('END SET', style: TextStyle(color: Colors.white)),
              onPressed: () => _sendControlCommand(OpcodeEnum.endSet),
            ),
          ),
        ],
      );
    } else {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryCyan,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: const Icon(Icons.play_arrow, color: Colors.black),
        label: const Text('RESUME SET', style: TextStyle(color: Colors.black)),
        onPressed: () => _sendControlCommand(OpcodeEnum.resumeSet),
      );
    }
  }
}
