import 'package:docfinder/core/file_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/models/category.dart';
import '../../data/models/document.dart';
import '../actions.dart';
import '../providers/providers.dart';
import 'document_dialog.dart';
import 'highlighted_text.dart';

int? _lastTapId;
DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);

/// Click = focus row, Ctrl/Cmd+click = tick, Shift+click = tick range,
/// double click = details dialog (own detection so single clicks stay instant).
void handleDocTap(BuildContext context, WidgetRef ref, Document doc, List<int> orderedIds) {
  final kb = HardwareKeyboard.instance;
  final sel = ref.read(docSelectionProvider.notifier);
  if (kb.isControlPressed || kb.isMetaPressed) {
    sel.toggleChecked(doc.id);
    return;
  }
  if (kb.isShiftPressed) {
    sel.selectRange(orderedIds, doc.id);
    return;
  }
  final now = DateTime.now();
  final isDouble =
      _lastTapId == doc.id && now.difference(_lastTapAt) < const Duration(milliseconds: 350);
  _lastTapId = doc.id;
  _lastTapAt = now;
  sel.focus(doc.id);
  if (isDouble) {
    _lastTapId = null;
    showDocumentDialog(context, doc);
  }
}

Future<void> showDocContextMenu(
    BuildContext context, WidgetRef ref, Document doc, Offset position) async {
  final choice = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
    items: [
      const PopupMenuItem(value: 'open', child: Text('Open file')),
      const PopupMenuItem(value: 'folder', child: Text('Open containing folder')),
      const PopupMenuItem(value: 'copy', child: Text('Copy path')),
      const PopupMenuItem(value: 'details', child: Text('Details / edit…')),
      PopupMenuItem(value: 'fav', child: Text(doc.isFavorite ? 'Remove from favorites' : 'Add to favorites')),
      const PopupMenuItem(value: 'remove', child: Text('Remove entry…')),
    ],
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'open':
      await openDocument(context, ref, doc);
    case 'folder':
      await openFolder(context, ref, doc);
    case 'copy':
      await copyPath(context, doc);
    case 'details':
      await showDocumentDialog(context, doc);
    case 'fav':
      await ref.read(libraryServiceProvider).setFavorite([doc.id], !doc.isFavorite);
    case 'remove':
      await removeDocuments(context, ref, [doc]);
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.doc, required this.missing, this.size = 40});
  final Document doc;
  final bool missing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final kind = doc.kind;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: kind.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(kind.icon, color: kind.color, size: size * 0.55),
        ),
        if (missing)
          Positioned(
            right: -4,
            bottom: -4,
            child: Icon(Icons.warning_amber_rounded,
                size: 18, color: Theme.of(context).colorScheme.error),
          ),
      ]),
    );
  }
}

class _MissingBadge extends StatelessWidget {
  const _MissingBadge();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: s.errorContainer, borderRadius: BorderRadius.circular(6)),
      child: Text('File missing',
          style: TextStyle(fontSize: 11, color: s.onErrorContainer, fontWeight: FontWeight.w600)),
    );
  }
}

/// One row of the list view (fixed height: 76).
class DocumentTile extends ConsumerWidget {
  const DocumentTile({
    super.key,
    required this.doc,
    required this.terms,
    required this.focused,
    required this.checked,
    required this.missing,
    required this.category,
    required this.orderedIds,
  });

  final Document doc;
  final List<String> terms;
  final bool focused;
  final bool checked;
  final bool missing;
  final Category? category;
  final List<int> orderedIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final bg = checked
        ? scheme.primaryContainer.withValues(alpha: 0.55)
        : focused
            ? scheme.secondaryContainer.withValues(alpha: 0.6)
            : Colors.transparent;

    final extra = [
      if (doc.tags.isNotEmpty) doc.tags.map((t) => '#$t').join(' '),
      if (doc.notes.trim().isNotEmpty) doc.notes.trim().split('\n').first,
    ].join('   ');

    return LayoutBuilder(builder: (context, c) {
      final showCategory = c.maxWidth > 780 && category != null;
      final showMeta = c.maxWidth > 560;
      return Material(
        color: bg,
        child: InkWell(
          onTap: () => handleDocTap(context, ref, doc, orderedIds),
          onSecondaryTapUp: (d) {
            ref.read(docSelectionProvider.notifier).focus(doc.id);
            showDocContextMenu(context, ref, doc, d.globalPosition);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Checkbox(
                value: checked,
                onChanged: (_) => ref.read(docSelectionProvider.notifier).toggleChecked(doc.id),
              ),
              const SizedBox(width: 6),
              _FileIcon(doc: doc, missing: missing),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: HighlightedText(doc.displayName,
                            terms: terms,
                            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      if (doc.isFavorite)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.star, size: 16, color: Colors.amber),
                        ),
                      if (missing) const _MissingBadge(),
                    ]),
                    HighlightedText(doc.path, terms: terms, style: muted),
                    if (extra.isNotEmpty) HighlightedText(extra, terms: terms, style: muted),
                  ],
                ),
              ),
              if (showCategory)
                SizedBox(
                  width: 130,
                  child: Row(children: [
                    Icon(Icons.circle, size: 10, color: Color(category!.color)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(category!.name, overflow: TextOverflow.ellipsis, style: muted)),
                  ]),
                ),
              if (showMeta) ...[
                SizedBox(
                    width: 64,
                    child: Text(formatBytes(doc.size), textAlign: TextAlign.right, style: muted)),
                SizedBox(
                    width: 100,
                    child: Text(formatDate(doc.dateAdded), textAlign: TextAlign.right, style: muted)),
              ],
              IconButton(
                tooltip: doc.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                icon: Icon(doc.isFavorite ? Icons.star : Icons.star_outline,
                    color: doc.isFavorite ? Colors.amber : null),
                onPressed: () =>
                    ref.read(libraryServiceProvider).setFavorite([doc.id], !doc.isFavorite),
              ),
              IconButton(
                tooltip: 'Open file',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => openDocument(context, ref, doc),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

/// One card of the grid view.
class DocumentCard extends ConsumerWidget {
  const DocumentCard({
    super.key,
    required this.doc,
    required this.terms,
    required this.focused,
    required this.checked,
    required this.missing,
    required this.orderedIds,
  });

  final Document doc;
  final List<String> terms;
  final bool focused;
  final bool checked;
  final bool missing;
  final List<int> orderedIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final muted =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final color = checked
        ? scheme.primaryContainer
        : focused
            ? scheme.secondaryContainer
            : scheme.surfaceContainerLow;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => handleDocTap(context, ref, doc, orderedIds),
        onSecondaryTapUp: (d) {
          ref.read(docSelectionProvider.notifier).focus(doc.id);
          showDocContextMenu(context, ref, doc, d.globalPosition);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: checked,
                  onChanged: (_) => ref.read(docSelectionProvider.notifier).toggleChecked(doc.id),
                ),
              ),
              const Spacer(),
              if (doc.isFavorite) const Icon(Icons.star, size: 18, color: Colors.amber),
            ]),
            Center(child: _FileIcon(doc: doc, missing: missing, size: 52)),
            const SizedBox(height: 10),
            HighlightedText(doc.displayName,
                terms: terms,
                maxLines: 2,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            if (missing)
              Text('File missing',
                  style: muted?.copyWith(color: scheme.error, fontWeight: FontWeight.w600))
            else
              Text('${formatBytes(doc.size)} · ${formatDate(doc.dateAdded)}',
                  style: muted, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}
