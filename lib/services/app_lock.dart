import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'settings.dart';

/// Keeps the diary behind the device's fingerprint / face / screen lock.
class AppLockController extends ChangeNotifier {
  AppLockController(this.settings) : _locked = settings.appLock;

  final SettingsController settings;
  final _auth = LocalAuthentication();

  bool _locked;
  bool _authenticating = false;
  int _suspended = 0;
  DateTime? _hiddenAt;
  String? lastError;

  bool get locked => _locked;

  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Unlock your diary'}) async {
    if (_authenticating) return false;
    _authenticating = true;
    lastError = null;
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } on LocalAuthException catch (e) {
      lastError = switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet => 'Set up a screen lock on your phone first.',
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => 'Too many attempts. Try again in a moment.',
        LocalAuthExceptionCode.userCanceled || LocalAuthExceptionCode.systemCanceled => null,
        _ => e.description ?? 'Couldn’t verify it’s you.',
      };
      return false;
    } catch (e) {
      lastError = 'Couldn’t verify it’s you.';
      return false;
    } finally {
      _authenticating = false;
    }
  }

  Future<void> unlock() async {
    if (!_locked) return;
    if (await authenticate()) {
      _locked = false;
    }
    notifyListeners();
  }

  /// Turns the lock on or off. Turning it on requires one successful unlock.
  Future<bool> setEnabled(bool enabled) async {
    if (enabled) {
      if (!await isSupported()) {
        lastError = 'This phone has no fingerprint, face or screen lock set up.';
        return false;
      }
      if (!await authenticate(reason: 'Confirm it’s you to turn on the app lock')) return false;
    }
    settings.appLock = enabled;
    _locked = false;
    notifyListeners();
    return true;
  }

  /// Run [action] (a file picker, share sheet...) without locking when we come back.
  Future<T> suspendWhile<T>(Future<T> Function() action) async {
    _suspended++;
    try {
      return await action();
    } finally {
      // The resume event arrives a moment after the other activity closes.
      unawaited(Future<void>.delayed(const Duration(seconds: 1), () => _suspended--));
    }
  }

  void onHidden() {
    if (!settings.appLock || _authenticating || _suspended > 0) return;
    _hiddenAt = DateTime.now();
    if (settings.lockDelaySeconds == 0 && !_locked) {
      _locked = true;
      notifyListeners();
    }
  }

  void onResumed() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (!settings.appLock || _locked || hiddenAt == null || _suspended > 0) return;
    if (DateTime.now().difference(hiddenAt).inSeconds >= settings.lockDelaySeconds) {
      _locked = true;
      notifyListeners();
    }
  }
}
