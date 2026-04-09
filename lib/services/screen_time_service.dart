import 'package:flutter/services.dart';

/// Talks to native Android code for app-blocking & screen-time enforcement.
class ScreenTimeBlockingService {
  static const _ch = MethodChannel('com.repscreen/blocking');

  /// Returns list of launchable apps [{package, name}, ...]
  static Future<List<Map<String, String>>> getInstalledApps() async {
    final result = await _ch.invokeMethod('getInstalledApps');
    return (result as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  // â”€â”€ permissions â”€â”€

  static Future<bool> hasUsagePermission() async =>
      await _ch.invokeMethod('hasUsagePermission') as bool;

  static Future<void> requestUsagePermission() =>
      _ch.invokeMethod('requestUsagePermission');

  static Future<bool> hasOverlayPermission() async =>
      await _ch.invokeMethod('hasOverlayPermission') as bool;

  static Future<void> requestOverlayPermission() =>
      _ch.invokeMethod('requestOverlayPermission');

  // â”€â”€ service control â”€â”€

  /// Start the background timer + blocking service.
  static Future<void> startBlocking({
    required int seconds,
    required List<String> blockedApps,
  }) =>
      _ch.invokeMethod('startBlocking', {
        'seconds': seconds,
        'apps': blockedApps,
      });

  /// Stop the blocking service.
  static Future<void> stopBlocking() => _ch.invokeMethod('stopBlocking');
}