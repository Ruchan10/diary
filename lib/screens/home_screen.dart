import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/entry.dart';
import '../data/entry_repository.dart';
import '../navigation.dart';
import '../services/settings.dart';
import '../services/update_checker.dart';
import '../theme/moods.dart';
import '../theme/theme.dart';
import '../utils/dates.dart';
import '../utils/stats.dart';
import '../widgets/entry_tile.dart';
import '../widgets/inkling_logo.dart';
import '../widgets/inky.dart';
import '../widgets/month_calendar.dart';
import '../widgets/playful.dart';
import 'settings_screen.dart';
import 'stickers_screen.dart';

const _quips = [
  'I’m made of 100% ink. Please don’t spill me.',
  'Octopuses have ink too. We’re basically cousins. 🐙',
  'Small moments make the best pages.',
  'I can keep a secret. Pinky promise. 🤫',
  'Did you drink water today? 💧',
  'A line a day keeps the forgetting away.',
  'Psst… your calendar is looking lovely.',
  'Tap “Write today” and tell me everything!',
  'Fun fact: I’ve never been on a fountain pen. Yet.',
  'Collect stickers by writing! 🏆',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _month = monthOf(today());
  final _quipStart = Random().nextInt(_quips.length);
  int _quipCount = 0;
  String? _quip;
  Timer? _quipTimer;

  @override
  void dispose() {
    _quipTimer?.cancel();
    super.dispose();
  }

  void _openDay(DateTime day) => AppNav.openCompose(context, day);

  void _openStickers() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StickersScreen()));

  void _tapInky() {
    HapticFeedback.lightImpact();
    setState(() => _quip = _quips[(_quipStart + _quipCount++) % _quips.length]);
    _quipTimer?.cancel();
    _quipTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _quip = null);
    });
  }

  DateTime _firstMonth(EntryRepository repo, DateTime t) {
    final fiveYearsAgo = DateTime(t.year - 5, t.month);
    final first = repo.firstDay;
    return first != null && first.isBefore(fiveYearsAgo) ? monthOf(first) : fiveYearsAgo;
  }

  Future<void> _pickMonth(EntryRepository repo, DateTime firstMonth) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (_) => _MonthPickerSheet(initial: _month, firstMonth: firstMonth, repo: repo),
    );
    if (picked != null) setState(() => _month = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.watch<EntryRepository>();
    final settings = context.watch<SettingsController>();
    final updates = context.watch<UpdateController>();
    final t = today();
    final stats = repo.statsFor(t);
    final firstMonth = _firstMonth(repo, t);
    final monthEntries = repo.entriesInMonth(_month);
    final memories = repo.onThisDay(t);
    final isCurrentMonth = isSameMonth(_month, t);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            titleSpacing: 20,
            title: Row(
              children: [
                const InklingLogo(size: 30),
                const SizedBox(width: 10),
                Text('Inkling', style: theme.appBarTheme.titleTextStyle?.copyWith(fontSize: 27)),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _openStickers,
                icon: const Icon(Icons.emoji_events_outlined),
                tooltip: 'Sticker book',
              ),
              IconButton(
                onPressed: () => AppNav.handle(const LaunchRequest(LaunchKind.search)),
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search',
              ),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList.list(
              children: [
                _Greeting(stats: stats, quip: _quip, onInkyTap: _tapInky),
                const SizedBox(height: 18),
                PopIn(
                  delay: const Duration(milliseconds: 120),
                  child: _StatStickers(stats: stats, onTap: _openStickers),
                ),
                if (updates.available case final info?) ...[
                  const SizedBox(height: 14),
                  _UpdateBanner(info: info),
                ],
                const SizedBox(height: 18),
                PopIn(
                  delay: const Duration(milliseconds: 220),
                  child: CalendarCard(
                    month: _month,
                    today: t,
                    firstMonth: firstMonth,
                    firstWeekday: settings.firstWeekday,
                    style: settings.calendarStyle,
                    entryFor: repo.entryFor,
                    monthCount: monthEntries.length,
                    onMonthChanged: (m) => setState(() => _month = m),
                    onDayTap: _openDay,
                    onPickMonth: () => _pickMonth(repo, firstMonth),
                  ),
                ),
                if (memories.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const HandHeader('On this day'),
                  const SizedBox(height: 14),
                  for (final (i, e) in memories.take(3).indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _Polaroid(entry: e, years: t.year - e.day.year, tilt: i.isEven ? -0.022 : 0.018, onTap: () => _openDay(e.day)),
                    ),
                ],
                const SizedBox(height: 22),
                HandHeader(isCurrentMonth ? 'This month' : formatMonthYear(_month)),
                const SizedBox(height: 10),
                if (monthEntries.isEmpty)
                  _EmptyMonth(month: _month, isCurrent: isCurrentMonth, onWrite: () => _openDay(t))
                else
                  for (final e in monthEntries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EntryTile(entry: e, onTap: () => _openDay(e.day)),
                    ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Wiggle(
        active: !stats.writtenToday,
        child: Squishy(
          child: FloatingActionButton.extended(
            onPressed: () => _openDay(t),
            icon: Icon(stats.writtenToday ? Icons.edit_note_rounded : Icons.edit_rounded),
            label: Text(stats.writtenToday ? 'Add to today' : 'Write today'),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.stats, required this.quip, required this.onInkyTap});

  final DiaryStats stats;
  final String? quip;
  final VoidCallback onInkyTap;

  InkyFace _face(DateTime now) {
    if (now.hour >= 23 || now.hour < 5) return InkyFace.sleepy;
    if (stats.writtenToday) return stats.currentStreak >= 3 ? InkyFace.excited : InkyFace.happy;
    if (stats.currentStreak > 0) return InkyFace.surprised;
    return InkyFace.happy;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final streak = stats.currentStreak;
    final line = switch ((stats.writtenToday, streak, stats.totalEntries)) {
      (_, _, 0) => 'I’m Inky! Your very first page is waiting ✨',
      (true, >= 2, _) => '🔥 $streak days in a row! I’m so proud.',
      (true, _, _) => 'Today’s page is safe with me ✅',
      (false, >= 1, _) => '🔥 $streak-day streak! Don’t leave me hanging today.',
      _ => 'Got a minute? Tell me about today.',
    };
    final text = quip == null ? null : Text(quip!, style: handStyle(22, color: scheme.onSurface));

    return Row(
      children: [
        Inky(size: 96, face: quip == null ? _face(now) : InkyFace.wink, onTap: onInkyTap),
        const SizedBox(width: 4),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, a) => ScaleTransition(scale: a, alignment: Alignment.centerLeft, child: child),
            child: SpeechBubble(
              key: ValueKey(quip ?? line),
              child:
                  text ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greetingFor(now), style: handStyle(30, color: scheme.onSurface, height: 1)),
                      const SizedBox(height: 2),
                      Text(line, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatStickers extends StatelessWidget {
  const _StatStickers({required this.stats, required this.onTap});

  final DiaryStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _StatSticker(
            emoji: '🔥',
            value: '${stats.currentStreak}',
            label: 'day streak',
            color: scheme.tertiaryContainer,
            onColor: scheme.onTertiaryContainer,
            angle: -0.04,
            onTap: onTap,
            tooltip: 'Longest streak: ${stats.longestStreak} days',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatSticker(
            emoji: '📖',
            value: compactNumber(stats.totalEntries),
            label: stats.totalEntries == 1 ? 'page' : 'pages',
            color: scheme.secondaryContainer,
            onColor: scheme.onSecondaryContainer,
            angle: 0.03,
            onTap: onTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatSticker(
            emoji: '✍️',
            value: compactNumber(stats.totalWords),
            label: 'words',
            color: scheme.primaryContainer,
            onColor: scheme.onPrimaryContainer,
            angle: -0.02,
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _StatSticker extends StatelessWidget {
  const _StatSticker({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
    required this.onColor,
    required this.angle,
    required this.onTap,
    this.tooltip,
  });

  final String emoji;
  final String value;
  final String label;
  final Color color;
  final Color onColor;
  final double angle;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sticker = Transform.rotate(
      angle: angle,
      child: Squishy(
        child: Material(
          color: color,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.colorScheme.surface, width: 3),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(color: onColor, height: 1.1, fontSize: 24),
                        ),
                      ),
                    ],
                  ),
                  Text(label, style: handStyle(19, color: onColor, weight: FontWeight.w600, height: 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? sticker : Tooltip(message: tooltip, child: sticker);
  }
}

/// "On this day" memories, taped in like an instant photo.
class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.entry, required this.years, required this.tilt, required this.onTap});

  final DiaryEntry entry;
  final int years;
  final double tilt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mood = moodFor(entry.mood);
    final dark = scheme.brightness == Brightness.dark;
    return Transform.rotate(
      angle: tilt,
      child: Squishy(
        pressedScale: 0.97,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: dark ? scheme.surfaceContainerHighest : Colors.white,
              elevation: 3,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📸 ${years == 1 ? 'A year' : '$years years'} ago today',
                              style: handStyle(23, color: scheme.primary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.preview.isEmpty ? 'Just a mood that day.' : entry.preview,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4, color: scheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                      if (mood != null) ...[const SizedBox(width: 8), MoodSticker(mood: mood, size: 34)],
                    ],
                  ),
                ),
              ),
            ),
            // A strip of tape holding it in place.
            Positioned(
              top: -9,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: -0.06,
                  child: Container(width: 74, height: 20, color: scheme.tertiaryContainer.withValues(alpha: 0.85)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth({required this.month, required this.isCurrent, required this.onWrite});

  final DateTime month;
  final bool isCurrent;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Inky(size: 84, face: isCurrent ? InkyFace.surprised : InkyFace.sleepy),
          const SizedBox(height: 10),
          Text(
            'No ink spilled in ${formatMonth(month)} ${isCurrent ? 'yet' : ''}'.trimRight(),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            isCurrent ? 'Inky is bored. Tell it something!' : 'Tap any day above to fill it in.',
            style: handStyle(21, color: theme.colorScheme.onSurfaceVariant, weight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          if (isCurrent) ...[
            const SizedBox(height: 14),
            Squishy(
              child: FilledButton.tonalIcon(
                onPressed: onWrite,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Write today’s page'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.info});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Inky(size: 40, face: InkyFace.excited, shadow: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Inkling ${info.version} is here!',
                    style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.read<UpdateController>().skip(info),
                  child: const Text('Skip'),
                ),
                FilledButton(
                  onPressed: () => launchUrl(info.download ?? info.page, mode: LaunchMode.externalApplication),
                  child: const Text('Get it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.initial, required this.firstMonth, required this.repo});

  final DateTime initial;
  final DateTime firstMonth;
  final EntryRepository repo;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = today();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _year > widget.firstMonth.year ? () => setState(() => _year--) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(child: Center(child: Text('$_year', style: handStyle(34, color: scheme.onSurface)))),
                IconButton(
                  onPressed: _year < t.year ? () => setState(() => _year++) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var m = 1; m <= 12; m++)
                  Builder(
                    builder: (context) {
                      final month = DateTime(_year, m);
                      final enabled = !month.isAfter(t) && !month.isBefore(widget.firstMonth);
                      final selected = isSameMonth(month, widget.initial);
                      final count = widget.repo.countInMonth(month);
                      return Squishy(
                        child: Material(
                          color: selected ? scheme.primary : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: enabled ? () => Navigator.pop(context, month) : null,
                            child: Opacity(
                              opacity: enabled ? 1 : 0.35,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    formatMonth(month).substring(0, 3),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: selected ? scheme.onPrimary : scheme.onSurface,
                                    ),
                                  ),
                                  if (count > 0)
                                    Text(
                                      '${'💧' * min(count, 3)}${count > 3 ? ' $count' : ''}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: selected ? scheme.onPrimary : scheme.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
