import 'package:flutter_test/flutter_test.dart';
import 'package:inkling/data/entry.dart';
import 'package:inkling/data/entry_repository.dart';
import 'package:inkling/utils/dates.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late EntryRepository repo;

  setUp(() async {
    repo = await EntryRepository.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
  });

  tearDown(() => repo.close());

  final day = DateTime(2026, 10, 25);

  test('save creates, updates and persists an entry', () async {
    await repo.save(day, text: 'First draft', mood: 3);
    final created = repo.entryFor(day)!;
    await repo.save(day, text: 'Second draft', mood: 4);
    final updated = repo.entryFor(day)!;
    expect(updated.text, 'Second draft');
    expect(updated.mood, 4);
    expect(updated.createdAt, created.createdAt);
    expect(repo.count, 1);
  });

  test('blank text without a mood removes the entry', () async {
    await repo.save(day, text: 'Something');
    await repo.save(day, text: '   \n');
    expect(repo.hasEntry(day), isFalse);
    // A mood alone is still an entry.
    await repo.save(day, text: '', mood: 5);
    expect(repo.hasEntry(day), isTrue);
  });

  test('notifies listeners only on real changes', () async {
    var calls = 0;
    repo.addListener(() => calls++);
    await repo.save(day, text: 'Hi');
    await repo.save(day, text: 'Hi');
    expect(calls, 1);
  });

  test('month, on-this-day, search and stats', () async {
    await repo.save(DateTime(2026, 10, 23), text: 'Coffee with Maya at the harbour');
    await repo.save(DateTime(2026, 10, 24), text: 'Long walk', mood: 5);
    await repo.save(day, text: 'Harbour again, windy', mood: 4);
    await repo.save(DateTime(2025, 10, 25), text: 'A year ago');
    await repo.save(DateTime(2026, 9, 30), text: 'Last month');

    expect(repo.entriesInMonth(DateTime(2026, 10)).map((e) => e.date), [
      '2026-10-25',
      '2026-10-24',
      '2026-10-23',
    ]);
    expect(repo.onThisDay(day).single.date, '2025-10-25');
    expect(repo.search('harbour').length, 2);
    expect(repo.search('maya HARBOUR').single.date, '2026-10-23');
    expect(repo.search('', mood: 5).single.date, '2026-10-24');

    final stats = repo.statsFor(day);
    expect(stats.currentStreak, 3);
    expect(stats.totalEntries, 5);
    expect(stats.writtenToday, isTrue);
    expect(repo.latestOnOrBefore(DateTime(2026, 10, 1))!.date, '2026-09-30');
  });

  group('import', () {
    DiaryEntry incoming(String date, String text, DateTime updated, {int? mood}) =>
        DiaryEntry(date: date, text: text, mood: mood, createdAt: updated, updatedAt: updated);

    setUp(() async {
      await repo.save(day, text: 'Local text');
    });

    test('keepNewest only overwrites older pages', () async {
      final local = repo.entryFor(day)!;
      final summary = await repo.importEntries([
        incoming(dateKey(day), 'Older remote', local.updatedAt.subtract(const Duration(hours: 1))),
        incoming('2026-10-20', 'New day', DateTime(2026, 10, 20)),
      ], ImportMode.keepNewest);
      expect(summary.added, 1);
      expect(summary.unchanged, 1);
      expect(repo.entryFor(day)!.text, 'Local text');

      await repo.importEntries([
        incoming(dateKey(day), 'Newer remote', local.updatedAt.add(const Duration(hours: 1))),
      ], ImportMode.keepNewest);
      expect(repo.entryFor(day)!.text, 'Newer remote');
    });

    test('keepBoth appends and is idempotent', () async {
      final e = incoming(dateKey(day), 'Imported text', DateTime(2020));
      await repo.importEntries([e], ImportMode.keepBoth);
      expect(repo.entryFor(day)!.text, contains('Local text'));
      expect(repo.entryFor(day)!.text, contains('Imported text'));
      final again = await repo.importEntries([e], ImportMode.keepBoth);
      expect(again.changed, 0);
    });

    test('replaceAll wipes pages missing from the backup', () async {
      await repo.save(DateTime(2026, 10, 1), text: 'Will vanish');
      final s = await repo.importEntries([incoming('2026-01-01', 'Only one', DateTime(2026))], ImportMode.replaceAll);
      expect(s.added, 1);
      expect(repo.count, 1);
      expect(repo.hasEntry(day), isFalse);
    });

    test('identical text is reported as unchanged', () async {
      final s = await repo.importEntries([incoming(dateKey(day), 'Local text', DateTime(2030))], ImportMode.keepNewest);
      expect(s.unchanged, 1);
      expect(s.changed, 0);
    });
  });

  test('deleteAll clears everything', () async {
    await repo.save(day, text: 'x');
    await repo.deleteAll();
    expect(repo.isEmpty, isTrue);
  });
}
