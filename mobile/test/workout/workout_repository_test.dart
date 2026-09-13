import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tracker/core/protocol/protocol_models.dart';
import 'package:smart_tracker/features/workout/data/workout_repository_impl.dart';

void main() {
  group('WorkoutRepository — Set Lifecycle & Corrections', () {
    late WorkoutRepositoryImpl repository;

    setUp(() {
      repository = WorkoutRepositoryImpl();
    });

    test('startWorkout and createDraftSet generate valid UUIDs', () async {
      final workout = await repository.startWorkout();
      expect(workout.id.length, greaterThan(20));
      expect(workout.status, equals('active'));

      final draft = await repository.createDraftSet(
        workoutId: workout.id,
        deviceId: 'DEV_01',
        bootId: 0x11223344,
        wireSetId: 1,
        loadKg: 12.5,
        loadConvention: 'per_dumbbell',
      );

      expect(draft.workoutId, equals(workout.id));
      expect(draft.loadKg, equals(12.5));
      expect(draft.loadConvention, equals('per_dumbbell'));
      expect(draft.detectedReps, equals(0));
    });

    test('checkpointSetState updates reps without regression', () async {
      final workout = await repository.startWorkout();
      await repository.createDraftSet(
        workoutId: workout.id,
        deviceId: 'DEV_01',
        bootId: 0x11223344,
        wireSetId: 1,
      );

      // Checkpoint 1: 10 reps
      await repository.checkpointSetState(const SetSnapshot(
        protocolVersion: 1,
        state: SetStateEnum.counting,
        stateRevision: 1,
        bootId: 0x11223344,
        wireSetId: 1,
        cumulativeReps: 10,
        activeDurationMs: 15000,
      ));

      var sets = repository.getSetsForWorkout(workout.id);
      expect(sets.first.detectedReps, equals(10));

      // Checkpoint 2: Stale/Regressed count (8 reps) -> preserved at 10
      await repository.checkpointSetState(const SetSnapshot(
        protocolVersion: 1,
        state: SetStateEnum.counting,
        stateRevision: 2,
        bootId: 0x11223344,
        wireSetId: 1,
        cumulativeReps: 8,
        activeDurationMs: 16000,
      ));

      sets = repository.getSetsForWorkout(workout.id);
      expect(sets.first.detectedReps, equals(10)); // Preserved highest count
    });

    test('updateRepCorrection retains original detectedReps', () async {
      final workout = await repository.startWorkout();
      final draft = await repository.createDraftSet(
        workoutId: workout.id,
        deviceId: 'DEV_01',
        bootId: 0x11223344,
        wireSetId: 1,
      );

      await repository.checkpointSetState(const SetSnapshot(
        protocolVersion: 1,
        state: SetStateEnum.ended,
        stateRevision: 1,
        bootId: 0x11223344,
        wireSetId: 1,
        cumulativeReps: 10,
        activeDurationMs: 20000,
      ));

      // User corrects reps from 10 to 12
      await repository.updateRepCorrection(draft.id, 12);

      final updated = repository.getSetsForWorkout(workout.id).first;
      expect(updated.detectedReps, equals(10)); // Original preserved
      expect(updated.correctedReps, equals(12)); // User correction
      expect(updated.effectiveReps, equals(12)); // Effective display value
    });
  });
}
