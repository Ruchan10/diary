import 'package:flutter_test/flutter_test.dart';
import 'package:inkling/data/entry.dart';
import 'package:inkling/data/entry_repository.dart';
import 'package:inkling/data/stickers.dart';
import 'package:inkling/services/celebrations.dart';
import 'package:inkling/utils/dates.dart';

import 'helpers.dart';

void main() {
  late EntryRepository repo;
  late Celebrations celebrations;

  setUp(() async {
    final services = await makeServices();
    repo = services.repo;
    celebrations = services.celebrations;
  });

  tearDown(() => repo.close());

  DiaryEntry entry(DateTime day, {String text = 'A page', int? mood, DateTime? created}) {
    final at = created ?? day.add(const Duration(hours: 21));
    return DiaryEntry(date: dateKey(day), text: text, mood: mood, createdAt: at, updatedAt: at);
  }

  Set<String> unlocked() => unlockedStickers(StickerProgress.of(repo, today()));

  test('nothing is unlocked in an empty diary', () {
    expect(unlocked(), isEmpty);
  });

  test('streak, page and mood stickers follow the diary', () async {
    final t = today();
    await repo.importEntries([
      for (var i = 0; i < 3; i++) entry(addDays(t, -i - 10), mood: 5 - i),
      entry(addDays(t, -20), mood: 2),
      entry(addDays(t, -30), mood: 1),
    ], ImportMode.keepNewest);
    final got = unlocked();
    expect(got, containsAll(['first', 'streak3', 'moods']));
    expect(got, isNot(contains('streak7')));
    expect(got, isNot(contains('pages10')));
  });

  test('time-of-day, time-travel and weekend stickers', () async {
    final saturday = DateTime(2025, 6, 7);
    await repo.importEntries([
      entry(saturday, created: DateTime(2025, 6, 7, 1, 30)), // night owl
      entry(addDays(saturday, 1), created: DateTime(2025, 6, 8, 6, 15)), // early bird + weekend
      entry(DateTime(2025, 6, 2), created: DateTime(2025, 6, 4, 20)), // written two days later
    ], ImportMode.keepNewest);
    expect(unlocked(), containsAll(['owl', 'bird', 'weekend', 'time']));
  });

  test('progress is capped at the goal', () {
    final s = stickers.firstWhere((s) => s.id == 'words1k');
    const p = StickerProgress(
      entries: 1,
      words: 5000,
      longestStreak: 1,
      longestEntry: 5000,
      moodsUsed: 0,
      nightOwl: false,
      earlyBird: false,
      timeTraveller: false,
      weekendWarrior: false,
    );
    expect(s.progress(p), 1000);
    expect(s.unlocked(p), isTrue);
  });

  test('celebrations: quiet first look, then cheers for new stickers and the day', () async {
    celebrations.checkStickers(repo);
    expect(celebrations.busy, isFalse, reason: 'first check only records what exists');
    expect(celebrations.settings.seenStickers, isEmpty);

    await repo.save(today(), text: 'Hello');
    celebrations.afterWriting(repo, firstToday: true);
    expect(celebrations.current?.title, 'Today’s page is done!');
    celebrations.dismiss();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(celebrations.current?.title, 'New sticker: First drop');
    expect(celebrations.settings.seenStickers, ['first']);

    // Seen stickers are not celebrated twice.
    celebrations.dismiss();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    celebrations.checkStickers(repo);
    expect(celebrations.current, isNull);
  });

  test('streak milestones get their own cheer', () async {
    celebrations.checkStickers(repo);
    final t = today();
    await repo.importEntries([entry(addDays(t, -1)), entry(addDays(t, -2))], ImportMode.keepNewest);
    await repo.save(t, text: 'Day three');
    celebrations.afterWriting(repo, firstToday: true);
    expect(celebrations.current?.title, '3-day streak!');
    celebrations.dismiss();
  });

  test('switching celebrations off keeps things quiet', () async {
    celebrations.settings.celebrations = false;
    celebrations.checkStickers(repo);
    await repo.save(today(), text: 'Shh');
    celebrations.afterWriting(repo, firstToday: true);
    expect(celebrations.busy, isFalse);
  });
}
