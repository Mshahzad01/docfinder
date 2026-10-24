import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/file_types.dart';
import '../../data/database/app_database.dart';
import '../../data/models/category.dart';
import '../../data/models/document.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../domain/search_params.dart';
import '../../domain/services/file_service.dart';
import '../../domain/services/library_service.dart';
import '../../domain/services/settings_service.dart';

// ------------------------------------------------------------------ wiring
// Overridden in main() once the database and settings are ready.
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());
final settingsServiceProvider = Provider<SettingsService>((ref) => throw UnimplementedError());

final categoryRepositoryProvider =
    Provider((ref) => CategoryRepository(ref.watch(databaseProvider).db));
final documentRepositoryProvider =
    Provider((ref) => DocumentRepository(ref.watch(databaseProvider).db));
final fileServiceProvider = Provider((ref) => FileService());

/// Incremented after every write; providers watching it refresh themselves.
class DataVersion extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final dataVersionProvider = NotifierProvider<DataVersion, int>(DataVersion.new);

final libraryServiceProvider = Provider<LibraryService>((ref) => LibraryService(
      documents: ref.watch(documentRepositoryProvider),
      categories: ref.watch(categoryRepositoryProvider),
      files: ref.watch(fileServiceProvider),
      onChanged: () => ref.read(dataVersionProvider.notifier).bump(),
    ));

// ------------------------------------------------------------ UI singletons
final searchTextControllerProvider = Provider<TextEditingController>((ref) {
  final c = TextEditingController();
  ref.onDispose(c.dispose);
  return c;
});

final searchFocusProvider = Provider<FocusNode>((ref) {
  final f = FocusNode(debugLabel: 'search');
  ref.onDispose(f.dispose);
  return f;
});

/// Focus node of the main area; keeps keyboard shortcuts alive after clicks.
final bodyFocusProvider = Provider<FocusNode>((ref) {
  final f = FocusNode(debugLabel: 'body');
  ref.onDispose(f.dispose);
  return f;
});

// ----------------------------------------------------------------- settings
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(settingsServiceProvider).themeMode;
  void set(ThemeMode mode) {
    state = mode;
    ref.read(settingsServiceProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// true = grid view, false = list view.
class ViewModeNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsServiceProvider).gridView;
  void set(bool grid) {
    state = grid;
    ref.read(settingsServiceProvider).setGridView(grid);
  }
}

final viewModeProvider = NotifierProvider<ViewModeNotifier, bool>(ViewModeNotifier.new);

// ------------------------------------------------------------------ library
class LibraryData {
  const LibraryData({required this.categories, required this.uncategorized, required this.total});
  final List<CategoryWithCount> categories;
  final int uncategorized;
  final int total;

  Category? categoryById(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.category.id == id) return c.category;
    }
    return null;
  }
}

final libraryProvider = FutureProvider<LibraryData>((ref) async {
  ref.watch(dataVersionProvider);
  final cats = ref.watch(categoryRepositoryProvider);
  final docs = ref.watch(documentRepositoryProvider);
  final list = await cats.withCounts();
  final uncategorized = await docs.countUncategorized();
  final total = await docs.countAll();
  return LibraryData(categories: list, uncategorized: uncategorized, total: total);
});

// ------------------------------------------------------------------- search
class SearchState {
  const SearchState({
    this.params = const SearchParams(),
    this.items = const [],
    this.total = 0,
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.missingIds = const {},
    this.terms = const [],
  });

  final SearchParams params;
  final List<Document> items;
  final int total;
  final bool loading;
  final bool loadingMore;
  final Object? error;

  /// Ids whose file no longer exists on disk.
  final Set<int> missingIds;

  /// Words used by the currently displayed results (for highlighting).
  final List<String> terms;

  bool get hasMore => items.length < total;

  SearchState copyWith({
    SearchParams? params,
    List<Document>? items,
    int? total,
    bool? loading,
    bool? loadingMore,
    Object? error,
    bool clearError = false,
    Set<int>? missingIds,
    List<String>? terms,
  }) {
    return SearchState(
      params: params ?? this.params,
      items: items ?? this.items,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      missingIds: missingIds ?? this.missingIds,
      terms: terms ?? this.terms,
    );
  }
}

