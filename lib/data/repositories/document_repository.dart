import 'dart:math' as math;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/file_types.dart';
import '../../domain/search_params.dart';
import '../models/document.dart';

/// All SQL for documents lives here, including the search query builder.
///
/// Search design: every document has a pre-lower-cased `search_text` column
/// (name + file name + path + tags + notes). Each typed word becomes one
/// `search_text LIKE '%word%'` clause, so partial matches ("mus" finds
/// "Muhammad") and multi-word queries work. Substring LIKE over a few
/// ten-thousand rows runs in a few milliseconds, which FTS5 can not match for
/// true substring search (FTS5 only does prefix matching on whole tokens).
class DocumentRepository {
  DocumentRepository(this._db);
  final Database _db;
  static const _table = 'documents';

  // ------------------------------------------------------------ queries

  Future<List<Document>> search(SearchParams q, {required int limit, int offset = 0}) async {
    final where = _buildWhere(q);
    final order = _buildOrder(q);
    final rows = await _db.rawQuery(
      'SELECT * FROM $_table${where.sql} ORDER BY ${order.sql} LIMIT ? OFFSET ?',
      [...where.args, ...order.args, limit, offset],
    );
    return rows.map(Document.fromMap).toList();
  }

  Future<int> count(SearchParams q) async {
    final where = _buildWhere(q);
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM $_table${where.sql}', where.args);
    return (rows.first['n'] as num).toInt();
  }

  Future<int> countAll() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM $_table');
    return (rows.first['n'] as num).toInt();
  }

  Future<int> countUncategorized() async {
    final rows =
        await _db.rawQuery('SELECT COUNT(*) AS n FROM $_table WHERE category_id IS NULL');
    return (rows.first['n'] as num).toInt();
  }

  /// Returns the stored paths (as saved) that already exist in the database.
  Future<Set<String>> existingPaths(List<String> paths) async {
    final found = <String>{};
    for (final chunk in _chunks(paths)) {
      final marks = List.filled(chunk.length, '?').join(',');
      final rows = await _db.rawQuery('SELECT path FROM $_table WHERE path IN ($marks)', chunk);
      found.addAll(rows.map((r) => r['path'] as String));
    }
    return found;
  }

  // ------------------------------------------------------------ writes

  Future<void> insertAll(List<Document> docs) async {
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final d in docs) {
        batch.insert(_table, d.toMap(includeId: false),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> update(Document d) => _db.update(
        _table,
        d.toMap(includeId: false),
        where: 'id = ?',
        whereArgs: [d.id],
      );

  Future<void> markOpened(int id) => _db.update(
        _table,
        {'last_opened': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> setFavorite(List<int> ids, bool value) =>
      _bulk(ids, 'UPDATE $_table SET is_favorite = ? WHERE id IN', [value ? 1 : 0]);

  Future<void> moveToCategory(List<int> ids, int? categoryId) =>
      _bulk(ids, 'UPDATE $_table SET category_id = ? WHERE id IN', [categoryId]);

  Future<void> deleteMany(List<int> ids) => _bulk(ids, 'DELETE FROM $_table WHERE id IN', []);

  Future<void> _bulk(List<int> ids, String sqlPrefix, List<Object?> leadingArgs) async {
    await _db.transaction((txn) async {
      for (final chunk in _chunks(ids)) {
        final marks = List.filled(chunk.length, '?').join(',');
        await txn.rawUpdate('$sqlPrefix ($marks)', [...leadingArgs, ...chunk]);
      }
    });
  }

  // ------------------------------------------------------------ builders

  ({String sql, List<Object?> args}) _buildWhere(SearchParams q) {
    final clauses = <String>[];
    final args = <Object?>[];

    final cat = q.categoryId;
    if (cat == kUncategorized) {
      clauses.add('category_id IS NULL');
    } else if (cat != null) {
      clauses.add('category_id = ?');
      args.add(cat);
    }

    for (final term in q.terms) {
      clauses.add("search_text LIKE ? ESCAPE '\\'");
      args.add('%${_escapeLike(term)}%');
    }

    if (q.kinds.isNotEmpty) {
      final exts = <String>[
        for (final k in q.kinds) ...?kKindExtensions[k],
      ];
      final parts = <String>[];
      if (exts.isNotEmpty) {
        parts.add('extension IN (${List.filled(exts.length, '?').join(',')})');
        args.addAll(exts);
      }
      if (q.kinds.contains(FileKind.other)) {
        final known = kKnownExtensions.toList();
        parts.add('extension NOT IN (${List.filled(known.length, '?').join(',')})');
        args.addAll(known);
      }
      clauses.add('(${parts.join(' OR ')})');
    }

    if (q.from != null) {
      final start = DateTime(q.from!.year, q.from!.month, q.from!.day);
      clauses.add('date_added >= ?');
      args.add(start.millisecondsSinceEpoch);
    }
    if (q.to != null) {
      final endExclusive = DateTime(q.to!.year, q.to!.month, q.to!.day + 1);
      clauses.add('date_added < ?');
      args.add(endExclusive.millisecondsSinceEpoch);
    }
    if (q.favoritesOnly) clauses.add('is_favorite = 1');

    return (
      sql: clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}',
      args: args,
    );
  }

  /// Favourites are always pinned on top, then the chosen sort applies.
  ({String sql, List<Object?> args}) _buildOrder(SearchParams q) {
    final dir = q.ascending ? 'ASC' : 'DESC';
    final args = <Object?>[];
    final String main;

    switch (q.sort) {
      case SortField.relevance:
        final terms = q.terms;
        if (terms.isEmpty) {
          main = 'date_added DESC';
        } else {
          // Words found in the display name rank above matches elsewhere.
          final score = terms.map((_) => '(instr(name_lower, ?) > 0)').join(' + ');
          args.addAll(terms);
          main = '($score) DESC, date_added DESC';
        }
      case SortField.name:
        main = 'name_lower $dir';
      case SortField.dateAdded:
        main = 'date_added $dir';
      case SortField.lastOpened:
        main = 'last_opened $dir';
      case SortField.size:
        main = 'size $dir';
    }
    return (sql: 'is_favorite DESC, $main, id DESC', args: args);
  }

  static String _escapeLike(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  static Iterable<List<T>> _chunks<T>(List<T> list, [int size = 500]) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, math.min(i + size, list.length));
    }
  }
}
