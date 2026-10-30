import 'dates.dart';

final _word = RegExp(r"[\p{L}\p{N}][\p{L}\p{N}'’\-]*", unicode: true);

int countWords(String text) => _word.allMatches(text).length;

/// Consecutive written days ending today, or ending yesterday (a streak stays
/// alive until the day is over).
int currentStreak(Set<String> keys, DateTime today) {
  var day = dateOnly(today);
  if (!keys.contains(dateKey(day))) {
    day = addDays(day, -1);
    if (!keys.contains(dateKey(day))) return 0;
  }
  var count = 0;
  while (keys.contains(dateKey(day))) {
    count++;
    day = addDays(day, -1);
  }
  return count;
}

int longestStreak(Iterable<String> keys) {
  final days = keys.map(tryParseDateKey).whereType<DateTime>().toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final day in days) {
    run = previous != null && daysBetween(previous, day) == 1 ? run + 1 : 1;
    if (run > best) best = run;
    previous = day;
  }
  return best;
}

/// The most recent run of consecutive days on or before [today]. Used by the
/// home-screen widget, which works out by itself whether the run is still
/// alive when the date rolls over.
({String? end, int length}) latestRun(Set<String> keys, DateTime today) {
  final t = dateKey(dateOnly(today));
  final past = keys.where((k) => k.compareTo(t) <= 0).toList()..sort();
  if (past.isEmpty) return (end: null, length: 0);
  var day = parseDateKey(past.last);
  final end = dateKey(day);
  var length = 0;
  while (keys.contains(dateKey(day))) {
    length++;
    day = addDays(day, -1);
  }
  return (end: end, length: length);
}

String compactNumber(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) {
    final k = (n / 1000).toStringAsFixed(1);
    return '${k.endsWith('.0') ? k.substring(0, k.length - 2) : k}k';
  }
  if (n < 1000000) return '${(n / 1000).round()}k';
  return '${(n / 1000000).toStringAsFixed(1)}M';
}
