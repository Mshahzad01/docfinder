import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/file_types.dart';
import '../../data/models/document.dart';
import '../../domain/search_params.dart';
import '../actions.dart';
import '../providers/providers.dart';

Future<void> showDocumentDialog(BuildContext context, Document doc) {
  return showDialog<void>(context: context, builder: (_) => DocumentDialog(doc: doc));
}

/// Details + editing for one document, with Open / Open Folder / Copy Path.
class DocumentDialog extends ConsumerStatefulWidget {
  const DocumentDialog({super.key, required this.doc});
  final Document doc;

  @override
  ConsumerState<DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends ConsumerState<DocumentDialog> {
  late Document _doc = widget.doc;
  late final TextEditingController _name = TextEditingController(text: _doc.displayName);
  late final TextEditingController _notes = TextEditingController(text: _doc.notes);
  final _tagInput = TextEditingController();
  final _tagFocus = FocusNode();
  late final List<String> _tags = [..._doc.tags];
  late int _categoryId = _doc.categoryId ?? kUncategorized;
  late bool _favorite = _doc.isFavorite;
  bool? _exists;

  @override
  void initState() {
    super.initState();
    _checkExists();
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _tagInput.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  Future<void> _checkExists() async {
    final ok = await File(_doc.path).exists();
    if (mounted) setState(() => _exists = ok);
  }

  void _addTag(String raw) {
    final t = raw.replaceAll(',', ' ').trim();
    if (t.isNotEmpty && !_tags.any((x) => x.toLowerCase() == t.toLowerCase())) {
      setState(() => _tags.add(t));
    }
    _tagInput.clear();
    _tagFocus.requestFocus();
  }

  Future<void> _save() async {
    final pending = _tagInput.text.replaceAll(',', ' ').trim();
    if (pending.isNotEmpty && !_tags.any((x) => x.toLowerCase() == pending.toLowerCase())) {
      _tags.add(pending);
    }
    final name = _name.text.trim();
    final updated = _doc.copyWith(
      displayName: name.isEmpty ? _doc.fileName : name,
      categoryId: _categoryId == kUncategorized ? null : _categoryId,
      clearCategory: _categoryId == kUncategorized,
      tags: _tags,
      notes: _notes.text.trim(),
      isFavorite: _favorite,
    );
    await ref.read(libraryServiceProvider).updateDocument(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cats = ref.watch(libraryProvider).valueOrNull?.categories ?? const [];
    final kind = _doc.kind;

    Widget detail(String label, String value, {bool selectable = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 90,
                child: Text(label, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
            Expanded(child: selectable ? SelectableText(value) : Text(value)),
          ]),
        );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(kind.icon, color: kind.color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_doc.fileName,
                    style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: _favorite ? 'Remove from favorites' : 'Add to favorites',
                icon: Icon(_favorite ? Icons.star : Icons.star_outline,
                    color: _favorite ? Colors.amber : null),
                onPressed: () => setState(() => _favorite = !_favorite),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: 8),
            if (_exists == false)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('File missing: it was moved, renamed or deleted.',
                        style: TextStyle(color: scheme.onErrorContainer)),
                  ),
                  TextButton(
                    onPressed: () => relinkDocument(context, ref, _doc, onDone: (updated) {
                      setState(() => _doc = updated);
                      _checkExists();
                    }),
                    child: const Text('Relink…'),
                  ),
                ]),
              ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open File'),
                onPressed: () async {
                  await openDocument(context, ref, _doc);
                  _checkExists();
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Containing Folder'),
                onPressed: () => openFolder(context, ref, _doc),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy Path'),
                onPressed: () => copyPath(context, _doc),
              ),
            ]),
            const Divider(height: 28),
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  detail('Path', _doc.path, selectable: true),
                  detail('Size', formatBytes(_doc.size)),
                  detail('Type', _doc.extension.isEmpty ? 'Unknown' : _doc.extension.toUpperCase()),
                  detail('Added', formatDateTime(_doc.dateAdded)),
                  detail('Last opened',
                      _doc.lastOpened == null ? 'Never' : formatDateTime(_doc.lastOpened!)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      helperText: 'Only changes the name inside DocVault, not the real file.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownMenu<int>(
                    initialSelection: cats.any((c) => c.category.id == _categoryId)
                        ? _categoryId
                        : kUncategorized,
                    expandedInsets: EdgeInsets.zero,
                    label: const Text('Category'),
                    requestFocusOnTap: false,
                    dropdownMenuEntries: [
                      for (final c in cats)
                        DropdownMenuEntry(value: c.category.id, label: c.category.name),
                      const DropdownMenuEntry(value: kUncategorized, label: 'Uncategorized'),
                    ],
                    onSelected: (v) => setState(() => _categoryId = v ?? kUncategorized),
                  ),
                  const SizedBox(height: 16),
                  if (_tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final t in _tags)
                          InputChip(
                            label: Text(t),
                            onDeleted: () => setState(() => _tags.remove(t)),
                          ),
                      ]),
                    ),
                  TextField(
                    controller: _tagInput,
                    focusNode: _tagFocus,
                    decoration: const InputDecoration(
                      labelText: 'Add tag',
                      helperText: 'Press Enter or comma to add',
                      prefixIcon: Icon(Icons.sell_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      if (v.endsWith(',')) _addTag(v);
                    },
                    onSubmitted: _addTag,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notes,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.link_off),
                label: const Text('Remove from DocVault'),
                onPressed: () async {
                  if (await removeDocuments(context, ref, [_doc]) && context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ]),
          ]),
        ),
      ),
    );
  }
}
