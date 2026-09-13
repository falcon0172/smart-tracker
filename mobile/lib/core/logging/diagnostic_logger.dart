import 'dart:collection';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] [${level.name.toUpperCase()}] [$tag] $message';
}

class DiagnosticLogger {
  final int maxEntries;
  final Queue<LogEntry> _logs = Queue<LogEntry>();

  DiagnosticLogger({this.maxEntries = 500});

  void log(LogLevel level, String tag, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now().toUtc(),
      level: level,
      tag: tag,
      message: _redact(message),
    );

    _logs.addLast(entry);
    if (_logs.length > maxEntries) {
      _logs.removeFirst();
    }
  }

  void debug(String tag, String message) => log(LogLevel.debug, tag, message);
  void info(String tag, String message) => log(LogLevel.info, tag, message);
  void warning(String tag, String message) => log(LogLevel.warning, tag, message);
  void error(String tag, String message) => log(LogLevel.error, tag, message);

  List<LogEntry> get entries => List.unmodifiable(_logs);

  void clear() => _logs.clear();

  String _redact(String text) {
    // Redact MAC addresses or potential Bluetooth unique identifiers in logs
    return text.replaceAll(
      RegExp(r'([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})'),
      '[REDACTED_MAC]',
    );
  }
}
