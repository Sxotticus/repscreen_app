import 'package:flutter/services.dart';

/// Central service for all sound effects and haptic feedback.
/// Uses Android's sine-wave generator via platform channel,
/// and Flutter's built-in HapticFeedback for vibrations.
class SoundHapticService {
  static const _channel = MethodChannel('com.repscreen/sound');
  static bool _soundEnabled = true;
  static bool _hapticEnabled = true;

  static bool get soundEnabled => _soundEnabled;
  static bool get hapticEnabled => _hapticEnabled;

  static void setSoundEnabled(bool v) => _soundEnabled = v;
  static void setHapticEnabled(bool v) => _hapticEnabled = v;

  // ─── Sound Events ──────────────────────────────────────────

  /// Short click for each rep counted
  static Future<void> playRepTick() async {
    if (!_soundEnabled) return;
    _invoke('repTick');
    _hapticLight();
  }

  /// Celebration when a full set is complete
  static Future<void> playSetComplete() async {
    if (!_soundEnabled) return;
    _invoke('setComplete');
    _hapticHeavy();
  }

  /// Warning beep when timer has < 60 seconds left
  static Future<void> playTimerWarning() async {
    if (!_soundEnabled) return;
    _invoke('timerWarning');
    _hapticMedium();
  }

  /// Alarm when timer reaches zero
  static Future<void> playTimerExpired() async {
    if (!_soundEnabled) return;
    _invoke('timerExpired');
    _hapticHeavy();
  }

  /// Achievement/milestone unlocked
  static Future<void> playMilestone() async {
    if (!_soundEnabled) return;
    _invoke('milestone');
    _hapticHeavy();
  }

  /// Short tick for countdown seconds
  static Future<void> playCountdownTick() async {
    if (!_soundEnabled) return;
    _invoke('countdownTick');
  }

  /// Button tap feedback (haptic only, no sound)
  static Future<void> tapFeedback() async {
    _hapticLight();
  }

  // ─── Haptic Events ─────────────────────────────────────────

  static void _hapticLight() {
    if (!_hapticEnabled) return;
    HapticFeedback.lightImpact();
  }

  static void _hapticMedium() {
    if (!_hapticEnabled) return;
    HapticFeedback.mediumImpact();
  }

  static void _hapticHeavy() {
    if (!_hapticEnabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Selection click — subtle feedback for toggles
  static void selectionClick() {
    if (!_hapticEnabled) return;
    HapticFeedback.selectionClick();
  }

  // ─── Private ───────────────────────────────────────────────

  static Future<void> _invoke(String sound) async {
    try {
      await _channel.invokeMethod('playSound', {'type': sound});
    } catch (_) {
      // Silently fail — sounds are nice-to-have, not critical
    }
  }
}
