abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

class FakeClock implements Clock {
  DateTime _now;

  FakeClock([DateTime? initial]) : _now = initial ?? DateTime.utc(2026, 1, 1);

  @override
  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  void setTime(DateTime time) {
    _now = time.toUtc();
  }
}
