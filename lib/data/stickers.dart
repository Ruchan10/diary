import 'dart:math';

import '../utils/dates.dart';
import 'entry_repository.dart';

/// Everything the stickers are judged on, worked out from the diary itself.
class StickerProgress {
  const StickerProgress({
    required this.entries,
    required this.words,
    required this.longestStreak,
    required this.longestEntry,
    required this.moodsUsed,
    required this.nightOwl,
    required this.earlyBird,
    required this.timeTraveller,
    required this.weekendWarrior,
  });

  factory StickerProgress.of(EntryRepository repo, DateTime today) {
    final stats = repo.statsFor(today);
    final keys = repo.dateKeys;
    var longestEntry = 0;
    final moods = <int>{};
    var night = false, early = false, travel = false, weekend = false;
    for (final e in repo.allEntries) {
      longestEntry = max(longestEntry, e.wordCount);
      if (e.mood case final m?) moods.add(m);
      final hour = e.createdAt.hour;
      if (hour < 4) night = true;
      if (hour >= 5 && hour < 7) early = true;
      final day = e.day;
      if (daysBetween(day, e.createdAt) >= 1) travel = true;
      if (day.weekday == DateTime.saturday && keys.contains(dateKey(addDays(day, 1)))) weekend = true;
    }
    return StickerProgress(
      entries: stats.totalEntries,
      words: stats.totalWords,
      longestStreak: stats.longestStreak,
      longestEntry: longestEntry,
      moodsUsed: moods.length,
      nightOwl: night,
      earlyBird: early,
      timeTraveller: travel,
      weekendWarrior: weekend,
    );
  }

  final int entries;
  final int words;
  final int longestStreak;
  final int longestEntry;
  final int moodsUsed;
  final bool nightOwl;
  final bool earlyBird;
  final bool timeTraveller;
  final bool weekendWarrior;
}

class Sticker {
  const Sticker(this.id, this.emoji, this.name, this.description, this.measure, {this.goal = 1, this.unit = ''});

  final String id;
  final String emoji;
  final String name;
  final String description;
  final int Function(StickerProgress p) measure;
  final int goal;

  /// "days", "pages"... for the progress label.
  final String unit;

  int progress(StickerProgress p) => min(measure(p), goal);

  bool unlocked(StickerProgress p) => measure(p) >= goal;
}

int _flag(bool value) => value ? 1 : 0;

final stickers = <Sticker>[
  Sticker('first', '💧', 'First drop', 'Wrote your very first page.', (p) => p.entries),
  Sticker('streak3', '🔥', 'Warming up', 'Wrote 3 days in a row.', (p) => p.longestStreak, goal: 3, unit: 'days'),
  Sticker('streak7', '📅', 'Week of ink', 'Wrote 7 days in a row.', (p) => p.longestStreak, goal: 7, unit: 'days'),
  Sticker('streak30', '🏅', 'Ink habit', 'Wrote 30 days in a row.', (p) => p.longestStreak, goal: 30, unit: 'days'),
  Sticker('streak100', '👑', 'Legend', 'Wrote 100 days in a row!', (p) => p.longestStreak, goal: 100, unit: 'days'),
  Sticker('pages10', '📚', 'Ten tales', 'Filled 10 pages.', (p) => p.entries, goal: 10, unit: 'pages'),
  Sticker('pages50', '🎯', 'Half-century', 'Filled 50 pages.', (p) => p.entries, goal: 50, unit: 'pages'),
  Sticker('pages100', '💯', 'Century', 'Filled 100 pages.', (p) => p.entries, goal: 100, unit: 'pages'),
  Sticker('words1k', '✍️', 'Wordsmith', 'Wrote 1,000 words in total.', (p) => p.words, goal: 1000, unit: 'words'),
  Sticker('words10k', '📖', 'Novelist', 'Wrote 10,000 words in total.', (p) => p.words, goal: 10000, unit: 'words'),
  Sticker('epic', '📜', 'Epic page', 'Wrote a single page of 500+ words.', (p) => p.longestEntry, goal: 500, unit: 'words'),
  Sticker('moods', '🌈', 'Mood ring', 'Used all five moods.', (p) => p.moodsUsed, goal: 5, unit: 'moods'),
  Sticker('owl', '🦉', 'Night owl', 'Started a page after midnight.', (p) => _flag(p.nightOwl)),
  Sticker('bird', '🐦', 'Early bird', 'Started a page before 7 am.', (p) => _flag(p.earlyBird)),
  Sticker('time', '⏳', 'Time traveller', 'Filled in a page for a past day.', (p) => _flag(p.timeTraveller)),
  Sticker('weekend', '🎉', 'Weekend warrior', 'Wrote on a Saturday and the Sunday after.', (p) => _flag(p.weekendWarrior)),
];

Set<String> unlockedStickers(StickerProgress p) => {
  for (final s in stickers)
    if (s.unlocked(p)) s.id,
};
