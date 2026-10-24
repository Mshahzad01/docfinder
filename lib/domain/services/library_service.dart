import 'dart:ui' show VoidCallback;

import '../../data/models/document.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/document_repository.dart';
import 'file_service.dart';

class AddResult {
  const AddResult({this.added = 0, this.duplicates = 0, this.failed = 0});
  final int added;
  final int duplicates;
  final int failed;
}

enum OpenOutcome { opened, missing, failed }

enum RelinkOutcome { ok, duplicate, failed }

/// Business logic: orchestrates repositories and the file system.
/// [onChanged] is called after every write so the UI can refresh.
class LibraryService {
  LibraryService({
    required this.documents,
    required this.categories,
    required this.files,
    required this.onChanged,
  });

  final DocumentRepository documents;
  final CategoryRepository categories;
  final FileService files;
  final VoidCallback onChanged;

  // ---------------------------------------------------------- documents

  Future<AddResult> addPaths(List<String> rawPaths, {int? categoryId}) async {
    final expanded = await files.expandPaths(rawPaths);

    final unique = <String, String>{};
    for (final path in expanded) {
      unique.putIfAbsent(files.pathKey(path), () => path);
    }
    var duplicates = expanded.length - unique.length;

    final existing = (await documents.existingPaths(unique.values.toList()))
        .map(files.pathKey)
        .toSet();

    final fresh = <Document>[];
    var failed = 0;
    for (final entry in unique.entries) {
      if (existing.contains(entry.key)) {
        duplicates++;
        continue;
      }
      final doc = await files.describe(entry.value, categoryId: categoryId);
      if (doc == null) {
        failed++;
      } else {
        fresh.add(doc);
      }
    }

    if (fresh.isNotEmpty) {
      await documents.insertAll(fresh);
      onChanged();
    }
    return AddResult(added: fresh.length, duplicates: duplicates, failed: failed);
  }

  Future<void> updateDocument(Document d) async {
    await documents.update(d);
    onChanged();
  }

  Future<OpenOutcome> open(Document d) async {
    if (!await files.exists(d.path)) return OpenOutcome.missing;
    if (!await files.openFile(d.path)) return OpenOutcome.failed;
    await documents.markOpened(d.id);
    onChanged();
    return OpenOutcome.opened;
  }

  Future<bool> reveal(Document d) => files.revealInFolder(d.path);

  Future<RelinkOutcome> relink(Document d, String newPath) async {
    final key = files.pathKey(newPath);
    if (key != files.pathKey(d.path)) {
      final taken = (await documents.existingPaths([newPath])).map(files.pathKey);
      if (taken.contains(key)) return RelinkOutcome.duplicate;
    }
    final fresh = await files.describe(newPath);
    if (fresh == null) return RelinkOutcome.failed;
    await documents.update(d.copyWith(
      path: newPath,
      fileName: fresh.fileName,
      extension: fresh.extension,
      size: fresh.size,
    ));
    onChanged();
    return RelinkOutcome.ok;
  }

  /// Removes entries only. Real files are never touched.
  Future<void> removeDocuments(List<int> ids) async {
    await documents.deleteMany(ids);
    onChanged();
  }

  Future<void> moveDocuments(List<int> ids, int? categoryId) async {
    await documents.moveToCategory(ids, categoryId);
    onChanged();
  }

  Future<void> setFavorite(List<int> ids, bool value) async {
    await documents.setFavorite(ids, value);
    onChanged();
  }

  // --------------------------------------------------------- categories

  Future<void> addCategory(String name, int color, String icon) async {
    await categories.insert(name, color, icon);
    onChanged();
  }

  Future<void> updateCategory(int id, String name, int color, String icon) async {
    await categories.update(id, name, color, icon);
    onChanged();
  }

  Future<void> deleteCategory(int id) async {
    await categories.delete(id);
    onChanged();
  }
}
