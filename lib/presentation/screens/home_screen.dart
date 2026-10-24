import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/document.dart';
import '../actions.dart';
import '../providers/providers.dart';
import '../widgets/bulk_bar.dart';
import '../widgets/document_dialog.dart';
import '../widgets/documents_area.dart';
import '../widgets/search_header.dart';
import '../widgets/sidebar.dart';
import '../widgets/status_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _dragging = false;

  FocusNode get _searchFocus => ref.read(searchFocusProvider);
  FocusNode get _bodyFocus => ref.read(bodyFocusProvider);
  TextEditingController get _searchText => ref.read(searchTextControllerProvider);

  // ------------------------------------------------------------ shortcuts
  void _focusSearch() {
    _searchFocus.requestFocus();
    _searchText.selection = TextSelection(baseOffset: 0, extentOffset: _searchText.text.length);
  }

  List<Document> _targets() {
    final items = ref.read(searchProvider).items;
    final sel = ref.read(docSelectionProvider);
    if (sel.checked.isNotEmpty) return items.where((d) => sel.checked.contains(d.id)).toList();
    return items.where((d) => d.id == sel.focusedId).toList();
  }

  void _onEnter() {
    final items = ref.read(searchProvider).items;
    if (_searchFocus.hasFocus) {
      // Enter in the search box: jump to the first result.
      if (items.isEmpty) return;
      ref.read(docSelectionProvider.notifier).focus(items.first.id);
      _bodyFocus.requestFocus();
      return;
    }
    final focusedId = ref.read(docSelectionProvider).focusedId;
    final doc = items.where((d) => d.id == focusedId).firstOrNull;
    if (doc != null) openDocument(context, ref, doc);
  }

  void _onDelete() {
    if (_searchFocus.hasFocus) return;
    removeDocuments(context, ref, _targets()).then((done) {
      if (done) ref.read(docSelectionProvider.notifier).clear();
    });
  }

  void _onEscape() {
    if (_searchText.text.isNotEmpty) {
      _searchText.clear();
      ref.read(searchProvider.notifier).setQuery('');
    } else if (ref.read(docSelectionProvider).checked.isNotEmpty) {
      ref.read(docSelectionProvider.notifier).clear();
    } else {
      _bodyFocus.requestFocus();
    }
  }

  void _onArrow(int delta) {
    if (_searchFocus.hasFocus && delta < 0) return;
    if (_searchFocus.hasFocus) _bodyFocus.requestFocus();
    final ids = ref.read(searchProvider).items.map((d) => d.id).toList();
    ref.read(docSelectionProvider.notifier).moveFocus(ids, delta);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final scheme = Theme.of(context).colorScheme;

    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): _focusSearch,
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _focusSearch,
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
          addDocumentsFromPicker(context, ref),
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
          addDocumentsFromPicker(context, ref),
      const SingleActivator(LogicalKeyboardKey.enter): _onEnter,
      const SingleActivator(LogicalKeyboardKey.numpadEnter): _onEnter,
      const SingleActivator(LogicalKeyboardKey.delete): _onDelete,
      const SingleActivator(LogicalKeyboardKey.escape): _onEscape,
      const SingleActivator(LogicalKeyboardKey.arrowDown): () => _onArrow(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () => _onArrow(-1),
    };

    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(
        focusNode: _bodyFocus,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: wide
              ? null
              : Drawer(child: Sidebar(onNavigate: () => _scaffoldKey.currentState?.closeDrawer())),
          body: DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (detail) {
              setState(() => _dragging = false);
              addPaths(context, ref, detail.files.map((f) => f.path).toList());
            },
            child: Stack(children: [
              Row(children: [
                if (wide) const SizedBox(width: 272, child: Sidebar()),
                if (wide) VerticalDivider(width: 1, color: scheme.outlineVariant),
                Expanded(
                  child: Column(children: [
                    SearchHeader(
                      showMenuButton: !wide,
                      onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    const BulkBar(),
                    Expanded(
                      // Any click in the list returns keyboard focus to the body
                      // so Enter / Delete / arrows keep working.
                      child: Listener(
                        onPointerDown: (_) => _bodyFocus.requestFocus(),
                        child: const DocumentsArea(),
                      ),
                    ),
                    const StatusBar(),
                  ]),
                ),
              ]),
              if (_dragging) _DropOverlay(),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DropOverlay extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final catId = ref.watch(searchProvider.select((s) => s.params.categoryId));
    final name = catId == null ? null : ref.watch(libraryProvider).valueOrNull?.categoryById(catId)?.name;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: scheme.primary.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.primary, width: 2),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.file_download_outlined, size: 56, color: scheme.primary),
              const SizedBox(height: 8),
              Text(name == null ? 'Drop files to add them' : 'Drop files to add to "$name"',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
          ),
        ),
      ),
    );
  }
}
