import '../core/file_types.dart';

/// Pseudo category id meaning "documents without a category".
const int kUncategorized = 0;

enum SortField { relevance, name, dateAdded, lastOpened, size }

extension SortFieldLabel on SortField {
  String get label => switch (this) {
        SortField.relevance => 'Best match',
        SortField.name => 'Name',
        SortField.dateAdded => 'Date added',
        SortField.lastOpened => 'Last opened',
        SortField.size => 'File size',
      };
}

const Object _keep = Object();

/// Everything that defines a search: text, scope, filters and sorting.
class SearchParams {
  const SearchParams({
    this.query = '',
    this.categoryId,
    this.kinds = const <FileKind>{},
    this.from,
    this.to,
    this.favoritesOnly = false,
    this.sort = SortField.relevance,
    this.ascending = false,
  });

  final String query;

  /// null = all categories, [kUncategorized] = no category, else a category id.
  final int? categoryId;
  final Set<FileKind> kinds;
  final DateTime? from;
  final DateTime? to;
  final bool favoritesOnly;
  final SortField sort;
  final bool ascending;

  /// Lower-cased words; every word must match somewhere (AND).
  List<String> get terms =>
      query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  bool get hasFilters => kinds.isNotEmpty || from != null || to != null || favoritesOnly;
  bool get isActive => terms.isNotEmpty || hasFilters;

  SearchParams copyWith({
    String? query,
    Object? categoryId = _keep,
    Set<FileKind>? kinds,
    Object? from = _keep,
    Object? to = _keep,
    bool? favoritesOnly,
    SortField? sort,
    bool? ascending,
  }) {
    return SearchParams(
      query: query ?? this.query,
      categoryId: identical(categoryId, _keep) ? this.categoryId : categoryId as int?,
      kinds: kinds ?? this.kinds,
      from: identical(from, _keep) ? this.from : from as DateTime?,
      to: identical(to, _keep) ? this.to : to as DateTime?,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      sort: sort ?? this.sort,
      ascending: ascending ?? this.ascending,
    );
  }
}
