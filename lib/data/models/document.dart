import '../../core/file_types.dart';

/// A reference to a file on disk. The file itself is never copied; only its
/// path and a little metadata live in the database.
class Document {
  const Document({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.path,
    required this.extension,
    required this.size,
    required this.dateAdded,
    this.categoryId,
    this.lastOpened,
    this.tags = const [],
    this.notes = '',
    this.isFavorite = false,
  });

  /// 0 means "not saved yet".
  final int id;

  /// Name shown in the app. Renaming it never touches the real file.
  final String displayName;

  /// Real file name on disk (at the time of adding / relinking).
  final String fileName;
  final String path;
  final int? categoryId;

  /// Lower-case, without the dot ("pdf").
  final String extension;
  final int size;
  final DateTime dateAdded;
  final DateTime? lastOpened;
  final List<String> tags;
  final String notes;
  final bool isFavorite;

  FileKind get kind => kindOfExtension(extension);

  /// Everything searchable, lower-cased once so SQL only needs LIKE.
  String get searchText =>
      [displayName, fileName, path, tags.join(' '), notes].join('\n').toLowerCase();

  Document copyWith({
    String? displayName,
    String? fileName,
    String? path,
    int? categoryId,
    bool clearCategory = false,
    String? extension,
    int? size,
    DateTime? lastOpened,
    List<String>? tags,
    String? notes,
    bool? isFavorite,
  }) {
    return Document(
      id: id,
      displayName: displayName ?? this.displayName,
      fileName: fileName ?? this.fileName,
      path: path ?? this.path,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      extension: extension ?? this.extension,
      size: size ?? this.size,
      dateAdded: dateAdded,
      lastOpened: lastOpened ?? this.lastOpened,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory Document.fromMap(Map<String, Object?> m) {
    final rawTags = (m['tags'] as String?) ?? '';
    final lastOpened = m['last_opened'] as int?;
    return Document(
      id: m['id'] as int,
      displayName: m['display_name'] as String,
      fileName: m['file_name'] as String,
      path: m['path'] as String,
      categoryId: m['category_id'] as int?,
      extension: (m['extension'] as String?) ?? '',
      size: (m['size'] as num?)?.toInt() ?? 0,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(m['date_added'] as int),
      lastOpened: lastOpened == null ? null : DateTime.fromMillisecondsSinceEpoch(lastOpened),
      tags: rawTags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      notes: (m['notes'] as String?) ?? '',
      isFavorite: (m['is_favorite'] as int? ?? 0) == 1,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) => {
        if (includeId && id != 0) 'id': id,
        'display_name': displayName,
        'name_lower': displayName.toLowerCase(),
        'file_name': fileName,
        'path': path,
        'category_id': categoryId,
        'extension': extension,
        'size': size,
        'date_added': dateAdded.millisecondsSinceEpoch,
        'last_opened': lastOpened?.millisecondsSinceEpoch,
        'tags': tags.join(','),
        'notes': notes,
        'is_favorite': isFavorite ? 1 : 0,
        'search_text': searchText,
      };
}
