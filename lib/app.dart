import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';

import 'config.dart';
import 'data/entry_repository.dart';
import 'navigation.dart';
import 'screens/lock_screen.dart';
import 'services/app_lock.dart';
import 'services/celebrations.dart';
import 'services/platform_bridge.dart';
import 'services/reminders.dart';
import 'services/settings.dart';
import 'services/update_checker.dart';
import 'services/widget_sync.dart';
import 'theme/theme.dart';
import 'utils/dates.dart';
import 'widgets/celebration_layer.dart';

class AppServices {
  AppServices({
    required this.repo,
    required this.settings,
    required this.lock,
    required this.reminders,
    required this.widgets,
    required this.updates,
    required this.celebrations,
  });

  final EntryRepository repo;
  final SettingsController settings;
  final AppLockController lock;
  final ReminderService reminders;
  final WidgetSync widgets;
  final UpdateController updates;
  final Celebrations celebrations;
}

class InklingApp extends StatefulWidget {
  const InklingApp({super.key, required this.services, this.launch});

  final AppServices services;

  /// What opened the app (widget, reminder), if not the launcher icon.
  final LaunchRequest? launch;

  @override
  State<InklingApp> createState() => _InklingAppState();
}

class _InklingAppState extends State<InklingApp> {
  /// Coming back after this long counts as opening the app again.
  static const _newSessionAfter = Duration(minutes: 30);

  late final AppLifecycleListener _lifecycle;
  StreamSubscription<Uri?>? _widgetClicks;
  DateTime? _hiddenAt;
  bool? _secure;

  AppServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    s.repo.addListener(_onDataChanged);
    s.settings.addListener(_onSettingsChanged);
    s.reminders.onTap = (payload) => _handle(LaunchRequest.fromPayload(payload));
    _lifecycle = AppLifecycleListener(onHide: _onHide, onResume: _onResume);
    if (defaultTargetPlatform == TargetPlatform.android) {
      _widgetClicks = HomeWidget.widgetClicked.listen(
        (uri) => _handle(LaunchRequest.fromUri(uri)),
        onError: (Object e) => debugPrint('Inkling: widget click stream: $e'),
      );
      void logShortcutError(Object e) => debugPrint('Inkling: launcher shortcuts unavailable: $e');
      const actions = QuickActions();
      actions.initialize((type) => _handle(LaunchRequest.fromShortcut(type))).catchError(logShortcutError);
      actions
          .setShortcutItems(const [
            ShortcutItem(type: 'write', localizedTitle: 'Write today', icon: 'ic_shortcut_write'),
            ShortcutItem(type: 'search', localizedTitle: 'Search diary', icon: 'ic_shortcut_search'),
          ])
          .catchError(logShortcutError);
    }
    _applySecure();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      s.celebrations.checkStickers(s.repo, silent: s.settings.seenStickers == null);
      s.reminders.sync();
      s.widgets.sync();
      Future.delayed(const Duration(seconds: 4), s.updates.autoCheck);
    });
  }

  @override
  void dispose() {
    s.repo.removeListener(_onDataChanged);
    s.settings.removeListener(_onSettingsChanged);
    _widgetClicks?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    s.widgets.schedule();
    s.reminders.sync();
  }

  void _onSettingsChanged() {
    s.widgets.schedule();
    s.reminders.sync();
    _applySecure();
  }

  void _applySecure() {
    final secure = s.settings.secureScreen;
    if (secure == _secure) return;
    _secure = secure;
    PlatformBridge.setSecure(secure);
  }

  void _handle(LaunchRequest? request) {
    if (request == null) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => AppNav.handle(request))
      ..scheduleFrame();
  }

  void _onHide() {
    _hiddenAt = DateTime.now();
    s.lock.onHidden();
  }

  void _onResume() {
    s.lock.onResumed();
    if (s.lock.locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => s.lock.unlock());
    }
    s.reminders.sync();
    s.widgets.sync();

    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    final now = DateTime.now();
    if (hiddenAt != null && (!isSameDay(hiddenAt, now) || now.difference(hiddenAt) >= _newSessionAfter)) {
      // Treat it like a fresh launch: ask about today again, but only if the
      // person isn't in the middle of something.
      if (_shouldAsk(today()) && AppNav.homeIsCurrent) {
        AppNav.handle(LaunchRequest(LaunchKind.write, today()));
      }
    }
  }

  bool _shouldAsk(DateTime day) => switch (s.settings.launchBehavior) {
    LaunchBehavior.alwaysAsk => true,
    LaunchBehavior.askIfEmpty => !s.repo.hasEntry(day),
    LaunchBehavior.calendar => false,
  };

  List<Route<dynamic>> _initialRoutes() {
    final t = today();
    final launch = widget.launch;
    final routes = <Route<dynamic>>[AppNav.homeRoute()];
    switch (launch?.kind) {
      case LaunchKind.write:
        routes.add(AppNav.composeRoute(launch!.day ?? t));
      case LaunchKind.search:
        routes.add(AppNav.searchRoute());
      case LaunchKind.calendar:
        break;
      case null:
        if (_shouldAsk(t)) routes.add(AppNav.composeRoute(t));
    }
    return routes;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: s.repo),
        ChangeNotifierProvider.value(value: s.settings),
        ChangeNotifierProvider.value(value: s.lock),
        ChangeNotifierProvider.value(value: s.updates),
        ChangeNotifierProvider.value(value: s.celebrations),
        Provider.value(value: s.reminders),
      ],
      child: DynamicColorBuilder(
        builder: (lightDynamic, _) {
          final dynamicSeed = DynamicSeed(lightDynamic?.primary);
          if (s.widgets.dynamicSeed != dynamicSeed.color) {
            s.widgets
              ..dynamicSeed = dynamicSeed.color
              ..schedule();
          }
          return Provider.value(
            value: dynamicSeed,
            child: Consumer<SettingsController>(
              builder: (context, settings, _) {
                final seed = accentSeed(settings, dynamicSeed: dynamicSeed.color);
                return MaterialApp(
                  title: AppConfig.appName,
                  debugShowCheckedModeBanner: false,
                  navigatorKey: AppNav.key,
                  navigatorObservers: [AppNav.observer],
                  themeMode: settings.themeMode,
                  theme: buildTheme(schemeFor(seed, Brightness.light)),
                  darkTheme: buildTheme(schemeFor(seed, Brightness.dark)),
                  onGenerateInitialRoutes: (_) => _initialRoutes(),
                  onGenerateRoute: (_) => AppNav.homeRoute(),
                  builder: (context, child) => LockGate(
                    child: Stack(children: [child ?? const SizedBox.shrink(), const CelebrationLayer()]),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
