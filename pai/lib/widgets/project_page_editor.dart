import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../models/document_bookmark.dart';
import '../services/document_markdown_shortcuts.dart';
import '../services/document_selection_wrap.dart';
import '../services/project_document_content_codec.dart';
import '../theme/app_theme.dart';

typedef BookmarkCreateCallback =
    Future<void> Function(String label, String anchor, String? note);

enum ProjectPageStorageFormat { richTextJson, markdown }

class ProjectPageEditor extends StatefulWidget {
  const ProjectPageEditor({
    super.key,
    required this.pageId,
    required this.pageTitle,
    required this.contentController,
    required this.contentFocusNode,
    required this.bookmarks,
    required this.hasChanges,
    required this.pageKindLabel,
    required this.metaLabels,
    required this.onCreatePage,
    required this.onPageDraftChanged,
    required this.onSavePage,
    required this.onBookmarkCreated,
    this.compactDesktop = false,
    this.storageFormat = ProjectPageStorageFormat.richTextJson,
    this.onRenamePage,
    this.onDuplicatePage,
    this.onDeletePage,
    this.onTogglePinned,
    this.isPinned = false,
  });

  final String pageId;
  final String pageTitle;
  final TextEditingController contentController;
  final FocusNode contentFocusNode;
  final List<DocumentBookmark> bookmarks;
  final bool hasChanges;
  final String pageKindLabel;
  final List<String> metaLabels;
  final VoidCallback onCreatePage;
  final VoidCallback onPageDraftChanged;
  final VoidCallback onSavePage;
  final BookmarkCreateCallback onBookmarkCreated;
  final bool compactDesktop;
  final ProjectPageStorageFormat storageFormat;
  final VoidCallback? onRenamePage;
  final VoidCallback? onDuplicatePage;
  final VoidCallback? onDeletePage;
  final VoidCallback? onTogglePinned;
  final bool isPinned;

  @override
  State<ProjectPageEditor> createState() => _ProjectPageEditorState();
}

class _ProjectPageEditorState extends State<ProjectPageEditor> {
  final ScrollController _scrollController = ScrollController();
  quill.QuillController? _editorController;
  StreamSubscription<dynamic>? _documentChangeSubscription;
  String? _loadedPageId;
  String _loadedRawContent = '';
  bool _isApplyingEditorTransform = false;
  PendingListShortcutRevert? _pendingListShortcutRevert;

  quill.QuillController? get _controller => _editorController;

  @override
  void initState() {
    super.initState();
    _loadEditorDocument(force: true);
  }

  @override
  void didUpdateWidget(covariant ProjectPageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pageChanged =
        oldWidget.pageId != widget.pageId ||
        oldWidget.contentController.text != widget.contentController.text;
    if (pageChanged) {
      _loadEditorDocument(force: true);
    }
  }

