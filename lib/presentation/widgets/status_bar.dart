import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lib = ref.watch(libraryProvider).valueOrNull;
    final s = ref.watch(searchProvider);
    final checked = ref.watch(docSelectionProvider.select((x) => x.checked.length));
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    final filtered = s.params.isActive || s.params.categoryId != null;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Text(
            lib == null
                ? 'Loading…'
                : '${lib.total} document${lib.total == 1 ? '' : 's'} · '
                    '${lib.categories.length} categor${lib.categories.length == 1 ? 'y' : 'ies'}',
            style: style,
          ),
          if (filtered) Text('   |   Showing ${s.items.length} of ${s.total}', style: style),
          const Spacer(),
          if (checked > 0) Text('$checked selected   ', style: style),
          if (s.missingIds.isNotEmpty)
            Text('⚠ ${s.missingIds.length} missing file${s.missingIds.length == 1 ? '' : 's'}',
                style: style?.copyWith(color: scheme.error)),
        ],
      ),
    );
  }
}
