import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/entry.dart';
import '../services/settings.dart';
import '../theme/moods.dart';
import '../theme/theme.dart';
import '../utils/dates.dart';
import 'playful.dart';

/// The dashboard calendar. Days you wrote on get a splotch of ink, today gets
/// a pencil circle, and runs of days are joined like a highlighter stroke.
class CalendarCard extends StatefulWidget {
  const CalendarCard({
    super.key,
    required this.month,
    required this.today,
    required this.firstMonth,
    required this.firstWeekday,
    required this.style,
    required this.entryFor,
    required this.monthCount,
    required this.onMonthChanged,
    required this.onDayTap,
    this.onPickMonth,
  });

  final DateTime month;
  final DateTime today;
  final DateTime firstMonth;
  final int firstWeekday;
  final CalendarStyle style;
  final DiaryEntry? Function(DateTime day) entryFor;
  final int monthCount;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback? onPickMonth;

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  int _direction = 1;

  bool get _canGoBack => widget.month.isAfter(widget.firstMonth);
  bool get _canGoForward => widget.month.isBefore(monthOf(widget.today));
  bool get _isCurrentMonth => isSameMonth(widget.month, widget.today);

  @override
  void didUpdateWidget(CalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameMonth(oldWidget.month, widget.month)) {
      _direction = widget.month.isAfter(oldWidget.month) ? 1 : -1;
    }
  }

  void _go(int delta) {
    if (delta < 0 && !_canGoBack || delta > 0 && !_canGoForward) return;
    widget.onMonthChanged(addMonths(widget.month, delta));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final month = widget.month;
    final count = widget.monthCount;
    final title = month.year == widget.today.year ? formatMonth(month) : formatMonthYear(month);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _canGoBack ? () => _go(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous month',
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: widget.onPickMonth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        children: [
                          Text(title, style: handStyle(32, color: scheme.onSurface)),
                          Text(
                            count == 0 ? 'No ink yet' : '$count ${count == 1 ? 'page' : 'pages'} written',
                            style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_isCurrentMonth)
                  IconButton(
                    onPressed: () => widget.onMonthChanged(monthOf(widget.today)),
                    icon: const Icon(Icons.today_rounded),
                    tooltip: 'Back to this month',
                  ),
                IconButton(
                  onPressed: _canGoForward ? () => _go(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next month',
                ),
              ],
            ),
            const SizedBox(height: 6),
            _WeekdayRow(firstWeekday: widget.firstWeekday),
            const SizedBox(height: 2),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -200) _go(1);
                if (v > 200) _go(-1);
              },
              child: AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(month);
                    final offset = Tween(
                      begin: Offset(0.18 * _direction * (incoming ? 1 : -1), 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: _MonthGrid(
                    key: ValueKey(month),
                    month: month,
                    today: widget.today,
                    firstWeekday: widget.firstWeekday,
                    style: widget.style,
                    entryFor: widget.entryFor,
                    onDayTap: widget.onDayTap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.firstWeekday});

  final int firstWeekday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = DateFormat('EEEEE');
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                // 1 Jan 2024 was a Monday.
                narrow.format(DateTime(2024, 1, (firstWeekday - 1 + i) % 7 + 1)),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    super.key,
    required this.month,
    required this.today,
    required this.firstWeekday,
    required this.style,
    required this.entryFor,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime today;
  final int firstWeekday;
  final CalendarStyle style;
  final DiaryEntry? Function(DateTime day) entryFor;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final leading = (DateTime(month.year, month.month).weekday - firstWeekday) % 7;
    final days = daysInMonth(month.year, month.month);
    final rows = ((leading + days) / 7).ceil();
    final entries = [for (var d = 1; d <= days; d++) entryFor(DateTime(month.year, month.month, d))];
    bool written(int d) => d >= 1 && d <= days && entries[d - 1] != null;

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final d = r * 7 + c - leading + 1;
                      if (d < 1 || d > days) return const SizedBox(height: 46);
                      final day = DateTime(month.year, month.month, d);
                      return _DayCell(
                        day: day,
                        entry: entries[d - 1],
                        isToday: isSameDay(day, today),
                        isFuture: day.isAfter(today),
                        style: style,
                        joinLeft: c > 0 && written(d) && written(d - 1),
                        joinRight: c < 6 && written(d) && written(d + 1),
                        onTap: () => onDayTap(day),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.entry,
    required this.isToday,
    required this.isFuture,
    required this.style,
    required this.joinLeft,
    required this.joinRight,
    required this.onTap,
  });

  final DateTime day;
  final DiaryEntry? entry;
  final bool isToday;
  final bool isFuture;
  final CalendarStyle style;
  final bool joinLeft;
  final bool joinRight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = this.entry;
    final mood = style == CalendarStyle.mood ? moodFor(entry?.mood) : null;

    final Color? ink = entry == null ? null : (mood?.color ?? scheme.primary);
    final Color textColor;
    if (entry != null) {
      textColor = mood != null ? const Color(0xDD1B1B1F) : scheme.onPrimary;
    } else {
      textColor = isFuture
          ? scheme.onSurface.withValues(alpha: 0.3)
          : (isToday ? scheme.primary : scheme.onSurface);
    }
    final band = (mood == null ? scheme.primary : scheme.onSurface).withValues(alpha: 0.15);

    final label = StringBuffer(formatLong(day));
    if (isToday) label.write(', today');
    if (entry != null) {
      label.write(', written');
      if (moodFor(entry.mood) case final m?) label.write(', feeling ${m.label.toLowerCase()}');
    } else if (!isFuture) {
      label.write(', not written');
    }

    return Semantics(
      container: true,
      button: !isFuture,
      label: label.toString(),
      excludeSemantics: true,
      child: SizedBox(
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (joinLeft || joinRight)
              Row(
                children: [
                  Expanded(child: Container(height: 26, color: joinLeft ? band : null)),
                  Expanded(child: Container(height: 26, color: joinRight ? band : null)),
                ],
              ),
            Squishy(
              pressedScale: 0.8,
              child: InkResponse(
                onTap: isFuture ? null : onTap,
                radius: 24,
                child: CustomPaint(
                  painter: _InkDayPainter(
                    seed: day.year * 10000 + day.month * 100 + day.day,
                    ink: ink,
                    pencil: isToday ? scheme.primary : null,
                  ),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: textColor,
                          fontWeight: entry != null || isToday ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-of-a-kind ink blot (the same every time for a given day) and/or a
/// quick pencil circle.
class _InkDayPainter extends CustomPainter {
  _InkDayPainter({required this.seed, this.ink, this.pencil});

  final int seed;
  final Color? ink;
  final Color? pencil;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final random = Random(seed);
    if (ink case final ink?) {
      final r = size.shortestSide / 2 - (pencil != null ? 4.5 : 1);
      canvas.drawPath(inkBlot(c, r, random), Paint()..color = ink);
      // Every so often, a stray splash.
      if (seed % 5 == 0) {
        final a = random.nextDouble() * 2 * pi;
        canvas.drawCircle(c + Offset(cos(a), sin(a)) * (r + 4), 2.2, Paint()..color = ink);
      }
    }
    if (pencil case final pencil?) {
      canvas.drawPath(
        pencilCircle(c, size.shortestSide / 2 + 1, Random(seed + 7)),
        Paint()
          ..color = pencil
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_InkDayPainter old) => old.seed != seed || old.ink != ink || old.pencil != pencil;
}

/// A wobbly, closed blob around [c].
Path inkBlot(Offset c, double r, Random random, {int points = 8, double wobble = 0.09}) {
  final rotation = random.nextDouble() * 2 * pi;
  final pts = [
    for (var i = 0; i < points; i++)
      c +
          Offset(cos(rotation + i * 2 * pi / points), sin(rotation + i * 2 * pi / points)) *
              (r * (1 - wobble + random.nextDouble() * wobble * 2)),
  ];
  // Catmull-Rom through the points, as cubic Béziers.
  final path = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (var i = 0; i < points; i++) {
    final p0 = pts[(i - 1 + points) % points], p1 = pts[i], p2 = pts[(i + 1) % points], p3 = pts[(i + 2) % points];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path..close();
}

/// A slightly-more-than-once-around circle, like a quick pen loop.
Path pencilCircle(Offset c, double r, Random random) {
  final start = -pi * (0.55 + random.nextDouble() * 0.2);
  final phase = random.nextDouble() * 2 * pi;
  final path = Path();
  const steps = 48;
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final a = start + t * 2 * pi * 1.1;
    final rr = r * (1 + 0.045 * sin(3 * a + phase) + 0.05 * t);
    final p = c + Offset(cos(a), sin(a)) * rr;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path;
}