  @override
  void dispose() {
    _documentChangeSubscription?.cancel();
    _editorController?.removeListener(_handleEditorStateChanged);
    _editorController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadEditorDocument({required bool force}) {
    final rawContent = widget.contentController.text;
    if (!force &&
        widget.pageId == _loadedPageId &&
        rawContent == _loadedRawContent) {
      return;
    }

    _documentChangeSubscription?.cancel();
    _editorController?.removeListener(_handleEditorStateChanged);
    _editorController?.dispose();

    final document = ProjectDocumentContentCodec.decode(rawContent);
    final controller = quill.QuillController(
      document: document,
      selection: TextSelection.collapsed(
        offset: math.max(0, document.length - 1),
      ),
      readOnly: false,
    );
    _pendingListShortcutRevert = null;
    controller.onReplaceText = (index, len, data) {
      if (_isApplyingEditorTransform) {
        return true;
      }

      final listShortcut = applyMarkdownListShortcut(
        controller: controller,
        index: index,
        len: len,
        data: data,
      );
      if (listShortcut != null) {
        _pendingListShortcutRevert = listShortcut;
        return false;
      }

      final handledSelectionWrap = applySelectionWrapEdit(
        controller: controller,
        index: index,
        len: len,
        data: data,
        replaceText:
            (
              int nextIndex,
              int nextLen,
              Object? nextData,
              TextSelection? nextSelection,
            ) {
              _isApplyingEditorTransform = true;
              try {
                controller.replaceText(
                  nextIndex,
                  nextLen,
                  nextData,
                  nextSelection,
                );
              } finally {
                _isApplyingEditorTransform = false;
              }
            },
      );
      if (handledSelectionWrap) {
        _pendingListShortcutRevert = null;
        return false;
      }

      _pendingListShortcutRevert = null;
      return true;
    };
    controller.addListener(_handleEditorStateChanged);
    _documentChangeSubscription = controller.document.changes.listen((_) {
      _syncEditorDocumentToController();
    });

    _editorController = controller;
    _loadedPageId = widget.pageId;
    _loadedRawContent = rawContent;
    if (mounted) {
      setState(() {});
    }
  }

  void _handleEditorStateChanged() {
    final pendingListShortcutRevert = _pendingListShortcutRevert;
    final controller = _controller;
    if (pendingListShortcutRevert != null &&
        controller != null &&
        (controller.selection.baseOffset !=
                pendingListShortcutRevert.lineStart ||
            !controller.selection.isCollapsed)) {
      _pendingListShortcutRevert = null;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _syncEditorDocumentToController() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final encoded = switch (widget.storageFormat) {
      ProjectPageStorageFormat.richTextJson =>
        ProjectDocumentContentCodec.encode(controller.document),
      ProjectPageStorageFormat.markdown =>
        ProjectDocumentContentCodec.toMarkdown(controller.document),
    };
    if (widget.contentController.text == encoded) {
      return;
    }

    widget.contentController.value = TextEditingValue(
      text: encoded,
      selection: TextSelection.collapsed(offset: encoded.length),
    );
    _loadedRawContent = encoded;
    widget.onPageDraftChanged();
  }

  void _handleFileMenuSelection(String action) {
    switch (action) {
      case 'new':
        widget.onCreatePage();
        return;
      case 'rename':
        widget.onRenamePage?.call();
        return;
      case 'duplicate':
        widget.onDuplicatePage?.call();
        return;
      case 'delete':
        widget.onDeletePage?.call();
        return;
    }
  }

  void _handleInsertMenuSelection(String action) {
    switch (action) {
      case 'heading':
        _applyLineAttribute(quill.Attribute.h1);
        return;
      case 'subheading':
        _applyLineAttribute(quill.Attribute.h2);
        return;
      case 'bullet':
        _applyLineAttribute(quill.Attribute.ul);
        return;
      case 'numbered':
        _applyLineAttribute(quill.Attribute.ol);
        return;
      case 'quote':
        _applyLineAttribute(quill.Attribute.blockQuote);
        return;
      case 'divider':
        final controller = _controller;
        if (controller == null) {
          return;
        }
        final selection = controller.selection;
        final insertIndex = math.max(0, selection.end);
        controller.replaceText(
          insertIndex,
          selection.isValid ? selection.end - selection.start : 0,
          '\n---\n',
          TextSelection.collapsed(offset: insertIndex + 5),
        );
        _focusEditor();
        return;
    }
  }

  void _handleBookmarkMenuSelection(String action) {
    if (action == 'new') {
      unawaited(_createBookmark());
      return;
    }

    if (!action.startsWith('bookmark:')) {
      return;
    }

    final bookmarkId = action.substring(9);
    for (final bookmark in widget.bookmarks) {
      if (bookmark.id == bookmarkId) {
        _jumpToBookmark(bookmark);
        return;
      }
    }
  }

  void _applyLineAttribute(quill.Attribute<dynamic> attribute) {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    controller.formatSelection(attribute);
    _focusEditor();
  }

  void _toggleInlineAttribute(quill.Attribute<dynamic> attribute) {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final attributes = controller.getSelectionStyle().attributes;
    final enabled = attributes.containsKey(attribute.key);
    controller.formatSelection(
      enabled ? quill.Attribute.clone(attribute, null) : attribute,
    );
    _focusEditor();
  }

  Future<void> _addLink() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final selection = controller.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final textController = TextEditingController(
      text: hasSelection ? _selectedPlainText().trim() : '',
    );
    final urlController = TextEditingController();

    final result = await showDialog<_LinkDraft>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasSelection)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'Link text',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final url = urlController.text.trim();
                final label = textController.text.trim();
                if (url.isEmpty || (!hasSelection && label.isEmpty)) {
                  return;
                }

                Navigator.of(context).pop(_LinkDraft(text: label, url: url));
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    textController.dispose();
    urlController.dispose();

    if (result == null) {
      return;
    }

    final start = math.max(0, selection.start);
    var length = math.max(0, selection.end - selection.start);
    if (!hasSelection) {
      controller.replaceText(
        start,
        0,
        result.text,
        TextSelection.collapsed(offset: start + result.text.length),
      );
      controller.updateSelection(
        TextSelection(
          baseOffset: start,
          extentOffset: start + result.text.length,
        ),
        quill.ChangeSource.local,
      );
      length = result.text.length;
    }

    controller.formatText(
      start,
      length,
      quill.Attribute.fromKeyValue('link', result.url),
    );
    _focusEditor();
  }

