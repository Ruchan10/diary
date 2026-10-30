import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/entry_repository.dart';
import '../utils/dates.dart';
import 'settings.dart';

const _messages = [
  ('Psst! Inky here 💧', 'What happened today? Tell me everything.'),
  ('A little ink before bed? ✍️', 'Even one line counts.'),
  ('Inky is getting bored…', 'Got a story for me today?'),
  ('Today deserves a page 📖', 'Tap to spill the ink.'),
  ('How was today, really?', 'Inky is all ears 👂'),
  ('Don’t forget me! 🥺', 'Your diary misses you.'),
];

/// Daily "write something" nudges.
///
/// Instead of one repeating notification we schedule a one-off reminder for
/// each of the next few weeks. That lets us drop today's reminder as soon as
/// today's entry exists, so it never nags after you've already written.
class ReminderService {
  ReminderService(this.repo, this.settings);

  final EntryRepository repo;
  final SettingsController settings;

  static const _channelId = 'daily_reminder';
  static const _baseId = 1000;
  static const _horizonDays = 21;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tzReady = false;
  String? _signature;
  Future<void>? _running;

  /// Called with the payload when a reminder is tapped while the app runs.
  void Function(String? payload)? onTap;

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Returns the payload of the reminder that launched the app, if any.
  Future<String?> init() async {
    if (!_supported) return null;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_inkling')),
      onDidReceiveNotificationResponse: (response) => onTap?.call(response.payload),
    );
    _initialized = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      return launch!.notificationResponse?.payload ?? 'write';
    }
    return null;
  }

  Future<bool> requestPermission() async {
    if (!_supported) return false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> notificationsAllowed() async {
    if (!_supported) return false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  /// Brings the scheduled reminders in line with the settings and today's entry.
  /// Cheap to call often: it only touches the scheduler when something changed.
  Future<void> sync({bool force = false}) {
    final previous = _running ?? Future<void>.value();
    final next = previous.then((_) => _sync(force)).catchError((Object e) {
      debugPrint('Inkling: reminder sync failed: $e');
    });
    _running = next;
    return next;
  }

  Future<void> _sync(bool force) async {
    if (!_supported || !_initialized) return;
    final t = today();
    final time = settings.reminderTime;
    final enabled = settings.reminderEnabled;
    final writtenToday = repo.hasEntry(t);
    final signature = '$enabled|${time.hour}:${time.minute}|${dateKey(t)}|$writtenToday';
    if (!force && signature == _signature) return;

    await _ensureTimeZone();
    await _plugin.cancelAllPendingNotifications();
    if (!enabled) {
      _signature = signature;
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Daily reminder',
        channelDescription: 'A gentle nudge to write about your day',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        color: const Color(0xFF4F55D9),
      ),
    );
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < _horizonDays; i++) {
      if (i == 0 && writtenToday) continue;
      final day = addDays(t, i);
      final when = tz.TZDateTime(tz.local, day.year, day.month, day.day, time.hour, time.minute);
      if (!when.isAfter(now)) continue;
      final (title, body) = _messages[dayOfYear(day) % _messages.length];
      await _plugin.zonedSchedule(
        id: _baseId + i,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        payload: 'write:${dateKey(day)}',
      );
    }
    // Only remembered once everything is scheduled, so a failure retries next time.
    _signature = signature;
  }

  Future<void> _ensureTimeZone() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Inkling: could not resolve the local time zone ($e), reminders use UTC offsets');
      final offset = DateTime.now().timeZoneOffset;
      final match = tz.timeZoneDatabase.locations.values.where((l) => l.currentTimeZone.offset == offset);
      if (match.isNotEmpty) tz.setLocalLocation(match.first);
    }
    _tzReady = true;
  }
}
