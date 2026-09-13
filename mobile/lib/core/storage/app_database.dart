import 'package:drift/drift.dart';

import 'tables.dart';

@DriftDatabase(tables: [
  Devices,
  Exercises,
  Workouts,
  WorkoutSets,
  Recordings,
  AppSettings,
])
class AppDatabase {
  final QueryExecutor executor;

  AppDatabase(this.executor);
}
