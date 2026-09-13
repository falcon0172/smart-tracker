import 'package:drift/drift.dart';

class Devices extends Table {
  TextColumn get id => text()();
  IntColumn get stableDeviceId => integer()();
  TextColumn get platformRemoteId => text()();
  TextColumn get platform => text()();
  TextColumn get displayName => text()();
  TextColumn get firmwareVersion => text()();
  IntColumn get protocolVersion => integer()();
  DateTimeColumn get lastSeenUtc => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get profileId => integer().nullable()();
  TextColumn get validationStatus => text()();
  TextColumn get mountingNotes => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Workouts extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAtUtc => dateTime()();
  DateTimeColumn get endedAtUtc => dateTime().nullable()();
  TextColumn get status => text()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutSets extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId => text().references(Workouts, #id)();
  TextColumn get exerciseId => text().nullable().references(Exercises, #id)();
  TextColumn get deviceId => text().references(Devices, #id)();
  IntColumn get bootId => integer()();
  IntColumn get wireSetId => integer()();
  IntColumn get detectedReps => integer()();
  IntColumn get correctedReps => integer().nullable()();
  RealColumn get loadKg => real().nullable()();
  TextColumn get loadConvention => text()(); // 'per_dumbbell' or 'total_load'
  DateTimeColumn get startedAtUtc => dateTime()();
  DateTimeColumn get endedAtUtc => dateTime().nullable()();
  IntColumn get activeDurationMs => integer()();
  TextColumn get status => text()();
  TextColumn get algorithmVersion => text()();
  IntColumn get qualityFlags => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Recordings extends Table {
  TextColumn get id => text()();
  TextColumn get setId => text().nullable().references(WorkoutSets, #id)();
  TextColumn get privatePath => text()();
  IntColumn get sampleCount => integer()();
  IntColumn get missingSamples => integer()();
  IntColumn get overflowSamples => integer()();
  DateTimeColumn get startedAtUtc => dateTime()();
  DateTimeColumn get endedAtUtc => dateTime()();
  IntColumn get formatVersion => integer()();
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get typedValue => text()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
