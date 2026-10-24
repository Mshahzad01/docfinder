import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_style.dart';
import '../../data/models/category.dart';
import '../../domain/search_params.dart';
import '../providers/providers.dart';
import 'category_dialog.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, this.onNavigate});

  /// Called after a category is chosen (used to close the drawer).
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lib = ref.watch(libraryProvider).valueOrNull;
    final selected = ref.watch(searchProvider.select((s) => s.params.categoryId));

    void select(int? id) {
      ref.read(searchProvider.notifier).setCategory(id);
      ref.read(docSelectionProvider.notifier).clear();
      onNavigate?.call();
    }

    return Material(
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(children: [
              Icon(Icons.inventory_2, color: scheme.primary, size: 28),
              const SizedBox(width: 10),
              Text('DocVault',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _NavTile(
                  icon: Icons.all_inbox,
                  color: scheme.primary,
                  label: 'All Documents',
                  count: lib?.total,
                  selected: selected == null,
                  onTap: () => select(null),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 0, 4),
                  child: Row(children: [
                    Expanded(
                      child: Text('CATEGORIES',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant, letterSpacing: 1)),
                    ),
                    IconButton(
                      tooltip: 'New category',
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () => showCategoryDialog(context),
                    ),
                  ]),
                ),
                for (final c in lib?.categories ?? const <CategoryWithCount>[])
                  _NavTile(
                    icon: iconForCategory(c.category.icon),
                    color: Color(c.category.color),
                    label: c.category.name,
                    count: c.count,
                    selected: selected == c.category.id,
                    onTap: () => select(c.category.id),
                    menu: PopupMenuButton<String>(
                      tooltip: 'Category options',
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_horiz, size: 18),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Rename / edit…')),
                        PopupMenuItem(value: 'delete', child: Text('Delete…')),
                      ],
                      onSelected: (v) {
                        if (v == 'edit') {
                          showCategoryDialog(context, existing: c.category);
                        } else {
                          confirmDeleteCategory(context, ref, c);
                        }
                      },
                    ),
                  ),
                if ((lib?.uncategorized ?? 0) > 0)
                  _NavTile(
                    icon: Icons.folder_off_outlined,
                    color: scheme.outline,
                    label: 'Uncategorized',
                    count: lib!.uncategorized,
                    selected: selected == kUncategorized,
                    onTap: () => select(kUncategorized),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.menu,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: scheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: color),
      title: Text(label, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (count != null)
          Text('$count', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        if (menu != null) menu!,
      ]),
      onTap: onTap,
    );
  }
}
