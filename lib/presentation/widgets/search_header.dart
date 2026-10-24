import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/file_types.dart';
import '../../core/formatters.dart';
import '../../domain/search_params.dart';
import '../actions.dart';
import '../providers/providers.dart';

/// Big search box, "Add" button, theme toggle, filter chips, sort and view.
class SearchHeader extends ConsumerWidget {
  const SearchHeader({super.key, required this.showMenuButton, required this.onMenu});

  final bool showMenuButton;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final search = ref.read(searchProvider.notifier);
    final params = ref.watch(searchProvider.select((s) => s.params));
    final controller = ref.watch(searchTextControllerProvider);
    final focus = ref.watch(searchFocusProvider);
    final isGrid = ref.watch(viewModeProvider);
    final lib = ref.watch(libraryProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scopeName = params.categoryId == null
        ? null
        : params.categoryId == kUncategorized
            ? 'Uncategorized'
            : lib?.categoryById(params.categoryId)?.name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (showMenuButton)
            IconButton(tooltip: 'Categories', icon: const Icon(Icons.menu), onPressed: onMenu),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: true,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search name, path, tags, notes…   (Ctrl+F)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, v, __) => v.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Clear (Esc)',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            controller.clear();
                            search.setQuery('');
                          },
                        ),
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: search.setQuery,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Documents'),
            onPressed: () => addDocumentsFromPicker(context, ref),
          ),
          IconButton(
            tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref
                .read(themeModeProvider.notifier)
                .set(isDark ? ThemeMode.light : ThemeMode.dark),
          ),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (scopeName != null)
                InputChip(
                  avatar: const Icon(Icons.folder_outlined, size: 18),
                  label: Text('In: $scopeName'),
                  deleteButtonTooltipMessage: 'Search all categories',
                  onDeleted: () => search.setCategory(null),
                ),
              FilterChip(
                avatar: Icon(params.favoritesOnly ? Icons.star : Icons.star_outline,
                    size: 18, color: Colors.amber),
                label: const Text('Favorites'),
                showCheckmark: false,
                selected: params.favoritesOnly,
                onSelected: search.setFavoritesOnly,
              ),
              for (final k in FileKind.values)
                FilterChip(
                  label: Text(k.label),
                  selected: params.kinds.contains(k),
                  onSelected: (_) => search.toggleKind(k),
                ),
              InputChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(params.from == null || params.to == null
                    ? 'Any date'
                    : '${formatDate(params.from!)} – ${formatDate(params.to!)}'),
                onPressed: () => _pickRange(context, search, params),
                onDeleted: params.from == null ? null : () => search.setDateRange(null, null),
              ),
              if (params.hasFilters)
                TextButton(onPressed: search.clearFilters, child: const Text('Clear filters')),
            ]),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<SortField>(
            tooltip: 'Sort by',
            onSelected: search.setSort,
            itemBuilder: (_) => [
              for (final f in SortField.values)
                CheckedPopupMenuItem(value: f, checked: f == params.sort, child: Text(f.label)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sort, size: 20),
                const SizedBox(width: 6),
                Text(params.sort.label),
              ]),
            ),
          ),
          IconButton(
            tooltip: params.ascending ? 'Ascending' : 'Descending',
            icon: Icon(params.ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: params.sort == SortField.relevance ? null : search.toggleDirection,
          ),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.view_list), tooltip: 'List view'),
              ButtonSegment(value: true, icon: Icon(Icons.grid_view), tooltip: 'Grid view'),
            ],
            selected: {isGrid},
            onSelectionChanged: (s) => ref.read(viewModeProvider.notifier).set(s.first),
          ),
        ]),
      ]),
    );
  }

  Future<void> _pickRange(BuildContext context, SearchNotifier search, SearchParams p) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          p.from != null && p.to != null ? DateTimeRange(start: p.from!, end: p.to!) : null,
    );
    if (range != null) search.setDateRange(range.start, range.end);
  }
}
