import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/category.dart';

class DuplicateNameException implements Exception {
  const DuplicateNameException();
}

class CategoryRepository {
  CategoryRepository(this._db);
  final Database _db;

  Future<List<CategoryWithCount>> withCounts() async {
    final rows = await _db.rawQuery('''
      SELECT c.*,
             (SELECT COUNT(*) FROM documents d WHERE d.category_id = c.id) AS doc_count
      FROM categories c
      ORDER BY c.name COLLATE NOCASE
    ''');
    return [
      for (final r in rows)
        CategoryWithCount(Category.fromMap(r), (r['doc_count'] as num).toInt()),
    ];
  }

  Future<void> insert(String name, int color, String icon) async {
    await _ensureUnique(name);
    await _db.insert('categories', {
      'name': name,
      'color': color,
      'icon': icon,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> update(int id, String name, int color, String icon) async {
    await _ensureUnique(name, exceptId: id);
    await _db.update(
      'categories',
      {'name': name, 'color': color, 'icon': icon},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Removes the category AND its document entries (never the files on disk).
  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      await txn.delete('documents', where: 'category_id = ?', whereArgs: [id]);
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> _ensureUnique(String name, {int? exceptId}) async {
    final rows = await _db.query(
      'categories',
      columns: ['id'],
      where: exceptId == null ? 'name = ? COLLATE NOCASE' : 'name = ? COLLATE NOCASE AND id != ?',
      whereArgs: exceptId == null ? [name] : [name, exceptId],
      limit: 1,
    );
    if (rows.isNotEmpty) throw const DuplicateNameException();
  }
}