  Future<void> _createBookmark() async {
    final suggestedAnchor = _bookmarkAnchorSuggestion();
    final draft = await showDialog<_BookmarkDraft>(
      context: context,
      builder: (context) {
        return _BookmarkDialog(
          initialAnchor: suggestedAnchor,
          initialLabel: suggestedAnchor,
        );
      },
    );
    if (draft == null) {
      return;
    }

    await widget.onBookmarkCreated(draft.label, draft.anchor, draft.note);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bookmark added.')));
  }

  String _bookmarkAnchorSuggestion() {
    final selectedText = _selectedPlainText().trim();
    if (selectedText.isNotEmpty) {
      return selectedText.replaceAll('\n', ' ');
    }

    final controller = _controller;
    if (controller == null) {
      return '';
    }

    final plainText = controller.document.toPlainText();
    if (plainText.trim().isEmpty) {
      return '';
    }

    final cursor = controller.selection.baseOffset.clamp(0, plainText.length);
    final lineStart = cursor <= 0
        ? 0
        : plainText.lastIndexOf('\n', cursor - 1) + 1;
    final nextLineBreak = plainText.indexOf('\n', cursor);
    final lineEnd = nextLineBreak < 0 ? plainText.length : nextLineBreak;
    return plainText.substring(lineStart, lineEnd).trim();
  }

  String _selectedPlainText() {
    final controller = _controller;
    if (controller == null) {
      return '';
    }

    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return '';
    }

    final plainText = controller.document.toPlainText();
    final start = selection.start.clamp(0, plainText.length);
    final end = selection.end.clamp(0, plainText.length);
    if (end <= start) {
      return '';
    }

