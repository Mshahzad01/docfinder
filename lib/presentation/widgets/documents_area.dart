import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../actions.dart';
import '../providers/providers.dart';
import 'document_tile.dart';
import 'empty_state.dart';

/// The scrolling result list/grid with lazy loading and all empty states.
class DocumentsArea extends ConsumerStatefulWidget {
  const DocumentsArea({super.key});

  @override
  ConsumerState<DocumentsArea> createState() => _DocumentsAreaState();
}

class _DocumentsAreaState extends ConsumerState<DocumentsArea> {
  static const double _rowHeight = 76;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        ref.read(searchProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the keyboard-focused row visible (list view only).
  void _ensureVisible(int? id) {
    if (id == null || ref.read(viewModeProvider) || !_scroll.hasClients) return;
    final index = ref.read(searchProvider).items.indexWhere((d) => d.id == id);
    if (index < 0) return;
    final top = index * _rowHeight;
    final pos = _scroll.position;
    if (top < pos.pixels) {
      _scroll.jumpTo(top);
    } else if (top + _rowHeight > pos.pixels + pos.viewportDimension) {
      _scroll.jumpTo(top + _rowHeight - pos.viewportDimension);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(searchProvider);
    final sel = ref.watch(docSelectionProvider);
    final grid = ref.watch(viewModeProvider);
    final lib = ref.watch(libraryProvider).valueOrNull;
    final search = ref.read(searchProvider.notifier);

    ref.listen(docSelectionProvider.select((x) => x.focusedId), (_, id) => _ensureVisible(id));
    // Jump back to the top whenever the query/filters/sort change.
    ref.listen(searchProvider.select((x) => x.params), (_, __) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });

    if (s.error != null && s.items.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: '${s.error}',
        actionLabel: 'Try again',
        onAction: search.refresh,
      );
    }

    if (s.items.isEmpty) {
      if (s.loading) return const Center(child: CircularProgressIndicator());
      if (s.params.isActive) {
        return EmptyState(
          icon: Icons.search_off,
          title: 'No results found',
          message: 'Nothing matches your search or filters. Try fewer words, a different spelling, '
              'or search in all categories.',
          actionLabel: 'Clear search & filters',
          onAction: () {
            ref.read(searchTextControllerProvider).clear();
            search.clearAll();
          },
        );
      }
      final inCategory = s.params.categoryId != null;
      return EmptyState(
        icon: Icons.folder_open,
        title: inCategory ? 'No documents in this category' : 'Your vault is empty',
        message: 'Click "Add Documents" or drag files and folders into this window. '
            'DocVault only stores their location, never a copy.',
        actionLabel: 'Add Documents',
        onAction: () => addDocumentsFromPicker(context, ref),
      );
    }

    final ids = s.items.map((d) => d.id).toList();
    final itemCount = s.items.length + (s.hasMore ? 1 : 0);
    const loader = Center(
      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
    );

    final Widget content = grid
        ? GridView.builder(
            key: const ValueKey('grid'),
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 190,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: itemCount,
            itemBuilder: (context, i) {
              if (i >= s.items.length) return loader;
              final d = s.items[i];
              return DocumentCard(
                doc: d,
                terms: s.terms,
                focused: sel.focusedId == d.id,
                checked: sel.checked.contains(d.id),
                missing: s.missingIds.contains(d.id),
                orderedIds: ids,
              );
            },
          )
        : ListView.builder(
            key: const ValueKey('list'),
            controller: _scroll,
            itemExtent: _rowHeight,
            itemCount: itemCount,
            itemBuilder: (context, i) {
              if (i >= s.items.length) return loader;
              final d = s.items[i];
              return DocumentTile(
                doc: d,
                terms: s.terms,
                focused: sel.focusedId == d.id,
                checked: sel.checked.contains(d.id),
                missing: s.missingIds.contains(d.id),
                category: lib?.categoryById(d.categoryId),
                orderedIds: ids,
              );
            },
          );

    return Stack(children: [
      Positioned.fill(child: Scrollbar(controller: _scroll, child: content)),
      if (s.loading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
    ]);
  }
}
