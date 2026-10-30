import 'package:flutter/material.dart';

import 'screens/compose_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'utils/dates.dart';

enum LaunchKind { write, calendar, search }

/// Where the app was asked to go: from the widget, a reminder or a shortcut.
@immutable
class LaunchRequest {
  const LaunchRequest(this.kind, [this.day]);

  final LaunchKind kind;
  final DateTime? day;

  /// `inkling://write`, `inkling://write?date=2026-10-21`, `inkling://calendar`.
  static LaunchRequest? fromUri(Uri? uri) {
    if (uri == null) return null;
    return switch (uri.host) {
      'write' => LaunchRequest(LaunchKind.write, _pastOrToday(tryParseDateKey(uri.queryParameters['date']))),
      'calendar' => const LaunchRequest(LaunchKind.calendar),
      'search' => const LaunchRequest(LaunchKind.search),
      _ => null,
    };
  }

  /// Notification payloads look like `write:2026-10-25`.
  static LaunchRequest? fromPayload(String? payload) {
    if (payload == null) return null;
    final parts = payload.split(':');
    return switch (parts.first) {
      'write' => LaunchRequest(LaunchKind.write, _pastOrToday(tryParseDateKey(parts.elementAtOrNull(1)))),
      _ => null,
    };
  }

  static LaunchRequest? fromShortcut(String type) => switch (type) {
    'write' => const LaunchRequest(LaunchKind.write),
    'search' => const LaunchRequest(LaunchKind.search),
    _ => null,
  };

  static DateTime? _pastOrToday(DateTime? day) => day == null || day.isAfter(today()) ? null : day;
}

class _StackObserver extends NavigatorObserver {
  final List<Route<dynamic>> stack = [];

  Route<dynamic>? get top => stack.isEmpty ? null : stack.last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      stack[i] = newRoute;
    } else if (newRoute != null) {
      stack.add(newRoute);
    }
  }
}

abstract final class AppNav {
  static final key = GlobalKey<NavigatorState>();
  static final observer = _StackObserver();

  static const homeName = '/';
  static const composeName = '/compose';
  static const searchName = '/search';

  static NavigatorState? get _nav => key.currentState;

  static bool get homeIsCurrent => observer.top?.settings.name == homeName;

  static Route<void> homeRoute() => MaterialPageRoute(
    settings: const RouteSettings(name: homeName),
    builder: (_) => const HomeScreen(),
  );

  static Route<void> composeRoute(DateTime day) => MaterialPageRoute(
    settings: RouteSettings(name: composeName, arguments: dateOnly(day)),
    builder: (_) => ComposeScreen(day: dateOnly(day)),
  );

  static Route<void> searchRoute() => MaterialPageRoute(
    settings: const RouteSettings(name: searchName),
    builder: (_) => const SearchScreen(),
  );

  /// Opens the writing screen for [day], unless it's already showing.
  static Future<void> openCompose(BuildContext? context, DateTime day) async {
    final nav = context != null ? Navigator.of(context) : _nav;
    if (nav == null) return;
    final top = observer.top;
    if (top?.settings.name == composeName && isSameDay(top!.settings.arguments! as DateTime, day)) return;
    await nav.push(composeRoute(day));
  }

  static void handle(LaunchRequest request) {
    final nav = _nav;
    if (nav == null) return;
    switch (request.kind) {
      case LaunchKind.write:
        final day = request.day ?? today();
        final top = observer.top;
        if (top?.settings.name == composeName && isSameDay(top!.settings.arguments! as DateTime, day)) return;
        nav.popUntil((r) => r.isFirst);
        nav.push(composeRoute(day));
      case LaunchKind.calendar:
        nav.popUntil((r) => r.isFirst);
      case LaunchKind.search:
        if (observer.top?.settings.name == searchName) return;
        nav.popUntil((r) => r.isFirst);
        nav.push(searchRoute());
    }
  }
}
