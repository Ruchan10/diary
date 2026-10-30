import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/entry_repository.dart';
import '../data/stickers.dart';
import '../utils/dates.dart';
import 'settings.dart';

@immutable
class Cheer {
  const Cheer({required this.emoji, required this.title, this.subtitle, this.confetti = true});

  final String emoji;
  final String title;
  final String? subtitle;
  final bool confetti;
}

const streakMilestones = {3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 250, 300, 365, 500, 730, 1000};

const _doneLines = [
  'Inky is doing a happy dance 💃',
  'Another drop in the ink pot.',
  'Future you says thank you!',
  'One more memory, safely kept.',
  'Gold star for today ⭐',
];

const _streakLines = [
  'You’re on fire. Inky is impressed.',
  'Unstoppable! Keep the ink flowing.',
  'Look at that calendar glow ✨',
];

/// A queue of little parties: finished pages, streak milestones, new stickers.
/// They show one at a time on top of whatever screen is open.
class Celebrations extends ChangeNotifier {
  Celebrations(this.settings);

  final SettingsController settings;
  final _queue = <Cheer>[];
  final _random = Random();
  Timer? _timer;

  Cheer? current;

  /// Changes for every cheer shown, so the confetti restarts.
  int serial = 0;

  static const showFor = Duration(milliseconds: 3400);

  /// Something is showing or waiting to be shown.
  bool get busy => current != null || _queue.isNotEmpty || _timer != null;

  void cheer(Cheer cheer) {
    if (!settings.celebrations) return;
    _queue.add(cheer);
    if (current == null && _timer == null) _next();
  }

  void dismiss() {
    _timer?.cancel();
    current = null;
    notifyListeners();
    _timer = Timer(const Duration(milliseconds: 380), _next);
  }

  void _next() {
    _timer = null;
    if (_queue.isEmpty) return;
    current = _queue.removeAt(0);
    serial++;
    notifyListeners();
    _timer = Timer(showFor, dismiss);
  }

  /// Call when the writing screen closes.
  void afterWriting(EntryRepository repo, {required bool firstToday}) {
    if (firstToday) {
      final streak = repo.statsFor(today()).currentStreak;
      if (streakMilestones.contains(streak)) {
        cheer(Cheer(emoji: '🔥', title: '$streak-day streak!', subtitle: _pick(_streakLines)));
      } else {
        cheer(Cheer(emoji: '✍️', title: 'Today’s page is done!', subtitle: _pick(_doneLines)));
      }
    }
    checkStickers(repo);
  }

  /// Cheers for newly earned stickers. The very first check only takes note
  /// of what's already there ([silent] does the same).
  void checkStickers(EntryRepository repo, {bool silent = false}) {
    final unlocked = unlockedStickers(StickerProgress.of(repo, today()));
    final seen = settings.seenStickers;
    final merged = {...?seen, ...unlocked};
    if (seen == null || silent) {
      if (seen == null || merged.length != seen.length) settings.seenStickers = merged.toList()..sort();
      return;
    }
    final fresh = stickers.where((s) => unlocked.contains(s.id) && !seen.contains(s.id)).toList();
    if (fresh.isEmpty) return;
    settings.seenStickers = merged.toList()..sort();
    for (final s in fresh) {
      cheer(Cheer(emoji: s.emoji, title: 'New sticker: ${s.name}', subtitle: s.description));
    }
  }

  String _pick(List<String> lines) => lines[_random.nextInt(lines.length)];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
