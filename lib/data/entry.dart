import 'package:flutter/foundation.dart';

import '../utils/dates.dart';
import '../utils/stats.dart';

/// One diary page. There is at most one entry per calendar day, keyed by
/// [date] (`yyyy-MM-dd`).
@immutable
class DiaryEntry {
  const DiaryEntry({
    required this.date,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.mood,
  });

  final String date;
  final String text;

  /// 1 (awful) .. 5 (great), or null when not set.
  final int? mood;
  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get day => parseDateKey(date);

  int get wordCount => countWords(text);

  /// Single-line version of the text for lists and the widget.
  String get preview => text.trim().replaceAll(RegExp(r'\s+'), ' ');

  DiaryEntry copyWith({String? text, int? Function()? mood, DateTime? updatedAt}) => DiaryEntry(
    date: date,
    text: text ?? this.text,
    mood: mood != null ? mood() : this.mood,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toRow() => {
    'date': date,
    'body': text,
    'mood': mood,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory DiaryEntry.fromRow(Map<String, Object?> row) => DiaryEntry(
    date: row['date']! as String,
    text: (row['body'] as String?) ?? '',
    mood: row['mood'] as int?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
  );

  Map<String, Object?> toJson() => {
    'date': date,
    'text': text,
    if (mood != null) 'mood': mood,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  /// Lenient parser for backups: only `date` is required.
  factory DiaryEntry.fromJson(Map<String, Object?> json) {
    final rawDate = json['date'];
    if (rawDate is! String) throw const FormatException('Entry without a date');
    final day = parseDateKey(rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate);
    final text = json['text'] ?? json['body'] ?? '';
    if (text is! String) throw FormatException('Entry text is not a string', rawDate);
    final rawMood = json['mood'];
    final mood = rawMood is num ? rawMood.round().clamp(1, 5) : null;
    DateTime? time(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final created = time(json['createdAt']) ?? day;
    final updated = time(json['updatedAt']) ?? created;
    return DiaryEntry(
      date: dateKey(day),
      text: text,
      mood: mood,
      createdAt: created,
      updatedAt: updated,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryEntry &&
      other.date == date &&
      other.text == text &&
      other.mood == mood &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(date, text, mood, createdAt, updatedAt);

  @override
  String toString() => 'DiaryEntry($date, ${text.length} chars, mood: $mood)';
}
