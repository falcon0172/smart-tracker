import 'package:flutter/services.dart';

class HapticsService {
  static Future<void> repDetected() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> setStarted() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static Future<void> setEnded() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  static Future<void> buttonClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
