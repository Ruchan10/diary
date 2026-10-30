import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkling/data/backup.dart';
import 'package:inkling/data/entry.dart';

DiaryEntry entry(String date, String text, {int? mood, DateTime? updated}) => DiaryEntry(
  date: date,
  text: text,
  mood: mood,
  createdAt: DateTime(2026, 1, 1, 9),
  updatedAt: updated ?? DateTime(2026, 1, 1, 10),
);

void main() {
  test('JSON backup round-trips every field', () {
    final entries = [
      entry('2026-10-24', 'Rainy. Read all afternoon ☔', mood: 4),
      entry('2026-10-25', 'Line one\nLine two', updated: DateTime(2026, 10, 25, 22, 5)),
    ];
    final json = Backup.encodeJson(entries, exportedAt: DateTime(2026, 10, 25, 23), appVersion: '1.0.0');
    final decoded = Backup.decodeJson(json);
    expect(decoded.entries, entries);
    expect(decoded.skipped, 0);
    expect(decoded.exportedAt, DateTime(2026, 10, 25, 23));
    expect(jsonDecode(json)['format'], 'inkling-backup');
  });

  test('accepts a bare list and skips unreadable records', () {
    final contents = Backup.decodeJson(
      jsonEncode([
        {'date': '2026-05-01', 'text': 'Hello'},
        {'date': 'not a date', 'text': 'x'},
        {'text': 'no date'},
        {'date': '2026-05-02', 'text': '   '},
        {'date': '2026-05-03T12:00:00Z', 'body': 'Old field name', 'mood': 9},
      ]),
    );
    expect(contents.entries.map((e) => e.date), ['2026-05-01', '2026-05-03']);
    expect(contents.entries.last.text, 'Old field name');
    expect(contents.entries.last.mood, 5);
    expect(contents.skipped, 3);
  });

  test('keeps the newest copy when a day appears twice', () {
    final contents = Backup.decodeJson(
      jsonEncode([
        {'date': '2026-05-01', 'text': 'old', 'updatedAt': '2026-05-01T08:00:00Z'},
        {'date': '2026-05-01', 'text': 'new', 'updatedAt': '2026-05-01T09:00:00Z'},
      ]),
    );
    expect(contents.entries.single.text, 'new');
  });

  test('rejects files that are not backups', () {
    expect(() => Backup.decodeJson('hello'), throwsA(isA<BackupFormatException>()));
    expect(() => Backup.decodeJson('{"foo": 1}'), throwsA(isA<BackupFormatException>()));
    expect(() => Backup.decodeJson('[]'), throwsA(isA<BackupFormatException>()));
    expect(
      () => Backup.decodeJson('{"format": "inkling-backup", "version": 99, "entries": []}'),
      throwsA(isA<BackupFormatException>().having((e) => e.message, 'message', contains('newer version'))),
    );
  });

  test('markdown export reads like a book', () {
    final md = Backup.encodeMarkdown([
      entry('2026-01-02', 'Second', mood: 5),
      entry('2025-12-31', 'First'),
    ], exportedAt: DateTime(2026, 1, 3));
    expect(md.indexOf('# 2025'), lessThan(md.indexOf('# 2026')));
    expect(md, contains('## Wednesday, 31 December 2025'));
    expect(md, contains('## Friday, 2 January 2026  😄'));
    expect(md, contains('2 entries'));
  });
}
