import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../utils/dates.dart';
import '../utils/stats.dart';
import 'entry.dart';

enum ImportMode {
  /// For days that exist on both sides, keep whichever was edited last.
  keepNewest,

  /// For days that exist on both sides, append the imported text.
  keepBoth,

  /// Wipe the diary and use only the imported entries.
  replaceAll,
}

class ImportSummary {
  const ImportSummary({this.added = 0, this.updated = 0, this.merged = 0, this.unchanged = 0});

  final int added;
  final int updated;
  final int merged;
  final int unchanged;

  int get changed => added + updated + merged;
}

@immutable
class DiaryStats {
  const DiaryStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalEntries,
    required this.totalWords,
    required this.writtenToday,
  });

  final int currentStreak;
  final int longestStreak;
  final int totalEntries;
  final int totalWords;
  final bool writtenToday;
}

/// Owns the diary. Every entry is kept in memory (a decade of daily writing is
/// only a few MB) so the calendar, stats and search are instant; SQLite is the
/// durable copy.
class EntryRepository extends ChangeNotifier {
  EntryRepository._(this._db, Iterable<DiaryEntry> entries) {
    for (final e in entries) {
      _entries[e.date] = e;
    }
  }

  static const _table = 'entries';
  static const _separator = '\n\n· · ·\n\n';

  static Future<EntryRepository> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'inkling.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE $_table (
            date TEXT PRIMARY KEY,
            body TEXT NOT NULL,
            mood INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )'''),
      ),
    );
    final rows = await db.query(_table);
    return EntryRepository._(db, rows.map(DiaryEntry.fromRow));
  }

  final Database _db;
  final Map<String, DiaryEntry> _entries = {};

  List<DiaryEntry>? _sortedCache;
  (String, DiaryStats)? _statsCache;

  Future<void> close() => _db.close();

  int get count => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  Set<String> get dateKeys => _entries.keys.toSet();

  DiaryEntry? entryFor(DateTime day) => _entries[dateKey(day)];

  bool hasEntry(DateTime day) => _entries.containsKey(dateKey(day));

  /// Newest first.
  List<DiaryEntry> get allEntries =>
      _sortedCache ??= List.unmodifiable(_entries.values.toList()..sort((a, b) => b.date.compareTo(a.date)));

  DiaryEntry? latestOnOrBefore(DateTime day) {
    final key = dateKey(day);
    for (final e in allEntries) {
      if (e.date.compareTo(key) <= 0) return e;
    }
    return null;
  }

  /// Newest first.
  List<DiaryEntry> entriesInMonth(DateTime month) {
    final prefix = dateKey(DateTime(month.year, month.month)).substring(0, 8);
    return allEntries.where((e) => e.date.startsWith(prefix)).toList();
  }

  int countInMonth(DateTime month) => entriesInMonth(month).length;

  /// Entries written on the same calendar day in earlier years, newest first.
  List<DiaryEntry> onThisDay(DateTime day) {
    final suffix = dateKey(day).substring(4);
    final year = day.year.toString().padLeft(4, '0');
    return allEntries.where((e) => e.date.endsWith(suffix) && e.date.compareTo(year) < 0).toList();
  }

  DateTime? get firstDay => allEntries.isEmpty ? null : allEntries.last.day;

  /// Every word of the query has to appear (case-insensitive). Newest first.
  List<DiaryEntry> search(String query, {int? mood}) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return allEntries.where((e) {
      if (mood != null && e.mood != mood) return false;
      if (words.isEmpty) return true;
      final text = e.text.toLowerCase();
      return words.every(text.contains);
    }).toList();
  }

  DiaryStats statsFor(DateTime today) {
    final key = dateKey(today);
    final cached = _statsCache;
    if (cached != null && cached.$1 == key) return cached.$2;
    final keys = dateKeys;
    final stats = DiaryStats(
      currentStreak: currentStreak(keys, today),
      longestStreak: longestStreak(keys),
      totalEntries: keys.length,
      totalWords: _entries.values.fold(0, (sum, e) => sum + e.wordCount),
      writtenToday: keys.contains(key),
    );
    _statsCache = (key, stats);
    return stats;
  }

  /// Creates, updates or (when everything is blank) removes the entry for [day].
  Future<void> save(DateTime day, {required String text, int? mood}) async {
    final key = dateKey(day);
    if (text.trim().isEmpty && mood == null) return delete(day);
    final existing = _entries[key];
    if (existing != null && existing.text == text && existing.mood == mood) return;
    final now = DateTime.now();
    final entry = DiaryEntry(
      date: key,
      text: text,
      mood: mood,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    _entries[key] = entry;
    _changed();
    await _db.insert(_table, entry.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(DateTime day) async {
    final key = dateKey(day);
    if (_entries.remove(key) == null) return;
    _changed();
    await _db.delete(_table, where: 'date = ?', whereArgs: [key]);
  }

  Future<void> deleteAll() async {
    await _db.delete(_table);
    _entries.clear();
    _changed();
  }

  /// How many incoming entries land on a day that already has writing.
  int countConflicts(Iterable<DiaryEntry> incoming) =>
      incoming.where((e) => _entries.containsKey(e.date)).length;

  Future<ImportSummary> importEntries(List<DiaryEntry> incoming, ImportMode mode) async {
    final working = mode == ImportMode.replaceAll ? <String, DiaryEntry>{} : Map.of(_entries);
    final touched = <String>{};
    var added = 0, updated = 0, merged = 0, unchanged = 0;

    for (final e in incoming) {
      final existing = working[e.date];
      if (existing == null) {
        working[e.date] = e;
        touched.add(e.date);
        added++;
        continue;
      }
      final sameText = existing.text.trim() == e.text.trim();
      if (sameText && (e.mood == null || e.mood == existing.mood)) {
        unchanged++;
        continue;
      }
      if (mode == ImportMode.keepBoth && !sameText) {
        if (existing.text.contains(e.text.trim())) {
          unchanged++;
          continue;
        }
        working[e.date] = existing.copyWith(
          text: existing.text.trim().isEmpty ? e.text : '${existing.text.trimRight()}$_separator${e.text.trim()}',
          mood: () => existing.mood ?? e.mood,
          updatedAt: DateTime.now(),
        );
        merged++;
      } else if (e.updatedAt.isAfter(existing.updatedAt) || sameText) {
        working[e.date] = sameText ? existing.copyWith(mood: () => e.mood) : e;
        updated++;
      } else {
        unchanged++;
        continue;
      }
      touched.add(e.date);
    }

    await _db.transaction((txn) async {
      if (mode == ImportMode.replaceAll) await txn.delete(_table);
      final batch = txn.batch();
      for (final key in touched) {
        batch.insert(_table, working[key]!.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });

    if (mode == ImportMode.replaceAll) _entries.clear();
    for (final key in touched) {
      _entries[key] = working[key]!;
    }
    _changed();
    return ImportSummary(added: added, updated: updated, merged: merged, unchanged: unchanged);
  }

  void _changed() {
    _sortedCache = null;
    _statsCache = null;
    notifyListeners();
  }
}
