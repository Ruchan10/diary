import 'package:flutter/material.dart';

@immutable
class Mood {
  const Mood(this.value, this.emoji, this.label, this.color);

  final int value;
  final String emoji;
  final String label;
  final Color color;
}

/// Best first, the order they appear in the picker.
const moods = [
  Mood(5, '😄', 'Great', Color(0xFF3DB58A)),
  Mood(4, '🙂', 'Good', Color(0xFF8CC56B)),
  Mood(3, '😐', 'Okay', Color(0xFFE8C14F)),
  Mood(2, '😕', 'Meh', Color(0xFFF09A5B)),
  Mood(1, '😢', 'Rough', Color(0xFFE5676F)),
];

Mood? moodFor(int? value) {
  for (final m in moods) {
    if (m.value == value) return m;
  }
  return null;
}
