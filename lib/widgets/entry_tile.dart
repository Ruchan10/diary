import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/entry.dart';
import '../theme/moods.dart';
import '../theme/theme.dart';
import '../utils/dates.dart';
import 'playful.dart';

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, required this.onTap, this.highlight, this.label});

  final DiaryEntry entry;
  final VoidCallback onTap;

  /// Search query to highlight; the excerpt is centred on the first match.
  final String? highlight;

  /// Overrides the date line, e.g. "1 year ago".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = entry.day;
    final mood = moodFor(entry.mood);
    final words = entry.wordCount;

    return Squishy(
      pressedScale: 0.97,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CalendarPage(day: day),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label ?? relativeDayLabel(day, today()),
                              style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                            ),
                          ),
                          if (mood != null) MoodSticker(mood: mood),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (entry.preview.isEmpty)
                        Text('Just a mood today.', style: handStyle(20, color: scheme.onSurfaceVariant))
                      else
                        Text.rich(
                          _highlighted(entry.preview, highlight, scheme),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '$words ${words == 1 ? 'word' : 'words'}',
                        style: handStyle(17, color: scheme.onSurfaceVariant, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static TextSpan _highlighted(String text, String? query, ColorScheme scheme) {
    final words = (query ?? '').toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return TextSpan(text: text);

    final lower = text.toLowerCase();
    final first = words.map(lower.indexOf).where((i) => i >= 0).fold<int?>(null, (a, b) => a == null || b < a ? b : a);
    var start = 0;
    if (first != null && first > 60) {
      start = text.lastIndexOf(' ', first - 30).clamp(0, first);
    }
    final shown = start > 0 ? '…${text.substring(start).trimLeft()}' : text;
    final shownLower = shown.toLowerCase();

    final marks = List<bool>.filled(shown.length, false);
    for (final w in words) {
      for (var i = shownLower.indexOf(w); i >= 0; i = shownLower.indexOf(w, i + w.length)) {
        marks.fillRange(i, i + w.length, true);
      }
    }
    final spans = <TextSpan>[];
    var i = 0;
    while (i < shown.length) {
      final mark = marks[i];
      var j = i;
      while (j < shown.length && marks[j] == mark) {
        j++;
      }
      spans.add(
        TextSpan(
          text: shown.substring(i, j),
          style: mark
              ? TextStyle(
                  backgroundColor: scheme.tertiaryContainer,
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w800,
                )
              : null,
        ),
      );
      i = j;
    }
    return TextSpan(children: spans);
  }
}

/// A tiny tear-off calendar page.
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 50,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: scheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              DateFormat('EEE').format(day).toUpperCase(),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onPrimary,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text('${day.day}', style: theme.textTheme.headlineSmall?.copyWith(height: 1.1)),
          ),
        ],
      ),
    );
  }
}

/// A mood emoji stuck on like a sticker.
class MoodSticker extends StatelessWidget {
  const MoodSticker({super.key, required this.mood, this.size = 30});

  final Mood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Transform.rotate(
      angle: 0.18,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: mood.color.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 2),
        ),
        child: Text(mood.emoji, style: TextStyle(fontSize: size * 0.56, height: 1.1)),
      ),
    );
  }
}
