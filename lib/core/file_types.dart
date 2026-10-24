import 'package:flutter/material.dart';

/// Broad file groups used for icons and the "file type" filter.
enum FileKind { pdf, word, excel, powerpoint, image, text, archive, other }

/// Extensions (lower-case, no dot) that belong to each kind.
const Map<FileKind, List<String>> kKindExtensions = {
  FileKind.pdf: ['pdf'],
  FileKind.word: ['doc', 'docx', 'dot', 'dotx', 'odt', 'rtf'],
  FileKind.excel: ['xls', 'xlsx', 'xlsm', 'csv', 'ods'],
  FileKind.powerpoint: ['ppt', 'pptx', 'odp'],
  FileKind.image: ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'svg', 'tif', 'tiff', 'heic'],
  FileKind.text: ['txt', 'md', 'log', 'json', 'xml'],
  FileKind.archive: ['zip', 'rar', '7z', 'tar', 'gz'],
  FileKind.other: [],
};

/// Every extension that has a dedicated kind (used for the "Other" filter).
final Set<String> kKnownExtensions = {
  for (final list in kKindExtensions.values) ...list,
};

FileKind kindOfExtension(String extension) {
  final ext = extension.toLowerCase();
  for (final entry in kKindExtensions.entries) {
    if (entry.value.contains(ext)) return entry.key;
  }
  return FileKind.other;
}

extension FileKindUi on FileKind {
  String get label => switch (this) {
        FileKind.pdf => 'PDF',
        FileKind.word => 'Word',
        FileKind.excel => 'Excel',
        FileKind.powerpoint => 'PowerPoint',
        FileKind.image => 'Images',
        FileKind.text => 'Text',
        FileKind.archive => 'Archives',
        FileKind.other => 'Other',
      };

  IconData get icon => switch (this) {
        FileKind.pdf => Icons.picture_as_pdf,
        FileKind.word => Icons.description,
        FileKind.excel => Icons.table_chart,
        FileKind.powerpoint => Icons.slideshow,
        FileKind.image => Icons.image,
        FileKind.text => Icons.article,
        FileKind.archive => Icons.folder_zip,
        FileKind.other => Icons.insert_drive_file,
      };

  Color get color => switch (this) {
        FileKind.pdf => const Color(0xFFE53935),
        FileKind.word => const Color(0xFF1E6FD9),
        FileKind.excel => const Color(0xFF2E9E5B),
        FileKind.powerpoint => const Color(0xFFEF6C00),
        FileKind.image => const Color(0xFF8E24AA),
        FileKind.text => const Color(0xFF546E7A),
        FileKind.archive => const Color(0xFF8D6E63),
        FileKind.other => const Color(0xFF78909C),
      };
}
