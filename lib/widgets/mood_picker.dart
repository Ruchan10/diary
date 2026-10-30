import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/moods.dart';
import '../theme/theme.dart';
import 'inky.dart';
import 'playful.dart';

class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = moodFor(value);
    return Row(
      children: [
        for (final m in moods)
          _MoodButton(
            mood: m,
            selected: m.value == value,
            dimmed: value != null && m.value != value,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(m.value == value ? null : m.value);
            },
          ),
        const SizedBox(width: 6),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: Text(
              selected?.label ?? 'How did it feel?',
              key: ValueKey(selected?.value),
              overflow: TextOverflow.ellipsis,
              style: handStyle(selected == null ? 21 : 24, color: selected == null ? scheme.onSurfaceVariant : scheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({required this.mood, required this.selected, required this.dimmed, required this.onTap});

  final Mood mood;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bouncy = playfulMotion(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Mood: ${mood.label}',
      excludeSemantics: true,
      child: Squishy(
        pressedScale: 0.8,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            duration: Duration(milliseconds: bouncy ? 550 : 150),
            curve: bouncy ? Curves.elasticOut : Curves.easeOut,
            scale: selected ? 1.18 : (dimmed ? 0.84 : 1),
            child: AnimatedRotation(
              duration: Duration(milliseconds: bouncy ? 550 : 150),
              curve: bouncy ? Curves.elasticOut : Curves.easeOut,
              turns: selected ? -0.03 : 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? mood.color : scheme.surfaceContainerHigh,
                  border: Border.all(color: selected ? scheme.surface : Colors.transparent, width: 3),
                  boxShadow: selected
                      ? [BoxShadow(color: mood.color.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 3))]
                      : null,
                ),
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: dimmed ? 0.5 : 1,
                  child: Text(mood.emoji, style: const TextStyle(fontSize: 23, height: 1.1)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
