import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/search_params.dart';
import '../actions.dart';
import '../providers/providers.dart';

/// Appears when rows are ticked: move / favourite / remove in one go.
class BulkBar extends ConsumerWidget {
  const BulkBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = ref.watch(docSelectionProvider.select((s) => s.checked));
    if (checked.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final items = ref.watch(searchProvider.select((s) => s.items));
    final docs = items.where((d) => checked.contains(d.id)).toList();
    final ids = docs.map((d) => d.id).toList();
    final allFav = docs.isNotEmpty && docs.every((d) => d.isFavorite);
    final service = ref.read(libraryServiceProvider);

    return Material(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text('${docs.length} selected',
                style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer)),
            TextButton(
              onPressed: () => ref
                  .read(docSelectionProvider.notifier)
                  .selectAll(items.map((d) => d.id).toList()),
              child: const Text('Select all'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.drive_file_move_outline),
              label: const Text('Move to…'),
              onPressed: () async {
                final target = await pickCategory(context, ref, title: 'Move ${docs.length} to…');
                if (target == null) return;
                await service.moveDocuments(ids, target == kUncategorized ? null : target);
                ref.read(docSelectionProvider.notifier).clear();
                if (context.mounted) showMessage(context, 'Moved ${ids.length} document(s)');
              },
            ),
            TextButton.icon(
              icon: Icon(allFav ? Icons.star_outline : Icons.star),
              label: Text(allFav ? 'Unfavorite' : 'Favorite'),
              onPressed: () => service.setFavorite(ids, !allFav),
            ),
            TextButton.icon(
              icon: const Icon(Icons.link_off),
              label: const Text('Remove'),
              onPressed: () async {
                if (await removeDocuments(context, ref, docs)) {
                  ref.read(docSelectionProvider.notifier).clear();
                }
              },
            ),
            IconButton(
              tooltip: 'Clear selection',
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(docSelectionProvider.notifier).clear(),
            ),
          ],
        ),
      ),
    );
  }
}