    return plainText.substring(start, end);
  }

  void _jumpToBookmark(DocumentBookmark bookmark) {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final anchor = bookmark.anchor.trim();
    if (anchor.isEmpty) {
      return;
    }

    final plainText = controller.document.toPlainText();
    final start = plainText.toLowerCase().indexOf(anchor.toLowerCase());
    if (start < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not find "${bookmark.anchor}" in this page.'),
        ),
      );
      return;
    }

    controller.updateSelection(
      TextSelection(baseOffset: start, extentOffset: start + anchor.length),
      quill.ChangeSource.local,
    );
    _focusEditor();
  }

  void _focusEditor() {
    FocusScope.of(context).requestFocus(widget.contentFocusNode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final paiColors = context.paiColors;
    final isDark = theme.brightness == Brightness.dark;
    final isMobileLayout = MediaQuery.sizeOf(context).width < 900;
    final isCompactDesktop = widget.compactDesktop;
    final controller = _controller;
    final activeAttributes =
        controller?.getSelectionStyle().attributes ?? const {};

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(
          isMobileLayout
              ? 24
              : isCompactDesktop
              ? 24
              : 28,
        ),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: paiColors.panelShadow.withValues(
              alpha: isDark ? 0.18 : 0.08,
            ),
            blurRadius: isMobileLayout
                ? 18
                : isCompactDesktop
                ? 20
                : 24,
            offset: Offset(
              0,
              isMobileLayout
                  ? 10
                  : isCompactDesktop
                  ? 12
                  : 14,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          _PageEditorToolbar(
            titleText: widget.pageTitle,
            pageKindLabel: widget.pageKindLabel,
            metaLabels: [
              ...widget.metaLabels,
              _labelForSelectionStyle(activeAttributes),
            ],
            bookmarks: widget.bookmarks,
            isPinned: widget.isPinned,
            hasChanges: widget.hasChanges,
            boldEnabled: activeAttributes.containsKey(quill.Attribute.bold.key),
            italicEnabled: activeAttributes.containsKey(
              quill.Attribute.italic.key,
            ),
            underlineEnabled: activeAttributes.containsKey(
              quill.Attribute.underline.key,
            ),
            linkEnabled: activeAttributes.containsKey('link'),
            onFileMenuSelection: _handleFileMenuSelection,
            onInsertMenuSelection: _handleInsertMenuSelection,
            onBookmarksMenuSelection: _handleBookmarkMenuSelection,
            onToggleBold: () => _toggleInlineAttribute(quill.Attribute.bold),
            onToggleItalic: () =>
                _toggleInlineAttribute(quill.Attribute.italic),
            onToggleUnderline: () =>
                _toggleInlineAttribute(quill.Attribute.underline),
            onAddLink: _addLink,
            onTogglePinned: widget.onTogglePinned,
            canRename: widget.onRenamePage != null,
            canDuplicate: widget.onDuplicatePage != null,
            canDelete: widget.onDeletePage != null,
            onSavePage: widget.onSavePage,
            compactDesktop: widget.compactDesktop,
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: controller == null
                ? const SizedBox.shrink()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final showPageHeader =
                          !isMobileLayout &&
                          !isCompactDesktop &&
                          constraints.maxHeight >= 240;
                      final contentWidth = constraints.maxWidth;
                      final outerPadding = isMobileLayout
                          ? const EdgeInsets.fromLTRB(6, 6, 6, 6)
                          : isCompactDesktop
                          ? const EdgeInsets.fromLTRB(14, 12, 14, 14)
                          : const EdgeInsets.fromLTRB(28, 24, 28, 24);
                      final editorPadding = isMobileLayout
                          ? const EdgeInsets.fromLTRB(16, 14, 16, 20)
                          : isCompactDesktop
                          ? const EdgeInsets.fromLTRB(16, 14, 16, 16)
                          : const EdgeInsets.fromLTRB(20, 18, 20, 18);

                      return Padding(
                        padding: outerPadding,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: contentWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showPageHeader) ...[
                                  Text(
                                    widget.pageTitle,
                                    key: const ValueKey('workspace-page-title'),
                                    style:
                                        (isMobileLayout
                                                ? theme.textTheme.titleLarge
                                                : theme.textTheme.headlineSmall)
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                  ),
                                  SizedBox(height: isMobileLayout ? 6 : 8),
                                  Text(
                                    widget.pageKindLabel,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  SizedBox(height: isMobileLayout ? 12 : 20),
                                ],
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    margin: EdgeInsets.zero,
                                    decoration: BoxDecoration(
                                      color: AppTheme.tintedSurface(
                                        colorScheme.surface,
                                        colorScheme.primary,
                                        amount: isDark ? 0.08 : 0.02,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        isMobileLayout
                                            ? 20
                                            : isCompactDesktop
                                            ? 20
                                            : 24,
                                      ),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: editorPadding,
                                      child: Focus(
                                        onKeyEvent: (node, event) {
                                          if (event is! KeyDownEvent) {
                                            return KeyEventResult.ignored;
                                          }
                                          if (event.logicalKey !=
                                              LogicalKeyboardKey.backspace) {
                                            return KeyEventResult.ignored;
                                          }

                                          final pendingListShortcutRevert =
                                              _pendingListShortcutRevert;
                                          if (pendingListShortcutRevert ==
                                              null) {
                                            return KeyEventResult.ignored;
                                          }

                                          final applied =
                                              revertMarkdownListShortcut(
                                                controller: controller,
                                                pending:
                                                    pendingListShortcutRevert,
                                              );
                                          if (!applied) {
                                            return KeyEventResult.ignored;
                                          }

                                          setState(() {
                                            _pendingListShortcutRevert = null;
                                          });
                                          return KeyEventResult.handled;
                                        },
                                        child: quill.QuillEditor.basic(
                                          controller: controller,
                                          focusNode: widget.contentFocusNode,
                                          scrollController: _scrollController,
                                          config: quill.QuillEditorConfig(
                                            placeholder:
                                                'Write in one continuous page. Use the menu for structure and formatting.',
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PageEditorToolbar extends StatelessWidget {
  const _PageEditorToolbar({
    required this.titleText,
    required this.pageKindLabel,
    required this.metaLabels,
    required this.bookmarks,
    required this.isPinned,
    required this.hasChanges,
    required this.boldEnabled,
    required this.italicEnabled,
    required this.underlineEnabled,
    required this.linkEnabled,
    required this.onFileMenuSelection,
    required this.onInsertMenuSelection,
    required this.onBookmarksMenuSelection,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onToggleUnderline,
    required this.onAddLink,
    required this.canRename,
    required this.canDuplicate,
    required this.canDelete,
    required this.onSavePage,
    required this.compactDesktop,
    this.onTogglePinned,
  });

  final String titleText;
  final String pageKindLabel;
  final List<String> metaLabels;
  final List<DocumentBookmark> bookmarks;
  final bool isPinned;
  final bool hasChanges;
  final bool boldEnabled;
  final bool italicEnabled;
  final bool underlineEnabled;
  final bool linkEnabled;
  final PopupMenuItemSelected<String> onFileMenuSelection;
  final PopupMenuItemSelected<String> onInsertMenuSelection;
  final PopupMenuItemSelected<String> onBookmarksMenuSelection;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onToggleUnderline;
  final VoidCallback onAddLink;
  final bool canRename;
  final bool canDuplicate;
  final bool canDelete;
  final VoidCallback onSavePage;
  final bool compactDesktop;
  final VoidCallback? onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isMobileLayout = MediaQuery.sizeOf(context).width < 900;
    final infoLabels = <String>[
      pageKindLabel,
      for (final label in metaLabels)
        if (label.trim().isNotEmpty) label.trim(),
    ];

    void handleToolbarSelection(String value) {
      if (value.startsWith('file:')) {
        onFileMenuSelection(value.substring(5));
        return;
      }
      if (value.startsWith('insert:')) {
        onInsertMenuSelection(value.substring(7));
        return;
      }
      if (value.startsWith('bookmark:')) {
        onBookmarksMenuSelection(value.substring(9));
        return;
      }

      switch (value) {
        case 'pin':
          onTogglePinned?.call();
          return;
        case 'format:bold':
          onToggleBold();
          return;
        case 'format:italic':
          onToggleItalic();
          return;
        case 'format:underline':
          onToggleUnderline();
          return;
        case 'format:link':
          onAddLink();
          return;
      }
    }

    final overflowButton = PopupMenuButton<String>(
      tooltip: 'Page actions',
      onSelected: handleToolbarSelection,
      itemBuilder: (context) => [
        const PopupMenuItem<String>(value: 'file:new', child: Text('New page')),
        if (onTogglePinned != null)
          PopupMenuItem<String>(
            value: 'pin',
            child: Text(isPinned ? 'Unpin page' : 'Pin page'),
          ),
        if (canRename)
          const PopupMenuItem<String>(
            value: 'file:rename',
            child: Text('Rename page'),
          ),
        if (canDuplicate)
          const PopupMenuItem<String>(
            value: 'file:duplicate',
            child: Text('Duplicate page'),
          ),
        if (canDelete)
          const PopupMenuItem<String>(
            value: 'file:delete',
            child: Text('Delete page'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'insert:heading',
          child: Text('Insert heading'),
        ),
        const PopupMenuItem<String>(
          value: 'insert:subheading',
          child: Text('Insert subheading'),
        ),
        const PopupMenuItem<String>(
          value: 'insert:bullet',
          child: Text('Insert bullet list'),
        ),
        const PopupMenuItem<String>(
          value: 'insert:numbered',
          child: Text('Insert numbered list'),
        ),
        const PopupMenuItem<String>(
          value: 'insert:quote',
          child: Text('Insert quote'),
        ),
        const PopupMenuItem<String>(
          value: 'insert:divider',
          child: Text('Insert divider'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'format:bold',
          child: Text(boldEnabled ? 'Remove bold' : 'Bold'),
        ),
        PopupMenuItem<String>(
          value: 'format:italic',
          child: Text(italicEnabled ? 'Remove italic' : 'Italic'),
        ),
        PopupMenuItem<String>(
          value: 'format:underline',
          child: Text(underlineEnabled ? 'Remove underline' : 'Underline'),
        ),
        PopupMenuItem<String>(
          value: 'format:link',
          child: Text(linkEnabled ? 'Edit link' : 'Add link'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'bookmark:new',
          child: Text('Create bookmark'),
        ),
        if (bookmarks.isEmpty)
          const PopupMenuItem<String>(
            enabled: false,
            child: Text('No bookmarks yet'),
          ),
        for (final bookmark in bookmarks)
          PopupMenuItem<String>(
            value: 'bookmark:bookmark:${bookmark.id}',
            child: Text(bookmark.label),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.tintedSurface(
            colorScheme.surface,
            colorScheme.primary,
            amount: 0.04,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: const Icon(Icons.more_horiz_rounded),
      ),
    );

    if (isMobileLayout) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                infoLabels.join(' | '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
            if (hasChanges) ...[
              FilledButton.icon(
                onPressed: onSavePage,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 8),
            overflowButton,
          ],
        ),
      );
    }
    if (compactDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    infoLabels.join(' | '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _PageFormatButton(
              icon: Icons.format_bold_rounded,
              tooltip: 'Bold',
              selected: boldEnabled,
              onPressed: onToggleBold,
              compact: true,
            ),
            _PageFormatButton(
              icon: Icons.format_italic_rounded,
              tooltip: 'Italic',
              selected: italicEnabled,
              onPressed: onToggleItalic,
              compact: true,
            ),
            _PageFormatButton(
              icon: Icons.format_underlined_rounded,
              tooltip: 'Underline',
              selected: underlineEnabled,
              onPressed: onToggleUnderline,
              compact: true,
            ),
            _PageFormatButton(
              icon: Icons.link_rounded,
              tooltip: linkEnabled ? 'Edit link' : 'Add link',
              selected: linkEnabled,
              onPressed: onAddLink,
              compact: true,
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Save page',
              child: FilledButton(
                onPressed: hasChanges ? onSavePage : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Icon(Icons.save_outlined, size: 18),
              ),
            ),
            const SizedBox(width: 4),
            overflowButton,
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrowDesktop = constraints.maxWidth < 1180;
        final menus = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _PageToolbarMenuButton(
              label: 'File',
              icon: Icons.description_outlined,
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'file:new',
                  child: Text('New page'),
                ),
                if (canRename)
                  const PopupMenuItem<String>(
                    value: 'file:rename',
                    child: Text('Rename page'),
                  ),
                if (canDuplicate)
                  const PopupMenuItem<String>(
                    value: 'file:duplicate',
                    child: Text('Duplicate page'),
                  ),
                if (canDelete)
                  const PopupMenuItem<String>(
                    value: 'file:delete',
                    child: Text('Delete page'),
                  ),
              ],
              onSelected: handleToolbarSelection,
            ),
            _PageToolbarMenuButton(
              label: 'Insert',
              icon: Icons.add_box_outlined,
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'insert:heading',
                  child: Text('Heading'),
                ),
                PopupMenuItem<String>(
                  value: 'insert:subheading',
                  child: Text('Subheading'),
                ),
                PopupMenuItem<String>(
                  value: 'insert:bullet',
                  child: Text('Bullet list'),
                ),
                PopupMenuItem<String>(
                  value: 'insert:numbered',
                  child: Text('Numbered list'),
                ),
                PopupMenuItem<String>(
                  value: 'insert:quote',
                  child: Text('Quote'),
                ),
                PopupMenuItem<String>(
                  value: 'insert:divider',
                  child: Text('Divider'),
                ),
              ],
              onSelected: handleToolbarSelection,
            ),
            _PageToolbarMenuButton(
              label: 'Bookmarks',
              icon: Icons.bookmarks_outlined,
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'bookmark:new',
                  child: Text('Create bookmark'),
                ),
                if (bookmarks.isEmpty)
                  const PopupMenuItem<String>(
                    enabled: false,
                    child: Text('No bookmarks yet'),
                  ),
                for (final bookmark in bookmarks)
                  PopupMenuItem<String>(
                    value: 'bookmark:bookmark:${bookmark.id}',
                    child: Text(bookmark.label),
                  ),
              ],
              onSelected: handleToolbarSelection,
            ),
          ],
        );

        final titleArea = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titleText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in infoLabels) _PageToolbarLabel(text: label),
                if (isPinned) const _PageToolbarLabel(text: 'Pinned'),
              ],
            ),
          ],
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (onTogglePinned != null)
              IconButton(
                onPressed: onTogglePinned,
                tooltip: isPinned ? 'Unpin page' : 'Pin page',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.tintedSurface(
                    colorScheme.surface,
                    colorScheme.primary,
                    amount: isDark ? 0.12 : 0.04,
                  ),
                  foregroundColor: isPinned
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                icon: Icon(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                ),
              ),
            _PageFormatButton(
              icon: Icons.format_bold_rounded,
              tooltip: 'Bold',
              selected: boldEnabled,
              onPressed: onToggleBold,
            ),
            _PageFormatButton(
              icon: Icons.format_italic_rounded,
              tooltip: 'Italic',
              selected: italicEnabled,
              onPressed: onToggleItalic,
            ),
            _PageFormatButton(
              icon: Icons.format_underlined_rounded,
              tooltip: 'Underline',
              selected: underlineEnabled,
              onPressed: onToggleUnderline,
            ),
            _PageFormatButton(
              icon: Icons.link_rounded,
              tooltip: linkEnabled ? 'Edit link' : 'Add link',
              selected: linkEnabled,
              onPressed: onAddLink,
            ),
            FilledButton.icon(
              onPressed: hasChanges ? onSavePage : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ],
        );

        if (narrowDesktop) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                menus,
                const SizedBox(height: 10),
                titleArea,
                const SizedBox(height: 10),
                actions,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              menus,
              const SizedBox(width: 12),
              Expanded(child: titleArea),
              const SizedBox(width: 12),
              Flexible(
                child: Align(alignment: Alignment.topRight, child: actions),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PageToolbarMenuButton extends StatelessWidget {
  const _PageToolbarMenuButton({
    required this.label,
    required this.icon,
    required this.itemBuilder,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final PopupMenuItemBuilder<String> itemBuilder;
  final PopupMenuItemSelected<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return PopupMenuButton<String>(
      itemBuilder: itemBuilder,
      onSelected: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.tintedSurface(
            colorScheme.surface,
            colorScheme.primary,
            amount: isDark ? 0.12 : 0.04,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageFormatButton extends StatelessWidget {
  const _PageFormatButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: Size(compact ? 36 : 40, compact ? 36 : 40),
          padding: EdgeInsets.zero,
          backgroundColor: selected
              ? AppTheme.tintedSurface(
                  colorScheme.surface,
                  colorScheme.primary,
                  amount: isDark ? 0.24 : 0.1,
                )
              : AppTheme.tintedSurface(
                  colorScheme.surface,
                  colorScheme.primary,
                  amount: isDark ? 0.12 : 0.04,
                ),
          foregroundColor: selected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        icon: Icon(icon, size: compact ? 18 : 22),
      ),
    );
  }
}

class _PageToolbarLabel extends StatelessWidget {
  const _PageToolbarLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _BookmarkDialog extends StatefulWidget {
  const _BookmarkDialog({
    required this.initialAnchor,
    required this.initialLabel,
  });

  final String initialAnchor;
  final String initialLabel;

  @override
  State<_BookmarkDialog> createState() => _BookmarkDialogState();
}

class _BookmarkDialogState extends State<_BookmarkDialog> {
  late final TextEditingController _labelController = TextEditingController(
    text: widget.initialLabel,
  );
  late final TextEditingController _anchorController = TextEditingController(
    text: widget.initialAnchor,
  );
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    _anchorController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _labelController.text.trim();
    final anchor = _anchorController.text.trim();
    if (label.isEmpty || anchor.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _BookmarkDraft(
        label: label,
        anchor: anchor,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create bookmark'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _anchorController,
              decoration: const InputDecoration(
                labelText: 'Anchor text',
                hintText: 'Heading or phrase to jump to',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _BookmarkDraft {
  const _BookmarkDraft({required this.label, required this.anchor, this.note});

  final String label;
  final String anchor;
  final String? note;
}

class _LinkDraft {
  const _LinkDraft({required this.text, required this.url});

  final String text;
  final String url;
}

String _labelForSelectionStyle(
  Map<String, quill.Attribute<dynamic>> attributes,
) {
  final headerAttribute = attributes[quill.Attribute.header.key];
  if (headerAttribute?.value == 1) {
    return 'Heading';
  }
  if (headerAttribute?.value == 2) {
    return 'Subheading';
  }
  if (headerAttribute?.value == 3) {
    return 'Section heading';
  }

  final listAttribute = attributes[quill.Attribute.list.key];
  if (listAttribute?.value == 'bullet') {
    return 'Bullet list';
  }
  if (listAttribute?.value == 'ordered') {
    return 'Numbered list';
  }

  if (attributes.containsKey(quill.Attribute.blockQuote.key)) {
    return 'Quote';
  }
  if (attributes.containsKey(quill.Attribute.codeBlock.key)) {
    return 'Code block';
  }

  return 'Paragraph';
}
