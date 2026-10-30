import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkling/app.dart';
import 'package:inkling/screens/compose_screen.dart';
import 'package:inkling/screens/home_screen.dart';
import 'package:inkling/screens/lock_screen.dart';
import 'package:inkling/screens/settings_screen.dart';
import 'package:inkling/services/celebrations.dart';
import 'package:inkling/services/settings.dart';
import 'package:inkling/utils/dates.dart';
import 'package:inkling/utils/prompts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

void main() {
  AppServices? current;

  setUpAll(() async {
    await initializeDateFormatting();
    mockPlatformChannels();
  });

  // Inky's idle animations are switched off so pumpAndSettle can settle.
  Future<AppServices> boot(WidgetTester tester, {Map<String, Object> prefs = const {}, bool animated = false}) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.25;
    addTearDown(tester.view.reset);
    final services = (await tester.runAsync(() => makeServices(prefs: {'animatedInky': animated, ...prefs})))!;
    addTearDown(services.repo.close);
    current = services;
    await tester.pumpWidget(InklingApp(services: services));
    await tester.pump();
    return services;
  }

  // Lets the update check, autosave and celebration timers run out before the test ends.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    for (var i = 0; i < 30 && (current?.celebrations.busy ?? false); i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('opens on today’s question with the keyboard up, and saves into the calendar', (tester) async {
    final s = await boot(tester);
    final t = today();

    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.text(promptFor(t, today: t, playful: true, hasEntry: false)), findsOneWidget);
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue, reason: 'editor focused on launch');
    expect(tester.testTextInput.isVisible, isTrue, reason: 'soft keyboard requested');

    await tester.enterText(field, 'Went hiking with Sam. Saw a heron!');
    await tester.pump(const Duration(seconds: 1));
    expect(s.repo.entryFor(t)?.text, 'Went hiking with Sam. Saw a heron!', reason: 'autosaved');
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('7 words'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('${formatLong(t)}, today, written')), findsOneWidget);
    expect(find.textContaining('Went hiking with Sam'), findsOneWidget);
    semantics.dispose();
    await settle(tester);
  });

  testWidgets('tapping a past day opens it for editing', (tester) async {
    final s = await boot(tester, prefs: {'launchBehavior': 'calendar'});
    final t = today();
    final past = t.day > 1 ? DateTime(t.year, t.month, 1) : addDays(t, -1);
    await tester.runAsync(() => s.repo.save(past, text: 'An older page'));
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget, reason: '"Show the calendar" launch setting');
    final semantics = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel(RegExp('^${formatLong(past)}, written')));
    await tester.pumpAndSettle();
    semantics.dispose();

    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.text('An older page'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'An older page, now edited');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(s.repo.entryFor(past)?.text, 'An older page, now edited', reason: 'saved when leaving');
    await settle(tester);
  });

  testWidgets('"ask until I’ve written" skips the question once today exists', (tester) async {
    final services = (await tester.runAsync(
      () => makeServices(prefs: {'launchBehavior': 'askIfEmpty', 'animatedInky': false}),
    ))!;
    addTearDown(services.repo.close);
    current = services;
    await tester.runAsync(() => services.repo.save(today(), text: 'Already wrote'));
    await tester.pumpWidget(InklingApp(services: services));
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(ComposeScreen), findsNothing);
    await settle(tester);
  });

  testWidgets('app lock covers everything and keeps the keyboard down', (tester) async {
    await boot(tester, prefs: {'appLock': true});
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('Inkling is locked'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    await settle(tester);
  });

  testWidgets('settings screen renders every section', (tester) async {
    final s = await boot(tester, prefs: {'launchBehavior': 'calendar'});
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    final seen = <String>{};
    for (var i = 0; i < 8; i++) {
      seen.addAll(find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? ''));
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(
      seen,
      containsAll([
        'Appearance',
        'Fun stuff',
        'Writing',
        'Reminders',
        'Privacy & security',
        'Home screen',
        'Backup & data',
        'Updates',
        'About',
      ]),
    );
    // Changing a setting flows back into the app.
    await tester.drag(find.byType(ListView), const Offset(0, 5000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(s.settings.themeMode, ThemeMode.dark);
    expect(s.settings.launchBehavior, LaunchBehavior.calendar);
    await settle(tester);
  });

  testWidgets('finishing today’s first page throws a little party', (tester) async {
    final s = await boot(tester, animated: true);
    await tester.enterText(find.byType(TextField), 'Tiny but mighty.');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Today’s page is done!'), findsOneWidget);
    expect(s.settings.seenStickers, contains('first'));
    // The "First drop" sticker is queued right behind it.
    await tester.pump(Celebrations.showFor + const Duration(seconds: 1));
    expect(find.text('New sticker: First drop'), findsOneWidget);
    await settle(tester);
  });
}
