import 'dart:io' show Platform;

import 'package:intl/intl.dart';

/// Diary days are plain local calendar dates. Everything is normalised to
/// midnight local time and keyed as `yyyy-MM-dd`, so DST shifts and time
/// zones never move an entry to a different day.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

DateTime addMonths(DateTime month, int months) => DateTime(month.year, month.month + months);

DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Whole calendar days between two dates (ignores the time of day).
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

int dayOfYear(DateTime d) => daysBetween(DateTime(d.year), d) + 1;

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String key) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key.trim());
  if (match == null) throw FormatException('Not a yyyy-MM-dd date', key);
  final y = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  final d = int.parse(match.group(3)!);
  final date = DateTime(y, m, d);
  if (date.year != y || date.month != m || date.day != d) {
    throw FormatException('Not a real calendar date', key);
  }
  return date;
}

DateTime? tryParseDateKey(String? key) {
  if (key == null) return null;
  try {
    return parseDateKey(key);
  } on FormatException {
    return null;
  }
}

/// First day of the week containing [d]. [firstWeekday] uses
/// [DateTime.monday]..[DateTime.sunday].
DateTime startOfWeek(DateTime d, int firstWeekday) =>
    addDays(dateOnly(d), -((d.weekday - firstWeekday) % 7));

/// The device locale's first day of the week ([DateTime.monday]..[DateTime.sunday]).
/// Requires `initializeDateFormatting()` to have run.
int localeFirstWeekday() {
  try {
    final locale = Intl.verifiedLocale(
      Platform.localeName.split('.').first,
      DateFormat.localeExists,
      onFailure: (_) => 'en_US',
    );
    // intl: 0 = Monday ... 6 = Sunday.
    return DateFormat.yMd(locale).dateSymbols.FIRSTDAYOFWEEK + 1;
  } catch (_) {
    return DateTime.sunday;
  }
}

final _long = DateFormat('EEEE, d MMMM y');
final _longNoYear = DateFormat('EEEE, d MMMM');
final _short = DateFormat('EEE, d MMM');
final _shortYear = DateFormat('EEE, d MMM y');
final _monthYear = DateFormat('MMMM y');
final _weekday = DateFormat('EEEE');
final _dayMonth = DateFormat('d MMMM');

String formatLong(DateTime d) => _long.format(d);

String formatLongSmart(DateTime d, {DateTime? now}) =>
    d.year == (now ?? DateTime.now()).year ? _longNoYear.format(d) : _long.format(d);

String formatShort(DateTime d, {DateTime? now}) =>
    d.year == (now ?? DateTime.now()).year ? _short.format(d) : _shortYear.format(d);

String formatMonthYear(DateTime d) => _monthYear.format(d);

String formatMonth(DateTime d) => DateFormat('MMMM').format(d);

String formatWeekday(DateTime d) => _weekday.format(d);

String formatDayMonth(DateTime d) => _dayMonth.format(d);

/// "Today", "Yesterday", "Tuesday" (within a week) or "Tue, 3 Oct".
String relativeDayLabel(DateTime day, DateTime today) {
  final diff = daysBetween(day, today);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return formatWeekday(day);
  return formatShort(day, now: today);
}

/// "just now", "5 min ago", "3 h ago", "2 days ago"...
String timeAgo(DateTime then, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(then);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  final days = diff.inDays;
  if (days == 1) return 'yesterday';
  if (days < 30) return '$days days ago';
  return formatShort(then, now: now);
}

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Up late?';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  if (h < 22) return 'Good evening';
  return 'Winding down?';
}
