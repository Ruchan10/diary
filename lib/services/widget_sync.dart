import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../config.dart';
import '../data/entry_repository.dart';
import '../theme/theme.dart';
import '../utils/dates.dart';
import '../utils/stats.dart';
import 'settings.dart';

/// Pushes a compact snapshot of the diary to the Android home-screen widget.
///
/// The widget works out "today", the week strip and whether the streak is
/// still alive by itself, so it stays correct after midnight even when the
/// app isn't running. We still ask for an update shortly after each midnight.
class WidgetSync {
  WidgetSync(this.repo, this.settings);

  final EntryRepository repo;
  final SettingsController settings;

  /// Wallpaper colour on Android 12+, when Material You is switched on.
  Color? dynamicSeed;

  Timer? _debounce;
  String? _lastPayload;
  String? _scheduledFrom;

  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), sync);
  }

  Future<void> sync() async {
    _debounce?.cancel();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final t = today();
    final keys = repo.dateKeys;
    final run = latestRun(keys, t);
    final from = dateKey(addDays(t, -45));
    final recent = keys.where((k) => k.compareTo(from) >= 0).toList()..sort();
    final latest = repo.latestOnOrBefore(t);
    final seed = accentSeed(settings, dynamicSeed: dynamicSeed);
    final light = schemeFor(seed, Brightness.light);
    final dark = schemeFor(seed, Brightness.dark);

    final payload = jsonEncode({
      'entryDates': recent,
      'runEnd': run.end,
      'runLength': run.length,
      'snippet': latest == null ? '' : _clip(latest.preview, 180),
      'snippetDate': latest?.date,
      'firstWeekday': settings.firstWeekday,
      'total': repo.count,
      'colors': {
        for (final (name, l, d) in [
          ('bg', light.surfaceContainerLow, dark.surfaceContainer),
          ('fg', light.onSurface, dark.onSurface),
          ('muted', light.onSurfaceVariant, dark.onSurfaceVariant),
          ('accent', light.primary, dark.primary),
          ('onAccent', light.onPrimary, dark.onPrimary),
          ('soft', light.primaryContainer, dark.primaryContainer),
          ('onSoft', light.onPrimaryContainer, dark.onPrimaryContainer),
        ])
          name: [l.toARGB32(), d.toARGB32()],
      },
    });

    try {
      if (payload != _lastPayload) {
        await HomeWidget.saveWidgetData<String>('inkling_state', payload);
        await HomeWidget.updateWidget(qualifiedAndroidName: AppConfig.widgetProvider);
        _lastPayload = payload;
      }
      final todayKey = dateKey(t);
      if (_scheduledFrom != todayKey) {
        await HomeWidget.scheduleWidgetUpdates(
          [for (var i = 1; i <= 14; i++) addDays(t, i).add(const Duration(seconds: 20))],
          qualifiedAndroidName: AppConfig.widgetProvider,
        );
        _scheduledFrom = todayKey;
      }
    } catch (e) {
      debugPrint('Inkling: widget sync failed: $e');
    }
  }

  static String _clip(String s, int max) => s.length <= max ? s : '${s.substring(0, max - 1).trimRight()}…';
}
