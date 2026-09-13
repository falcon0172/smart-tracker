import 'package:uuid/uuid.dart';

import '../../../core/protocol/protocol_models.dart';
import '../domain/workout_repository.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final _uuid = const Uuid();
  final List<LocalWorkout> _workouts = [];
  final Map<String, LocalWorkoutSet> _sets = {};

  @override
  Future<LocalWorkout> startWorkout() async {
    final workout = LocalWorkout(
      id: _uuid.v4(),
      startedAtUtc: DateTime.now().toUtc(),
      status: 'active',
    );
    _workouts.add(workout);
    return workout;
  }

  @override
  Future<void> endWorkout(String workoutId) async {
    final index = _workouts.indexWhere((w) => w.id == workoutId);
    if (index != -1) {
      final old = _workouts[index];
      _workouts[index] = LocalWorkout(
        id: old.id,
        startedAtUtc: old.startedAtUtc,
        endedAtUtc: DateTime.now().toUtc(),
        status: 'completed',
        notes: old.notes,
      );
    }
  }

  @override
  Future<List<LocalWorkout>> getWorkouts() async {
    return List.unmodifiable(_workouts);
  }

  @override
  Future<LocalWorkoutSet> createDraftSet({
    required String workoutId,
    required String deviceId,
    required int bootId,
    required int wireSetId,
    double? loadKg,
    String loadConvention = 'per_dumbbell',
  }) async {
    final set = LocalWorkoutSet(
      id: _uuid.v4(),
      workoutId: workoutId,
      deviceId: deviceId,
      bootId: bootId,
      wireSetId: wireSetId,
      detectedReps: 0,
      loadKg: loadKg,
      loadConvention: loadConvention,
      startedAtUtc: DateTime.now().toUtc(),
      activeDurationMs: 0,
      status: 'draft',
      algorithmVersion: 'v1.0-curl',
      qualityFlags: 0,
    );
    _sets[set.id] = set;
    return set;
  }

  @override
  Future<void> checkpointSetState(SetSnapshot snapshot) async {
    // Find matching set by wireSetId and bootId
    final existingKey = _sets.keys.firstWhere(
      (k) =>
          _sets[k]!.bootId == snapshot.bootId &&
          _sets[k]!.wireSetId == snapshot.wireSetId,
      orElse: () => '',
    );

    if (existingKey.isNotEmpty) {
      final old = _sets[existingKey]!;
      // Reconcile rep count: never regress count
      final reps = snapshot.cumulativeReps >= old.detectedReps
          ? snapshot.cumulativeReps
          : old.detectedReps;

      _sets[existingKey] = LocalWorkoutSet(
        id: old.id,
        workoutId: old.workoutId,
        exerciseId: old.exerciseId,
        deviceId: old.deviceId,
        bootId: old.bootId,
        wireSetId: old.wireSetId,
        detectedReps: reps,
        correctedReps: old.correctedReps,
        loadKg: old.loadKg,
        loadConvention: old.loadConvention,
        startedAtUtc: old.startedAtUtc,
        endedAtUtc: snapshot.state == SetStateEnum.ended
            ? DateTime.now().toUtc()
            : old.endedAtUtc,
        activeDurationMs: snapshot.activeDurationMs,
        status: snapshot.state.name,
        algorithmVersion: old.algorithmVersion,
        qualityFlags: old.qualityFlags,
      );
    }
  }

  @override
  Future<void> saveFinalSet(LocalWorkoutSet set) async {
    // Upsert set idempotently
    _sets[set.id] = set;
  }

  @override
  Future<void> updateRepCorrection(String setId, int correctedReps) async {
    if (_sets.containsKey(setId)) {
      final old = _sets[setId]!;
      _sets[setId] = LocalWorkoutSet(
        id: old.id,
        workoutId: old.workoutId,
        exerciseId: old.exerciseId,
        deviceId: old.deviceId,
        bootId: old.bootId,
        wireSetId: old.wireSetId,
        detectedReps: old.detectedReps,
        correctedReps: correctedReps,
        loadKg: old.loadKg,
        loadConvention: old.loadConvention,
        startedAtUtc: old.startedAtUtc,
        endedAtUtc: old.endedAtUtc,
        activeDurationMs: old.activeDurationMs,
        status: old.status,
        algorithmVersion: old.algorithmVersion,
        qualityFlags: old.qualityFlags,
      );
    }
  }

  List<LocalWorkoutSet> getSetsForWorkout(String workoutId) {
    return _sets.values.where((s) => s.workoutId == workoutId).toList();
  }
}
