import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Owns the SQLite connection. The file lives in the OS "application support"
/// directory (Windows: %APPDATA%\<company>\<app>), never next to user files.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;
  static const int _version = 1;

  static Future<AppDatabase> open() async {
    sqfliteFfiInit();
    final dbFactory = databaseFactoryFfi;
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);

    final db = await dbFactory.openDatabase(
      p.join(dir.path, 'docvault.db'),
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.rawQuery('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
        },
        onCreate: _onCreate,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Windows / macOS file systems are case-insensitive, Linux is not.
    final collate = Platform.isLinux ? '' : 'COLLATE NOCASE';

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        color INTEGER NOT NULL,
        icon TEXT NOT NULL DEFAULT 'folder',
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        display_name TEXT NOT NULL,
        name_lower TEXT NOT NULL,
        file_name TEXT NOT NULL,
        path TEXT NOT NULL UNIQUE $collate,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        extension TEXT NOT NULL DEFAULT '',
        size INTEGER NOT NULL DEFAULT 0,
        date_added INTEGER NOT NULL,
        last_opened INTEGER,
        tags TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        search_text TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_docs_category ON documents(category_id)');
    await db.execute('CREATE INDEX idx_docs_added ON documents(date_added)');
    await db.execute('CREATE INDEX idx_docs_opened ON documents(last_opened)');
    await db.execute('CREATE INDEX idx_docs_ext ON documents(extension)');
    await db.execute('CREATE INDEX idx_docs_fav ON documents(is_favorite)');
    await db.execute('CREATE INDEX idx_docs_name ON documents(name_lower)');

    // Starter categories so the app is not empty on first launch.
    final now = DateTime.now().millisecondsSinceEpoch;
    const seeds = [
      ('CV', 0xFF3F51B5, 'badge'),
      ('Tenders', 0xFFFF9800, 'gavel'),
      ('Invoices', 0xFF4CAF50, 'receipt'),
      ('Contracts', 0xFF9C27B0, 'assignment'),
    ];
    for (final s in seeds) {
      await db.insert('categories', {
        'name': s.$1,
        'color': s.$2,
        'icon': s.$3,
        'created_at': now,
      });
    }
  }

  Future<void> close() => db.close();
}
