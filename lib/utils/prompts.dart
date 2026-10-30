import 'dart:math';

import 'dates.dart';

const defaultTodayPrompt = 'What happened today?';

const _playfulTodayPrompts = [
  defaultTodayPrompt,
  'So… how was today?',
  'What made you smile today?',
  'Spill the ink. What happened?',
  'What’s worth remembering about today?',
  'Tell me about your day.',
  'Any small wins today?',
  'What surprised you today?',
  'What’s on your mind right now?',
  'Who made today better?',
  'Today in a few lines?',
  'What would you tell your future self about today?',
];

/// Dice-roll questions that work for any day.
const _anyDayPrompts = [
  'What made you smile?',
  'Who did you see?',
  'What was the best bite you ate?',
  'One tiny detail worth keeping?',
  'What did you learn?',
  'What was hard, and how did you handle it?',
  'What are you grateful for?',
  'What song was stuck in your head?',
  'What would you do differently?',
  'Rate the day out of 10. Why?',
  'What made you laugh?',
  'Where did your mind wander?',
];

const _hints = [
  'Start anywhere: a moment, a feeling, a tiny detail…',
  'No pressure. One line counts.',
  'Messy is fine. Nobody’s grading this.',
  'What did you see, hear, eat, think?',
];

/// The headline question on the writing screen. Stable for the whole day, so
/// it doesn't change under your fingers while you write.
String promptFor(
  DateTime day, {
  required DateTime today,
  required bool playful,
  required bool hasEntry,
}) {
  final diff = daysBetween(day, today);
  if (diff <= 0) {
    if (hasEntry) return 'Anything else about today?';
    if (!playful) return defaultTodayPrompt;
    return _playfulTodayPrompts[(dayOfYear(day) + day.year) % _playfulTodayPrompts.length];
  }
  if (diff == 1) return 'What happened yesterday?';
  if (diff < 7) return 'What happened on ${formatWeekday(day)}?';
  return 'What happened on ${formatDayMonth(day)}?';
}

/// A different question from the dice button.
String rollPrompt(DateTime day, {required DateTime today, required String current, Random? random}) {
  final pool = [
    if (isSameDay(day, today)) ..._playfulTodayPrompts,
    ..._anyDayPrompts,
  ]..remove(current);
  return pool[(random ?? Random()).nextInt(pool.length)];
}

String hintFor(DateTime day) => _hints[dayOfYear(day) % _hints.length];
