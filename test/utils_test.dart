import 'package:flutter_test/flutter_test.dart';
import 'package:inkling/services/update_checker.dart';
import 'package:inkling/utils/dates.dart';
import 'package:inkling/utils/prompts.dart';
import 'package:inkling/utils/stats.dart';

void main() {
  group('dates', () {
    test('dateKey and parseDateKey round-trip', () {
      final d = DateTime(2026, 3, 9);
      expect(dateKey(d), '2026-03-09');
      expect(parseDateKey('2026-03-09'), d);
    });

    test('parseDateKey rejects impossible dates', () {
      expect(() => parseDateKey('2026-02-30'), throwsFormatException);
      expect(() => parseDateKey('25/10/2026'), throwsFormatException);
      expect(tryParseDateKey('nope'), isNull);
    });

    test('addDays crosses month and year boundaries', () {
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2024, 3, 1), -1), DateTime(2024, 2, 29));
    });

    test('startOfWeek honours the first weekday', () {
      final sat = DateTime(2026, 10, 24); // a Saturday
      expect(startOfWeek(sat, DateTime.monday), DateTime(2026, 10, 19));
      expect(startOfWeek(sat, DateTime.sunday), DateTime(2026, 10, 18));
      expect(startOfWeek(sat, DateTime.saturday), sat);
    });

    test('relativeDayLabel', () {
      final t = DateTime(2026, 10, 25);
      expect(relativeDayLabel(t, t), 'Today');
      expect(relativeDayLabel(DateTime(2026, 10, 24), t), 'Yesterday');
      expect(relativeDayLabel(DateTime(2026, 10, 21), t), 'Wednesday');
      expect(relativeDayLabel(DateTime(2026, 9, 1), t), 'Tue, 1 Sep');
    });
  });

  group('streaks', () {
    final t = DateTime(2026, 10, 25);
    Set<String> keys(List<int> daysAgo) => {for (final d in daysAgo) dateKey(addDays(t, -d))};

    test('counts consecutive days ending today', () {
      expect(currentStreak(keys([0, 1, 2, 4]), t), 3);
    });

    test('stays alive until today is over', () {
      expect(currentStreak(keys([1, 2]), t), 2);
      expect(currentStreak(keys([2, 3]), t), 0);
    });

    test('longest streak across gaps and month ends', () {
      expect(longestStreak({'2026-01-30', '2026-01-31', '2026-02-01', '2026-02-05'}), 3);
      expect(longestStreak(<String>{}), 0);
    });

    test('latestRun reports the most recent run for the widget', () {
      final run = latestRun(keys([3, 4, 5, 9]), t);
      expect(run.end, dateKey(addDays(t, -3)));
      expect(run.length, 3);
      expect(latestRun(<String>{}, t).end, isNull);
    });

    test('future-dated keys are ignored by latestRun', () {
      final run = latestRun({...keys([0]), dateKey(addDays(t, 2))}, t);
      expect(run.end, dateKey(t));
    });
  });

  test('countWords handles punctuation, apostrophes and unicode', () {
    expect(countWords(''), 0);
    expect(countWords("It's a lovely day — isn't it?"), 6);
    expect(countWords('Café   naïve\nnew-line'), 3);
  });

  test('compactNumber', () {
    expect(compactNumber(999), '999');
    expect(compactNumber(1000), '1k');
    expect(compactNumber(4250), '4.3k');
    expect(compactNumber(12345), '12k');
  });

  test('prompts', () {
    final t = DateTime(2026, 10, 25);
    expect(promptFor(t, today: t, playful: false, hasEntry: false), defaultTodayPrompt);
    expect(promptFor(t, today: t, playful: true, hasEntry: true), 'Anything else about today?');
    expect(promptFor(DateTime(2026, 10, 24), today: t, playful: true, hasEntry: false), 'What happened yesterday?');
    expect(promptFor(DateTime(2026, 10, 21), today: t, playful: true, hasEntry: false), 'What happened on Wednesday?');
    expect(promptFor(DateTime(2026, 8, 3), today: t, playful: true, hasEntry: false), 'What happened on 3 August?');
    // Stable through the day.
    expect(
      promptFor(t, today: t, playful: true, hasEntry: false),
      promptFor(t, today: t, playful: true, hasEntry: false),
    );
  });

  test('version comparison', () {
    expect(UpdateController.isNewer('1.0.1', '1.0.0'), isTrue);
    expect(UpdateController.isNewer('1.10.0', '1.9.3'), isTrue);
    expect(UpdateController.isNewer('1.0.0', '1.0.0'), isFalse);
    expect(UpdateController.isNewer('0.9', '1.0.0'), isFalse);
    expect(UpdateController.isNewer('2.0.0-beta', '1.5.0+7'), isTrue);
  });
}
