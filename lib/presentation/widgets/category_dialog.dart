import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_style.dart';
import '../../data/models/category.dart';
import '../../data/repositories/category_repository.dart';
import '../actions.dart';
import '../providers/providers.dart';

/// Add (existing == null) or edit a category.
Future<void> showCategoryDialog(BuildContext context, {Category? existing}) {
  return showDialog<void>(context: context, builder: (_) => _CategoryDialog(existing: existing));
}

Future<void> confirmDeleteCategory(BuildContext context, WidgetRef ref, CategoryWithCount c) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: Text('Delete "${c.category.name}"?'),
      content: Text(
        c.count == 0
            ? 'This category is empty.'
            : 'This category contains ${c.count} document${c.count == 1 ? '' : 's'}. '
                'Their entries will be removed from DocVault.\n\n'
                'Your actual files on disk are NOT deleted.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(libraryServiceProvider).deleteCategory(c.category.id);
  final search = ref.read(searchProvider.notifier);
  if (ref.read(searchProvider).params.categoryId == c.category.id) search.setCategory(null);
  if (context.mounted) showMessage(context, 'Category deleted');
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog({this.existing});
  final Category? existing;

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late int _color = widget.existing?.color ?? kCategoryColors.first;
  late String _icon = widget.existing?.icon ?? 'folder';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name');
      return;
    }
    final service = ref.read(libraryServiceProvider);
    try {
      if (widget.existing == null) {
        await service.addCategory(name, _color, _icon);
      } else {
        await service.updateCategory(widget.existing!.id, name, _color, _icon);
      }
      if (mounted) Navigator.pop(context);
    } on DuplicateNameException {
      setState(() => _error = 'A category with this name already exists');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.existing == null ? 'New category' : 'Edit category'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Name', errorText: _error),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              const Text('Color'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in kCategoryColors)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: c == _color ? Border.all(color: scheme.onSurface, width: 3) : null,
                      ),
                      child: c == _color
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              const Text('Icon'),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in kCategoryIcons.entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _icon = e.key),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: e.key == _icon ? scheme.primaryContainer : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(e.value, color: e.key == _icon ? Color(_color) : scheme.onSurfaceVariant),
                    ),
                  ),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
