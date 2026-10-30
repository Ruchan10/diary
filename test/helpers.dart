import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkling/app.dart';
import 'package:inkling/data/entry_repository.dart';
import 'package:inkling/services/app_lock.dart';
import 'package:inkling/services/celebrations.dart';
import 'package:inkling/services/reminders.dart';
import 'package:inkling/services/settings.dart';
import 'package:inkling/services/update_checker.dart';
import 'package:inkling/services/widget_sync.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Real services over an in-memory database and in-memory preferences.
///
/// sqflite hands back the same in-memory database while it's open, so close
/// [AppServices.repo] when you're done to start the next test clean.
Future<AppServices> makeServices({Map<String, Object> prefs = const {}}) async {
  sqfliteFfiInit();
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(Map.of(prefs));
  final settings = await SettingsController.load();
  final repo = await EntryRepository.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
  assert(repo.isEmpty, 'a previous test left its in-memory database open');
  return AppServices(
    repo: repo,
    settings: settings,
    lock: AppLockController(settings),
    reminders: ReminderService(repo, settings),
    widgets: WidgetSync(repo, settings),
    updates: UpdateController(settings),
    celebrations: Celebrations(settings),
  );
}

/// Answers the Android plugin channels the app talks to on startup.
void mockPlatformChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger
    ..setMockMethodCallHandler(const MethodChannel('home_widget'), (_) async => true)
    ..setMockStreamHandler(const EventChannel('home_widget/updates'), MockStreamHandler.inline(onListen: (_, _) {}))
    ..setMockMethodCallHandler(const MethodChannel('com.inovaara.inkling/window'), (_) async => null);
  // quick_actions falls back to its method channel when the Android implementation isn't registered.
  messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/quick_actions'), (_) async => null);
  for (final method in ['getLaunchAction', 'setShortcutItems', 'clearShortcutItems']) {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.quick_actions_android.AndroidQuickActionsApi.$method',
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
  }
  PackageInfo.setMockInitialValues(
    appName: 'Inkling',
    packageName: 'com.inovaara.inkling',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
}
