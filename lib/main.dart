import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/entry_repository.dart';
import 'navigation.dart';
import 'services/app_lock.dart';
import 'services/celebrations.dart';
import 'services/reminders.dart';
import 'services/settings.dart';
import 'services/update_checker.dart';
import 'services/widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  LicenseRegistry.addLicense(_fontLicenses);

  final settings = await SettingsController.load();
  final repo = await EntryRepository.open();
  final services = AppServices(
    repo: repo,
    settings: settings,
    lock: AppLockController(settings),
    reminders: ReminderService(repo, settings),
    widgets: WidgetSync(repo, settings),
    updates: UpdateController(settings),
    celebrations: Celebrations(settings),
  );

  LaunchRequest? launch;
  try {
    launch = LaunchRequest.fromPayload(await services.reminders.init());
  } catch (e) {
    debugPrint('Inkling: notifications unavailable: $e');
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      launch ??= LaunchRequest.fromUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (e) {
      debugPrint('Inkling: widget launch check failed: $e');
    }
  }

  runApp(InklingApp(services: services, launch: launch));
}

Stream<LicenseEntry> _fontLicenses() async* {
  const fonts = {
    'Fraunces': 'fraunces',
    'Nunito': 'nunito',
    'Lora': 'lora',
    'Caveat': 'caveat',
    'Courier Prime': 'courierprime',
  };
  for (final MapEntry(key: family, value: file) in fonts.entries) {
    yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString('assets/licenses/OFL-$file.txt'));
  }
}
