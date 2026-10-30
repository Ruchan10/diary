import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Small bits of Android the plugins don't cover. See MainActivity.kt.
abstract final class PlatformBridge {
  static const _channel = MethodChannel('com.inovaara.inkling/window');

  /// Hides the app content in the recent-apps switcher and blocks screenshots.
  static Future<void> setSecure(bool secure) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } catch (e) {
      debugPrint('Inkling: setSecure failed: $e');
    }
  }

  /// Opens the system notification settings page for Inkling.
  static Future<void> openNotificationSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (e) {
      debugPrint('Inkling: openNotificationSettings failed: $e');
    }
  }
}
