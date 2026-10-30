import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkling/data/entry.dart';
import 'package:inkling/services/settings.dart';
import 'package:inkling/theme/theme.dart';
import 'package:inkling/utils/dates.dart';
import 'package:inkling/widgets/month_calendar.dart';

void main() {
  final today = DateTime(2026, 10, 25); // a Sunday
  DiaryEntry entry(String date, {int? mood}) =>
      DiaryEntry(date: date, text: 'x', mood: mood, createdAt: today, updatedAt: today);

  Future<void> pump(
    WidgetTester tester, {
    required Map<String, DiaryEntry> entries,
    required ValueChanged<DateTime> onDayTap,
    ValueChanged<DateTime>? onMonthChanged,
    DateTime? month,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(schemeFor(accents.first.color, Brightness.light)),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CalendarCard(
            month: month ?? DateTime(2026, 10),
            today: today,
            firstMonth: DateTime(2021, 10),
            firstWeekday: DateTime.monday,
            style: CalendarStyle.ink,
            entryFor: (d) => entries[dateKey(d)],
            monthCount: entries.length,
            onMonthChanged: onMonthChanged ?? (_) {},
            onDayTap: onDayTap,
          ),
        ),
      ),
    ),
  );

  testWidgets('marks written days, today, and blocks future days', (tester) async {
    final semantics = tester.ensureSemantics();
    DateTime? tapped;
    await pump(
      tester,
      entries: {'2026-10-03': entry('2026-10-03'), '2026-10-04': entry('2026-10-04', mood: 5)},
      onDayTap: (d) => tapped = d,
    );

    expect(find.bySemanticsLabel('Saturday, 3 October 2026, written'), findsOneWidget);
    expect(find.bySemanticsLabel('Sunday, 4 October 2026, written, feeling great'), findsOneWidget);
    expect(find.bySemanticsLabel('Sunday, 25 October 2026, today, not written'), findsOneWidget);
    expect(find.text('October'), findsOneWidget);
    expect(find.text('2 pages written'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Monday, 5 October 2026, not written'));
    expect(tapped, DateTime(2026, 10, 5));

    tapped = null;
    await tester.tap(find.bySemanticsLabel('Monday, 26 October 2026'));
    expect(tapped, isNull, reason: 'future days are not writable');
    semantics.dispose();
  });

  testWidgets('months start on the chosen weekday', (tester) async {
    await pump(tester, entries: {}, onDayTap: (_) {});
    // Monday-first: 1 Oct 2026 is a Thursday, so three blank cells come first.
    final first = tester.getTopLeft(find.text('1'));
    final fifth = tester.getTopLeft(find.text('5'));
    expect(fifth.dy, greaterThan(first.dy), reason: 'Monday the 5th starts the second row');
  });

  testWidgets('cannot page past the current month', (tester) async {
    DateTime? changed;
    await pump(tester, entries: {}, onDayTap: (_) {}, onMonthChanged: (m) => changed = m);
    await tester.tap(find.byTooltip('Next month'));
    expect(changed, isNull);
    await tester.tap(find.byTooltip('Previous month'));
    expect(changed, DateTime(2026, 9));
  });
}
