import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/entry_repository.dart';
import '../data/stickers.dart';
import '../theme/theme.dart';
import '../utils/dates.dart';
import '../widgets/inky.dart';
import '../widgets/playful.dart';

const _greyscale = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Achievements as collectible stickers, worked out from the diary.
class StickersScreen extends StatelessWidget {
  const StickersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final repo = context.watch<EntryRepository>();
    final progress = StickerProgress.of(repo, today());
    final got = stickers.where((s) => s.unlocked(progress)).length;
    final all = got == stickers.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Sticker book')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Inky(size: 84, face: all ? InkyFace.excited : (got == 0 ? InkyFace.surprised : InkyFace.happy)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SpeechBubble(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$got of ${stickers.length} collected', style: handStyle(27, color: scheme.onSurface)),
                          Text(
                            all
                                ? 'You got them all! Inky is speechless.'
                                : got == 0
                                ? 'Write your first page to earn one!'
                                : 'Keep writing to fill the book.',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            sliver: SliverGrid.count(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.86,
              children: [
                for (final (i, s) in stickers.indexed)
                  _StickerTile(sticker: s, progress: progress, index: i),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _stickerColor(ColorScheme scheme, int index) =>
    [scheme.primaryContainer, scheme.tertiaryContainer, scheme.secondaryContainer][index % 3];

class StickerBadge extends StatelessWidget {
  const StickerBadge({super.key, required this.sticker, required this.unlocked, required this.index, this.size = 74});

  final Sticker sticker;
  final bool unlocked;
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final angle = ((sticker.id.hashCode % 9) - 4) * 0.025;
    final face = Text(sticker.emoji, style: TextStyle(fontSize: size * 0.46, height: 1.1));
    return Transform.rotate(
      angle: unlocked ? angle : 0,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: unlocked ? _stickerColor(scheme, index) : scheme.surfaceContainerHigh,
          border: Border.all(color: unlocked ? scheme.surface : scheme.outlineVariant, width: unlocked ? 4 : 1.5),
          boxShadow: unlocked ? const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))] : null,
        ),
        child: unlocked ? face : Opacity(opacity: 0.3, child: ColorFiltered(colorFilter: _greyscale, child: face)),
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({required this.sticker, required this.progress, required this.index});

  final Sticker sticker;
  final StickerProgress progress;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unlocked = sticker.unlocked(progress);
    final value = sticker.progress(progress);
    return Semantics(
      button: true,
      label: '${sticker.name}, ${unlocked ? 'collected' : 'not collected yet'}',
      excludeSemantics: true,
      child: Squishy(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDetails(context, unlocked, value),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                StickerBadge(sticker: sticker, unlocked: unlocked, index: index),
                const SizedBox(height: 8),
                Text(
                  unlocked ? sticker.name : '???',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: unlocked ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
                if (!unlocked && sticker.goal > 1) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: value / sticker.goal, minHeight: 6),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, bool unlocked, int value) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopIn(child: StickerBadge(sticker: sticker, unlocked: unlocked, index: index, size: 112)),
              const SizedBox(height: 16),
              Text(unlocked ? sticker.name : 'A mystery sticker', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(sticker.description, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 10),
              Text(
                unlocked
                    ? 'Collected! 🎉'
                    : sticker.goal > 1
                    ? '$value of ${sticker.goal} ${sticker.unit} so far'
                    : 'Not yet… keep writing!',
                style: handStyle(24, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
