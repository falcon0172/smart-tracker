import '../../../core/protocol/protocol_models.dart';

class LocalWorkout {
  final String id;
  final DateTime startedAtUtc;
  final DateTime? endedAtUtc;
  final String status;
  final String? notes;

  const LocalWorkout({
    required this.id,
    required this.startedAtUtc,
    this.endedAtUtc,
    required this.status,
    this.notes,
  });
}

class LocalWorkoutSet {
  final String id;
  final String workoutId;
  final String? exerciseId;
  final String deviceId;
  final int bootId;
  final int wireSetId;
  final int detectedReps;
  final int? correctedReps;
  final double? loadKg;
  final String loadConvention; // 'per_dumbbell' or 'total_load'
  final DateTime startedAtUtc;
  final DateTime? endedAtUtc;
  final int activeDurationMs;
  final String status;
  final String algorithmVersion;
  final int qualityFlags;

  const LocalWorkoutSet({
    required this.id,
    required this.workoutId,
    this.exerciseId,
    required this.deviceId,
    required this.bootId,
    required this.wireSetId,
    required this.detectedReps,
    this.correctedReps,
    this.loadKg,
    required this.loadConvention,
    required this.startedAtUtc,
    this.endedAtUtc,
    required this.activeDurationMs,
    required this.status,
    required this.algorithmVersion,
    required this.qualityFlags,
  });

  int get effectiveReps => correctedReps ?? detectedReps;
}

abstract class WorkoutRepository {
  Future<LocalWorkout> startWorkout();
  Future<void> endWorkout(String workoutId);
  Future<List<LocalWorkout>> getWorkouts();

  Future<LocalWorkoutSet> createDraftSet({
    required String workoutId,
    required String deviceId,
    required int bootId,
    required int wireSetId,
    double? loadKg,
    String loadConvention = 'per_dumbbell',
  });

  Future<void> checkpointSetState(SetSnapshot snapshot);
  Future<void> saveFinalSet(LocalWorkoutSet set);
  Future<void> updateRepCorrection(String setId, int correctedReps);
}
