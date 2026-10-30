import 'dart:convert';

import 'package:intl/intl.dart';

import '../config.dart';
import '../theme/moods.dart';
import '../utils/dates.dart';
import 'entry.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Parsed backup file, ready to be previewed and imported.
class BackupContents {
  const BackupContents(this.entries, {this.skipped = 0, this.exportedAt});

  /// Sorted oldest first, one per day.
  final List<DiaryEntry> entries;

  /// Records in the file that could not be read.
  final int skipped;
  final DateTime? exportedAt;

  DateTime? get firstDay => entries.isEmpty ? null : entries.first.day;
  DateTime? get lastDay => entries.isEmpty ? null : entries.last.day;
}

abstract final class Backup {
  static const formatVersion = 1;
  static const _formatKey = 'inkling-backup';

  static String encodeJson(Iterable<DiaryEntry> entries, {required DateTime exportedAt, String? appVersion}) {
    final sorted = entries.toList()..sort((a, b) => a.date.compareTo(b.date));
    return const JsonEncoder.withIndent('  ').convert({
      'format': _formatKey,
      'version': formatVersion,
      'app': AppConfig.appName,
      'appVersion': ?appVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'count': sorted.length,
      'entries': [for (final e in sorted) e.toJson()],
    });
  }

  /// Accepts an Inkling backup, or a bare JSON list of `{date, text}` objects.
  static BackupContents decodeJson(String source) {
    final Object? json;
    try {
      json = jsonDecode(source.startsWith('﻿') ? source.substring(1) : source);
    } on FormatException {
      throw const BackupFormatException('That file isn’t valid JSON. Pick an Inkling backup (.json).');
    }

    final List<Object?> rawEntries;
    DateTime? exportedAt;
    if (json is Map<String, Object?>) {
      final version = json['version'];
      if (json['format'] == _formatKey && version is int && version > formatVersion) {
        throw const BackupFormatException('This backup was made by a newer version of Inkling. Update the app first.');
      }
      final list = json['entries'];
      if (list is! List<Object?>) {
        throw const BackupFormatException('No diary entries found in that file.');
      }
      rawEntries = list;
      final at = json['exportedAt'];
      exportedAt = at is String ? DateTime.tryParse(at)?.toLocal() : null;
    } else if (json is List<Object?>) {
      rawEntries = json;
    } else {
      throw const BackupFormatException('No diary entries found in that file.');
    }

    final byDate = <String, DiaryEntry>{};
    var skipped = 0;
    for (final raw in rawEntries) {
      try {
        if (raw is! Map<String, Object?>) throw const FormatException('not an object');
        final entry = DiaryEntry.fromJson(raw);
        if (entry.text.trim().isEmpty && entry.mood == null) throw const FormatException('empty');
        final previous = byDate[entry.date];
        if (previous == null || entry.updatedAt.isAfter(previous.updatedAt)) byDate[entry.date] = entry;
      } on FormatException {
        skipped++;
      }
    }
    if (byDate.isEmpty) {
      throw const BackupFormatException('No readable diary entries found in that file.');
    }
    final entries = byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return BackupContents(entries, skipped: skipped, exportedAt: exportedAt);
  }

  /// A human-friendly copy of the diary, oldest entry first, like a book.
  static String encodeMarkdown(Iterable<DiaryEntry> entries, {required DateTime exportedAt}) {
    final sorted = entries.toList()..sort((a, b) => a.date.compareTo(b.date));
    final buffer = StringBuffer()
      ..writeln('# ${AppConfig.appName}: my diary')
      ..writeln()
      ..writeln('_Exported ${DateFormat('d MMMM y, HH:mm').format(exportedAt)} · '
          '${sorted.length} ${sorted.length == 1 ? 'entry' : 'entries'}_')
      ..writeln();
    int? year;
    for (final e in sorted) {
      final day = e.day;
      if (day.year != year) {
        year = day.year;
        buffer
          ..writeln('---')
          ..writeln()
          ..writeln('# $year')
          ..writeln();
      }
      final mood = moodFor(e.mood);
      buffer
        ..writeln('## ${formatLong(day)}${mood == null ? '' : '  ${mood.emoji}'}')
        ..writeln()
        ..writeln(e.text.trim())
        ..writeln();
    }
    return buffer.toString();
  }

  static String fileName(DateTime now, String extension) =>
      'inkling-${DateFormat('yyyy-MM-dd-HHmm').format(now)}.$extension';
}
