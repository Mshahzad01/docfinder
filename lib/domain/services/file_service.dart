import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/document.dart';

/// Everything that touches the real file system / OS shell.
class FileService {
  /// Key used to compare paths (Windows & macOS are case-insensitive).
  String pathKey(String path) => Platform.isLinux ? path : path.toLowerCase();

  Future<bool> exists(String path) => File(path).exists();

  /// Builds a (not yet saved) [Document] from a file on disk, or null if the
  /// path is not a readable file.
  Future<Document?> describe(String path, {int? categoryId}) async {
    try {
      final stat = await File(path).stat();
      if (stat.type != FileSystemEntityType.file) return null;
      final name = p.basename(path);
      return Document(
        id: 0,
        displayName: name,
        fileName: name,
        path: path,
        categoryId: categoryId,
        extension: p.extension(path).replaceFirst('.', '').toLowerCase(),
        size: stat.size,
        dateAdded: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Turns dropped/picked paths into a flat list of files. Folders are
  /// expanded recursively (capped so a drive root can not freeze the app).
  Future<List<String>> expandPaths(List<String> paths, {int maxFiles = 20000}) async {
    final result = <String>[];
    for (final raw in paths) {
      final path = p.normalize(p.absolute(raw));
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        final stream = Directory(path).list(recursive: true, followLinks: false).handleError((_) {});
        await for (final e in stream) {
          if (e is File) result.add(e.path);
          if (result.length >= maxFiles) return result;
        }
      } else if (type == FileSystemEntityType.file) {
        result.add(path);
      }
    }
    return result;
  }

  /// Opens the file in the system default application.
  Future<bool> openFile(String path) async {
    try {
      if (await launchUrl(Uri.file(path))) return true;
    } catch (_) {}
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [path], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.start('open', [path], mode: ProcessStartMode.detached);
      } else {
        await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens the containing folder and selects the file where the OS supports it.
  Future<bool> revealInFolder(String path) async {
    try {
      final fileExists = await File(path).exists();
      if (Platform.isWindows) {
        if (fileExists) {
          await Process.start('explorer.exe', ['/select,', path], mode: ProcessStartMode.detached);
        } else {
          await Process.start('explorer.exe', [p.dirname(path)], mode: ProcessStartMode.detached);
        }
      } else if (Platform.isMacOS) {
        await Process.start('open', fileExists ? ['-R', path] : [p.dirname(path)],
            mode: ProcessStartMode.detached);
      } else {
        await Process.start('xdg-open', [p.dirname(path)], mode: ProcessStartMode.detached);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
