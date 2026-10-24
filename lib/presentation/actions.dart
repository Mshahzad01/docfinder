import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/category_style.dart';
import '../data/models/document.dart';
import '../domain/search_params.dart';
import '../domain/services/library_service.dart';
import 'providers/providers.dart';
import 'widgets/document_dialog.dart';

/// UI helpers that glue dialogs/snackbars to the [LibraryService].

void showMessage(BuildContext context, String text, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
}

// ---------------------------------------------------------------- adding
Future<void> addDocumentsFromPicker(BuildContext context, WidgetRef ref) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    dialogTitle: 'Select documents to add',
  );
  if (result == null || !context.mounted) return;
  await addPaths(context, ref, result.paths.whereType<String>().toList());
}

/// Adds files to the current category (asks for one when "All" is selected).
Future<void> addPaths(BuildContext context, WidgetRef ref, List<String> paths) async {
  if (paths.isEmpty) return;
  var target = ref.read(searchProvider).params.categoryId;
  if (target == null) {
    target = await pickCategory(context, ref, title: 'Add to which category?');
    if (target == null || !context.mounted) return;
  }
  final res = await ref
      .read(libraryServiceProvider)
      .addPaths(paths, categoryId: target == kUncategorized ? null : target);
  if (!context.mounted) return;

  final parts = <String>[];
  if (res.added > 0) parts.add('Added ${res.added} document${res.added == 1 ? '' : 's'}');
  if (res.duplicates > 0) parts.add('${res.duplicates} already added');
  if (res.failed > 0) parts.add('${res.failed} could not be read');
  showMessage(context, parts.isEmpty ? 'No files found to add' : parts.join(' · '));
}

/// Returns a category id, [kUncategorized], or null when cancelled.
Future<int?> pickCategory(BuildContext context, WidgetRef ref, {required String title}) {
  final cats = ref.read(libraryProvider).valueOrNull?.categories ?? const [];
  Widget option(BuildContext ctx, int id, IconData icon, Color? color, String label) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, id),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  return showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        for (final c in cats)
          option(ctx, c.category.id, iconForCategory(c.category.icon), Color(c.category.color),
              c.category.name),
        option(ctx, kUncategorized, Icons.folder_off_outlined, null, 'Uncategorized'),
      ],
    ),
  );
}

// ---------------------------------------------------------------- opening
Future<void> openDocument(BuildContext context, WidgetRef ref, Document doc) async {
  final outcome = await ref.read(libraryServiceProvider).open(doc);
  if (!context.mounted) return;
  switch (outcome) {
    case OpenOutcome.opened:
      break;
    case OpenOutcome.missing:
      showMessage(context, 'File not found. It may have been moved or deleted.',
          actionLabel: 'Relink', onAction: () => showDocumentDialog(context, doc));
    case OpenOutcome.failed:
      showMessage(context, 'Could not open the file. No default app may be installed for it.');
  }
}

Future<void> openFolder(BuildContext context, WidgetRef ref, Document doc) async {
  final ok = await ref.read(libraryServiceProvider).reveal(doc);
  if (!ok && context.mounted) showMessage(context, 'Could not open the folder.');
}

Future<void> copyPath(BuildContext context, Document doc) async {
  await Clipboard.setData(ClipboardData(text: doc.path));
  if (context.mounted) showMessage(context, 'Path copied');
}

// --------------------------------------------------------------- removing
Future<bool> removeDocuments(BuildContext context, WidgetRef ref, List<Document> docs) async {
  if (docs.isEmpty) return false;
  final single = docs.length == 1;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.link_off),
      title: Text(single ? 'Remove from DocVault?' : 'Remove ${docs.length} documents?'),
      content: Text(
        '${single ? '"${docs.first.displayName}"' : 'The selected documents'} will be removed from '
        'DocVault only.\n\nThe original file${single ? '' : 's'} on your disk will NOT be deleted.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove entry')),
      ],
    ),
  );
  if (ok != true) return false;
  await ref.read(libraryServiceProvider).removeDocuments(docs.map((d) => d.id).toList());
  if (context.mounted) {
    showMessage(context, single ? 'Entry removed' : '${docs.length} entries removed');
  }
  return true;
}

// ------------------------------------------------------------------ relink
Future<void> relinkDocument(BuildContext context, WidgetRef ref, Document doc,
    {void Function(Document updated)? onDone}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    dialogTitle: 'Locate "${doc.fileName}"',
  );
  final path = result?.paths.firstOrNull;
  if (path == null || !context.mounted) return;
  final outcome = await ref.read(libraryServiceProvider).relink(doc, path);
  if (!context.mounted) return;
  switch (outcome) {
    case RelinkOutcome.ok:
      showMessage(context, 'File relinked');
      onDone?.call(doc.copyWith(path: path));
    case RelinkOutcome.duplicate:
      showMessage(context, 'That file is already in DocVault.');
    case RelinkOutcome.failed:
      showMessage(context, 'Could not read that file.');
  }
}