/// Live search with debounce, lazy paging and missing-file detection.
class SearchNotifier extends Notifier<SearchState> {
  static const int pageSize = 100;
  Timer? _debounce;
  int _token = 0; // invalidates in-flight requests

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    ref.listen<int>(dataVersionProvider, (_, __) => _reload(keepExtent: true));
    Future.microtask(_reload);
    return const SearchState();
  }

  // ---- user intents
  void setQuery(String q) {
    state = state.copyWith(params: state.params.copyWith(query: q));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _reload);
  }

  void setCategory(int? id) => _apply(state.params.copyWith(categoryId: id));

  void toggleKind(FileKind kind) {
    final next = {...state.params.kinds};
    if (!next.remove(kind)) next.add(kind);
    _apply(state.params.copyWith(kinds: next));
  }

  void setFavoritesOnly(bool v) => _apply(state.params.copyWith(favoritesOnly: v));

  void setDateRange(DateTime? from, DateTime? to) =>
      _apply(state.params.copyWith(from: from, to: to));

  void setSort(SortField field) =>
      _apply(state.params.copyWith(sort: field, ascending: field == SortField.name));

  void toggleDirection() => _apply(state.params.copyWith(ascending: !state.params.ascending));

  void clearFilters() => _apply(state.params.copyWith(
        kinds: const <FileKind>{},
        from: null,
        to: null,
        favoritesOnly: false,
      ));

  void clearAll() => _apply(state.params.copyWith(
        query: '',
        kinds: const <FileKind>{},
        from: null,
        to: null,
        favoritesOnly: false,
      ));

  void refresh() => _reload(keepExtent: true);

  void _apply(SearchParams p) {
    _debounce?.cancel();
    state = state.copyWith(params: p);
    _reload();
  }

  // ---- loading
  Future<void> _reload({bool keepExtent = false}) async {
    final token = ++_token;
    final params = state.params;
    final limit = keepExtent ? math.max(pageSize, state.items.length) : pageSize;
    final repo = ref.read(documentRepositoryProvider);
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await repo.search(params, limit: limit);
      final total = await repo.count(params);
      if (token != _token) return;
      state = state.copyWith(
        items: items,
        total: total,
        loading: false,
        loadingMore: false,
        terms: params.terms,
      );
      unawaited(_checkMissing(items, token, merge: false));
    } catch (e) {
      if (token != _token) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore || state.error != null) return;
    final token = _token;
    state = state.copyWith(loadingMore: true);
    try {
      final more = await ref
          .read(documentRepositoryProvider)
          .search(state.params, limit: pageSize, offset: state.items.length);
      if (token != _token) return;
      final items = [...state.items, ...more];
      state = state.copyWith(
        items: items,
        loadingMore: false,
        total: more.isEmpty ? items.length : state.total,
      );
      unawaited(_checkMissing(more, token, merge: true));
    } catch (e) {
      if (token != _token) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }

  /// Checks (in small parallel batches) which files vanished from disk.
  Future<void> _checkMissing(List<Document> items, int token, {required bool merge}) async {
    final missing = <int>{};
    for (var i = 0; i < items.length; i += 32) {
      final chunk = items.skip(i).take(32);
      final res = await Future.wait(chunk.map((d) async {
        return await File(d.path).exists() ? null : d.id;
      }));
      missing.addAll(res.whereType<int>());
      if (token != _token) return;
    }
    state = state.copyWith(missingIds: merge ? {...state.missingIds, ...missing} : missing);
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);

// ---------------------------------------------------------------- selection
class DocSelection {
  const DocSelection({this.focusedId, this.checked = const {}});

  /// Row highlighted for keyboard actions (Enter / Delete).
  final int? focusedId;

  /// Rows ticked for bulk actions.
  final Set<int> checked;

  DocSelection copyWith({int? focusedId, bool clearFocus = false, Set<int>? checked}) =>
      DocSelection(
        focusedId: clearFocus ? null : (focusedId ?? this.focusedId),
        checked: checked ?? this.checked,
      );
}

class DocSelectionNotifier extends Notifier<DocSelection> {
  @override
  DocSelection build() {
    // Drop selections that are no longer in the result list.
    ref.listen<List<Document>>(searchProvider.select((s) => s.items), (_, items) {
      final ids = items.map((d) => d.id).toSet();
      final checked = state.checked.where(ids.contains).toSet();
      final focusGone = state.focusedId != null && !ids.contains(state.focusedId);
      if (checked.length != state.checked.length || focusGone) {
        state = state.copyWith(checked: checked, clearFocus: focusGone);
      }
    });
    return const DocSelection();
  }

  void focus(int id) => state = state.copyWith(focusedId: id);

  void toggleChecked(int id) {
    final next = {...state.checked};
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(focusedId: id, checked: next);
  }

  void selectRange(List<int> orderedIds, int toId) {
    final anchor = state.focusedId ?? toId;
    final a = orderedIds.indexOf(anchor);
    final b = orderedIds.indexOf(toId);
    if (a < 0 || b < 0) return;
    final range = orderedIds.sublist(math.min(a, b), math.max(a, b) + 1);
    state = state.copyWith(checked: {...state.checked, ...range});
  }

  void selectAll(List<int> ids) => state = state.copyWith(checked: ids.toSet());

  void moveFocus(List<int> orderedIds, int delta) {
    if (orderedIds.isEmpty) return;
    final current = state.focusedId == null ? -1 : orderedIds.indexOf(state.focusedId!);
    final next = current < 0
        ? (delta > 0 ? 0 : orderedIds.length - 1)
        : (current + delta).clamp(0, orderedIds.length - 1);
    state = state.copyWith(focusedId: orderedIds[next]);
  }

  void clear() => state = state.copyWith(checked: const {});
}

final docSelectionProvider =
    NotifierProvider<DocSelectionNotifier, DocSelection>(DocSelectionNotifier.new);
