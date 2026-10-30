import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/dates.dart';

enum LaunchBehavior {
  alwaysAsk('Ask about today', 'Open straight to the writing screen'),
  askIfEmpty('Ask until I’ve written', 'Ask only if today is still blank'),
  calendar('Show the calendar', 'Open on the calendar');

  const LaunchBehavior(this.label, this.description);

  final String label;
  final String description;
}

enum WritingFont {
  classic('Classic serif'),
  clean('Clean sans'),
  handwritten('Handwritten'),
  typewriter('Typewriter');

  const WritingFont(this.label);

  final String label;
}

enum CalendarStyle { ink, mood }

/// User preferences, persisted with shared_preferences.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  static Future<SettingsController> load() async => SettingsController(
    await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions()),
  );

  final SharedPreferencesWithCache _prefs;
  late final int _localeWeekday = localeFirstWeekday();

  T _enum<T extends Enum>(String key, List<T> values, T fallback) {
    final name = _prefs.getString(key);
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  void _set(String key, Object? value) {
    switch (value) {
      case null:
        _prefs.remove(key);
      case bool v:
        _prefs.setBool(key, v);
      case int v:
        _prefs.setInt(key, v);
      case double v:
        _prefs.setDouble(key, v);
      case String v:
        _prefs.setString(key, v);
      case Enum v:
        _prefs.setString(key, v.name);
      case DateTime v:
        _prefs.setInt(key, v.millisecondsSinceEpoch);
      case List<String> v:
        _prefs.setStringList(key, v);
    }
    notifyListeners();
  }

  DateTime? _time(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // Appearance
  ThemeMode get themeMode => _enum('themeMode', ThemeMode.values, ThemeMode.system);
  set themeMode(ThemeMode v) => _set('themeMode', v);

  bool get dynamicColor => _prefs.getBool('dynamicColor') ?? false;
  set dynamicColor(bool v) => _set('dynamicColor', v);

  int get accent => _prefs.getInt('accent') ?? 0;
  set accent(int v) => _set('accent', v);

  WritingFont get writingFont => _enum('writingFont', WritingFont.values, WritingFont.classic);
  set writingFont(WritingFont v) => _set('writingFont', v);

  double get fontSize => _prefs.getDouble('fontSize') ?? 18;
  set fontSize(double v) => _set('fontSize', v);

  CalendarStyle get calendarStyle => _enum('calendarStyle', CalendarStyle.values, CalendarStyle.ink);
  set calendarStyle(CalendarStyle v) => _set('calendarStyle', v);

  // Fun stuff
  /// Confetti and cheers for finished pages, streaks and new stickers.
  bool get celebrations => _prefs.getBool('celebrations') ?? true;
  set celebrations(bool v) => _set('celebrations', v);

  /// Inky blinks, bobs and hops. Off also stops other decorative motion.
  bool get animatedInky => _prefs.getBool('animatedInky') ?? true;
  set animatedInky(bool v) => _set('animatedInky', v);

  /// Stickers already celebrated. Null until the sticker book first runs.
  List<String>? get seenStickers => _prefs.getStringList('seenStickers');
  set seenStickers(List<String>? v) => _set('seenStickers', v);

  // Writing
  LaunchBehavior get launchBehavior => _enum('launchBehavior', LaunchBehavior.values, LaunchBehavior.alwaysAsk);
  set launchBehavior(LaunchBehavior v) => _set('launchBehavior', v);

  bool get playfulPrompts => _prefs.getBool('playfulPrompts') ?? true;
  set playfulPrompts(bool v) => _set('playfulPrompts', v);

  bool get showWordCount => _prefs.getBool('showWordCount') ?? true;
  set showWordCount(bool v) => _set('showWordCount', v);

  /// 0 follows the device locale, otherwise [DateTime.monday]..[DateTime.sunday].
  int get weekStart => _prefs.getInt('weekStart') ?? 0;
  set weekStart(int v) => _set('weekStart', v);

  int get firstWeekday => weekStart == 0 ? _localeWeekday : weekStart;

  // Reminders
  bool get reminderEnabled => _prefs.getBool('reminderEnabled') ?? false;
  set reminderEnabled(bool v) => _set('reminderEnabled', v);

  TimeOfDay get reminderTime {
    final m = _prefs.getInt('reminderMinutes') ?? 21 * 60;
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  set reminderTime(TimeOfDay v) => _set('reminderMinutes', v.hour * 60 + v.minute);

  // Privacy
  bool get appLock => _prefs.getBool('appLock') ?? false;
  set appLock(bool v) => _set('appLock', v);

  int get lockDelaySeconds => _prefs.getInt('lockDelaySeconds') ?? 0;
  set lockDelaySeconds(int v) => _set('lockDelaySeconds', v);

  bool get secureScreen => _prefs.getBool('secureScreen') ?? false;
  set secureScreen(bool v) => _set('secureScreen', v);

  // Updates & backups
  bool get autoCheckUpdates => _prefs.getBool('autoCheckUpdates') ?? true;
  set autoCheckUpdates(bool v) => _set('autoCheckUpdates', v);

  DateTime? get lastUpdateCheck => _time('lastUpdateCheck');
  set lastUpdateCheck(DateTime? v) => _set('lastUpdateCheck', v);

  String? get skippedVersion => _prefs.getString('skippedVersion');
  set skippedVersion(String? v) => _set('skippedVersion', v);

  DateTime? get lastBackupAt => _time('lastBackupAt');
  set lastBackupAt(DateTime? v) => _set('lastBackupAt', v);
}
