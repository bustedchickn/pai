import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../models/document_bookmark.dart';
import '../models/project_document.dart';
import '../services/document_markdown_shortcuts.dart';
import '../services/document_selection_wrap.dart';
import '../theme/app_theme.dart';
import '../services/project_document_content_codec.dart';

typedef BookmarkCreateCallback =
    Future<void> Function(String label, String anchor, String? note);

class ProjectDocumentEditor extends StatefulWidget {
  const ProjectDocumentEditor({
    super.key,
    required this.documents,
    required this.selectedDocumentId,
    required this.documentTitleController,
    required this.documentContentController,
    required this.documentContentFocusNode,
    required this.selectedDocumentType,
    required this.selectedDocumentPinned,
    required this.hasDocumentChanges,
    required this.bookmarks,
    required this.onDocumentSelected,
    required this.onCreateDocument,
    required this.onRenameDocument,
    required this.onDuplicateDocument,
    required this.onDeleteDocument,
    required this.onDocumentTypeChanged,
    required this.onDocumentPinnedChanged,
    required this.onDocumentDraftChanged,
    required this.onSaveDocument,
    required this.onBookmarkCreated,
    this.onOpenFocusedEditor,
  });

  final List<ProjectDocument> documents;
  final String? selectedDocumentId;
  final TextEditingController documentTitleController;
  final TextEditingController documentContentController;
  final FocusNode documentContentFocusNode;
  final ProjectDocumentType selectedDocumentType;
  final bool selectedDocumentPinned;
  final bool hasDocumentChanges;
  final List<DocumentBookmark> bookmarks;
  final ValueChanged<ProjectDocument> onDocumentSelected;
  final VoidCallback onCreateDocument;
  final VoidCallback onRenameDocument;
  final VoidCallback onDuplicateDocument;
  final VoidCallback onDeleteDocument;
  final ValueChanged<ProjectDocumentType> onDocumentTypeChanged;
  final ValueChanged<bool> onDocumentPinnedChanged;
  final VoidCallback onDocumentDraftChanged;
  final VoidCallback onSaveDocument;
  final BookmarkCreateCallback onBookmarkCreated;
  final VoidCallback? onOpenFocusedEditor;

  @override
  State<ProjectDocumentEditor> createState() => _ProjectDocumentEditorState();
}

class _ProjectDocumentEditorState extends State<ProjectDocumentEditor> {
  final ScrollController _scrollController = ScrollController();
  quill.QuillController? _editorController;
  StreamSubscription<dynamic>? _documentChangeSubscription;
  String? _loadedDocumentId;
  String _loadedRawContent = '';
  bool _isApplyingEditorTransform = false;
  PendingListShortcutRevert? _pendingListShortcutRevert;

  ProjectDocument? get _selectedDocument {
    final selectedDocumentId = widget.selectedDocumentId;
    if (selectedDocumentId == null) {
      return null;
    }

    for (final document in widget.documents) {
      if (document.id == selectedDocumentId) {
        return document;
      }
    }

    return null;
  }

  quill.QuillController? get _controller => _editorController;

  @override
  void initState() {
    super.initState();
    _loadEditorDocument(force: true);
  }

  @override
  void didUpdateWidget(covariant ProjectDocumentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final documentChanged =
        oldWidget.selectedDocumentId != widget.selectedDocumentId ||
        oldWidget.documentContentController.text !=
            widget.documentContentController.text;
    if (documentChanged) {
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
    final selectedDocumentId = widget.selectedDocumentId;
    final rawContent = widget.documentContentController.text;
    if (!force &&
        selectedDocumentId == _loadedDocumentId &&
        rawContent == _loadedRawContent) {
      return;
    }

    _documentChangeSubscription?.cancel();
    _editorController?.removeListener(_handleEditorStateChanged);
    _editorController?.dispose();

    if (selectedDocumentId == null) {
      _editorController = null;
      _loadedDocumentId = null;
      _loadedRawContent = '';
      _pendingListShortcutRevert = null;
      if (mounted) {
        setState(() {});
      }
      return;
    }

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
    _loadedDocumentId = selectedDocumentId;
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

    final encoded = ProjectDocumentContentCodec.encode(controller.document);
    if (widget.documentContentController.text == encoded) {
      return;
    }

    widget.documentContentController.value = TextEditingValue(
      text: encoded,
      selection: TextSelection.collapsed(offset: encoded.length),
    );
    _loadedRawContent = encoded;
    widget.onDocumentDraftChanged();
  }

  Future<void> _copyMarkdown() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: ProjectDocumentContentCodec.toMarkdown(controller.document),
      ),
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Markdown copied.')));
  }

  Future<void> _showMarkdownSource() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final sourceController = TextEditingController(
      text: ProjectDocumentContentCodec.toMarkdown(controller.document),
    );
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Markdown export'),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: sourceController,
              readOnly: true,
              maxLines: 20,
              minLines: 12,
              style: const TextStyle(fontFamily: 'Courier'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
    sourceController.dispose();
  }

  void _handleFileMenuSelection(String action) {
    switch (action) {
      case 'new':
        widget.onCreateDocument();
        return;
      case 'rename':
        widget.onRenameDocument();
        return;
      case 'duplicate':
        widget.onDuplicateDocument();
        return;
      case 'delete':
        widget.onDeleteDocument();
        return;
      case 'copy-markdown':
        unawaited(_copyMarkdown());
        return;
      case 'view-markdown':
        unawaited(_showMarkdownSource());
        return;
    }

    if (!action.startsWith('doc:')) {
      return;
    }

    final documentId = action.substring(4);
    for (final document in widget.documents) {
      if (document.id == documentId) {
        widget.onDocumentSelected(document);
        return;
      }
    }
  }

  void _handleInsertMenuSelection(String action) {
    final controller = _controller;
    if (controller == null) {
      return;
    }

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
    if (_selectedDocument == null) {
      return;
    }

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
          content: Text(
            'Could not find "${bookmark.anchor}" in this document.',
          ),
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
    FocusScope.of(context).requestFocus(widget.documentContentFocusNode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final paiColors = context.paiColors;
    final isDark = theme.brightness == Brightness.dark;
    final isMobileLayout = MediaQuery.sizeOf(context).width < 900;
    final selectedDocument = _selectedDocument;
    final controller = _controller;
    final titleText = widget.documentTitleController.text.trim().isEmpty
        ? (selectedDocument?.title ?? 'Project document')
        : widget.documentTitleController.text.trim();
    final selectionStyle = controller?.getSelectionStyle();
    final activeAttributes = selectionStyle?.attributes ?? const {};

    return Container(
      constraints: isMobileLayout
          ? null
          : const BoxConstraints(minHeight: 520, maxHeight: 780),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(isMobileLayout ? 18 : 20),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: paiColors.panelShadow.withValues(
              alpha: isDark ? 0.18 : 0.08,
            ),
            blurRadius: isMobileLayout ? 16 : 20,
            offset: Offset(0, isMobileLayout ? 10 : 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _DocumentToolbar(
            titleText: titleText,
            selectedDocument: selectedDocument,
            documents: widget.documents,
            selectedDocumentType: widget.selectedDocumentType,
            selectedDocumentPinned: widget.selectedDocumentPinned,
            hasDocumentChanges: widget.hasDocumentChanges,
            bookmarks: widget.bookmarks,
            currentLineStyleLabel: _labelForSelectionStyle(activeAttributes),
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
            onDocumentTypeChanged: widget.onDocumentTypeChanged,
            onDocumentPinnedChanged: widget.onDocumentPinnedChanged,
            onToggleBold: () => _toggleInlineAttribute(quill.Attribute.bold),
            onToggleItalic: () =>
                _toggleInlineAttribute(quill.Attribute.italic),
            onToggleUnderline: () =>
                _toggleInlineAttribute(quill.Attribute.underline),
            onAddLink: _addLink,
            onSaveDocument: widget.onSaveDocument,
            onRenameDocument: widget.onRenameDocument,
            onOpenFocusedEditor: widget.onOpenFocusedEditor,
          ),
          const Divider(height: 1),
          Expanded(
            child: selectedDocument == null || controller == null
                ? _EmptyDocumentState(onCreateDocument: widget.onCreateDocument)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final contentWidth = isMobileLayout
                          ? (constraints.maxWidth * 0.9)
                                .clamp(0.0, constraints.maxWidth)
                                .toDouble()
                          : constraints.maxWidth;
                      final shellPadding = isMobileLayout
                          ? const EdgeInsets.fromLTRB(10, 10, 10, 12)
                          : const EdgeInsets.fromLTRB(18, 18, 18, 20);
                      final editorPadding = isMobileLayout
                          ? const EdgeInsets.fromLTRB(12, 12, 12, 28)
                          : const EdgeInsets.fromLTRB(28, 28, 28, 140);

                      return Container(
                        color: AppTheme.tintedSurface(
                          colorScheme.surface,
                          colorScheme.primary,
                          amount: isDark ? 0.08 : 0.03,
                        ),
                        padding: shellPadding,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: contentWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(
                                  isMobileLayout ? 20 : 22,
                                ),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: paiColors.panelShadow.withValues(
                                      alpha: isDark ? 0.16 : 0.06,
                                    ),
                                    blurRadius: isMobileLayout ? 14 : 18,
                                    offset: Offset(0, isMobileLayout ? 8 : 10),
                                  ),
                                ],
                              ),
                              child: Scrollbar(
                                controller: _scrollController,
                                thumbVisibility: true,
                                child: quill.QuillEditor(
                                  controller: controller,
                                  focusNode: widget.documentContentFocusNode,
                                  scrollController: _scrollController,
                                  config: quill.QuillEditorConfig(
                                    padding: editorPadding,
                                    placeholder:
                                        'Start writing your document...',
                                    scrollable: true,
                                    expands: false,
                                    // ignore: experimental_member_use
                                    onKeyPressed: (event, node) {
                                      final pendingListShortcutRevert =
                                          _pendingListShortcutRevert;
                                      if (pendingListShortcutRevert == null ||
                                          !isListShortcutBackspace(event)) {
                                        return null;
                                      }

                                      final reverted =
                                          revertMarkdownListShortcut(
                                            controller: controller,
                                            pending: pendingListShortcutRevert,
                                          );
                                      if (!reverted) {
                                        _pendingListShortcutRevert = null;
                                        return null;
                                      }

                                      _pendingListShortcutRevert = null;
                                      return KeyEventResult.handled;
                                    },
                                  ),
                                ),
                              ),
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

class _DocumentToolbar extends StatelessWidget {
  const _DocumentToolbar({
    required this.titleText,
    required this.selectedDocument,
    required this.documents,
    required this.selectedDocumentType,
    required this.selectedDocumentPinned,
    required this.hasDocumentChanges,
    required this.bookmarks,
    required this.currentLineStyleLabel,
    required this.boldEnabled,
    required this.italicEnabled,
    required this.underlineEnabled,
    required this.linkEnabled,
    required this.onFileMenuSelection,
    required this.onInsertMenuSelection,
    required this.onBookmarksMenuSelection,
    required this.onDocumentTypeChanged,
    required this.onDocumentPinnedChanged,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onToggleUnderline,
    required this.onAddLink,
    required this.onSaveDocument,
    required this.onRenameDocument,
    this.onOpenFocusedEditor,
  });

  final String titleText;
  final ProjectDocument? selectedDocument;
  final List<ProjectDocument> documents;
  final ProjectDocumentType selectedDocumentType;
  final bool selectedDocumentPinned;
  final bool hasDocumentChanges;
  final List<DocumentBookmark> bookmarks;
  final String currentLineStyleLabel;
  final bool boldEnabled;
  final bool italicEnabled;
  final bool underlineEnabled;
  final bool linkEnabled;
  final ValueChanged<String> onFileMenuSelection;
  final ValueChanged<String> onInsertMenuSelection;
  final ValueChanged<String> onBookmarksMenuSelection;
  final ValueChanged<ProjectDocumentType> onDocumentTypeChanged;
  final ValueChanged<bool> onDocumentPinnedChanged;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onToggleUnderline;
  final VoidCallback onAddLink;
  final VoidCallback onSaveDocument;
  final VoidCallback onRenameDocument;
  final VoidCallback? onOpenFocusedEditor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 980;
        final menus = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ToolbarMenuButton(
              label: 'File',
              icon: Icons.description_outlined,
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'new',
                  child: Text('New document'),
                ),
                PopupMenuItem<String>(
                  value: 'rename',
                  enabled: selectedDocument != null,
                  child: const Text('Rename current document'),
                ),
                PopupMenuItem<String>(
                  value: 'duplicate',
                  enabled: selectedDocument != null,
                  child: const Text('Duplicate current document'),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  enabled: selectedDocument != null,
                  child: const Text('Delete current document'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'copy-markdown',
                  child: Text('Copy markdown export'),
                ),
                const PopupMenuItem<String>(
                  value: 'view-markdown',
                  child: Text('View markdown export'),
                ),
                if (documents.isNotEmpty) const PopupMenuDivider(),
                if (documents.isNotEmpty)
                  PopupMenuItem<String>(
                    enabled: false,
                    height: 28,
                    child: Text(
                      'Switch document',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final document in documents)
                  PopupMenuItem<String>(
                    value: 'doc:${document.id}',
                    child: Row(
                      children: [
                        Icon(
                          _iconForDocumentType(document.type),
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            document.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (document.id == selectedDocument?.id)
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
              onSelected: onFileMenuSelection,
            ),
            _ToolbarMenuButton(
              label: 'Insert',
              icon: Icons.add_box_outlined,
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'heading',
                  enabled: selectedDocument != null,
                  child: const Text('Heading'),
                ),
                PopupMenuItem<String>(
                  value: 'subheading',
                  enabled: selectedDocument != null,
                  child: const Text('Subheading'),
                ),
                PopupMenuItem<String>(
                  value: 'bullet',
                  enabled: selectedDocument != null,
                  child: const Text('Bullet list'),
                ),
                PopupMenuItem<String>(
                  value: 'numbered',
                  enabled: selectedDocument != null,
                  child: const Text('Numbered list'),
                ),
                PopupMenuItem<String>(
                  value: 'quote',
                  enabled: selectedDocument != null,
                  child: const Text('Quote'),
                ),
                PopupMenuItem<String>(
                  value: 'divider',
                  enabled: selectedDocument != null,
                  child: const Text('Divider'),
                ),
              ],
              onSelected: onInsertMenuSelection,
            ),
            _ToolbarMenuButton(
              label: 'Bookmarks',
              icon: Icons.bookmarks_outlined,
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'new',
                  enabled: selectedDocument != null,
                  child: const Text('Create bookmark'),
                ),
                if (bookmarks.isNotEmpty) const PopupMenuDivider(),
                if (bookmarks.isNotEmpty)
                  PopupMenuItem<String>(
                    enabled: false,
                    height: 28,
                    child: Text(
                      'Jump to bookmark',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (bookmarks.isEmpty)
                  const PopupMenuItem<String>(
                    enabled: false,
                    child: Text('No bookmarks yet'),
                  ),
                for (final bookmark in bookmarks)
                  PopupMenuItem<String>(
                    value: 'bookmark:${bookmark.id}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bookmark.label),
                        Text(
                          bookmark.anchor,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
              ],
              onSelected: onBookmarksMenuSelection,
            ),
          ],
        );

        final titleArea = InkWell(
          onTap: onRenameDocument,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToolbarLabel(
                      text:
                          '${selectedDocumentType.label} - ${selectedDocument != null ? _formatDocumentTimestamp(selectedDocument!.updatedAt) : 'New'}',
                    ),
                    if (selectedDocumentPinned)
                      const _ToolbarLabel(text: 'Pinned'),
                    _ToolbarLabel(text: currentLineStyleLabel),
                  ],
                ),
              ],
            ),
          ),
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PopupMenuButton<ProjectDocumentType>(
              tooltip: 'Document type',
              onSelected: onDocumentTypeChanged,
              itemBuilder: (context) => [
                for (final type in ProjectDocumentType.values)
                  PopupMenuItem<ProjectDocumentType>(
                    value: type,
                    child: Text(type.label),
                  ),
              ],
              child: _ToolbarMetaPill(
                label: selectedDocumentType.label,
                icon: _iconForDocumentType(selectedDocumentType),
              ),
            ),
            IconButton(
              onPressed: selectedDocument == null
                  ? null
                  : () => onDocumentPinnedChanged(!selectedDocumentPinned),
              tooltip: selectedDocumentPinned
                  ? 'Unpin document'
                  : 'Pin document',
              icon: Icon(
                selectedDocumentPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
              ),
            ),
            _FormatButton(
              icon: Icons.format_bold_rounded,
              tooltip: 'Bold',
              selected: boldEnabled,
              onPressed: selectedDocument == null ? null : onToggleBold,
            ),
            _FormatButton(
              icon: Icons.format_italic_rounded,
              tooltip: 'Italic',
              selected: italicEnabled,
              onPressed: selectedDocument == null ? null : onToggleItalic,
            ),
            _FormatButton(
              icon: Icons.format_underlined_rounded,
              tooltip: 'Underline',
              selected: underlineEnabled,
              onPressed: selectedDocument == null ? null : onToggleUnderline,
            ),
            _FormatButton(
              icon: Icons.link_rounded,
              tooltip: linkEnabled ? 'Edit link' : 'Add link',
              selected: linkEnabled,
              onPressed: selectedDocument == null ? null : onAddLink,
            ),
            if (onOpenFocusedEditor != null)
              IconButton(
                onPressed: onOpenFocusedEditor,
                tooltip: 'Open focused editor',
                icon: const Icon(Icons.open_in_full_rounded),
              ),
            FilledButton.icon(
              onPressed: selectedDocument != null && hasDocumentChanges
                  ? onSaveDocument
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ],
        );

        if (narrow) {
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

class _ToolbarMenuButton extends StatelessWidget {
  const _ToolbarMenuButton({
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
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

class _ToolbarMetaPill extends StatelessWidget {
  const _ToolbarMetaPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;

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
        icon: Icon(icon),
      ),
    );
  }
}

class _ToolbarLabel extends StatelessWidget {
  const _ToolbarLabel({required this.text});

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

class _EmptyDocumentState extends StatelessWidget {
  const _EmptyDocumentState({required this.onCreateDocument});

  final VoidCallback onCreateDocument;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isMobileLayout = MediaQuery.sizeOf(context).width < 900;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = isMobileLayout
            ? (constraints.maxWidth * 0.9)
                  .clamp(0.0, constraints.maxWidth)
                  .toDouble()
            : math.min(constraints.maxWidth, 560.0);
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: isMobileLayout ? 12 : 24),
            child: SizedBox(
              width: cardWidth,
              child: Container(
                padding: EdgeInsets.all(isMobileLayout ? 18 : 24),
                decoration: BoxDecoration(
                  color: AppTheme.tintedSurface(
                    colorScheme.surface,
                    colorScheme.primary,
                    amount: isDark ? 0.08 : 0.03,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_document,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Open a project document',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The editor now behaves like one continuous writing surface, with File, Insert, and Bookmarks controls at the top.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onCreateDocument,
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('New document'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

IconData _iconForDocumentType(ProjectDocumentType type) {
  switch (type) {
    case ProjectDocumentType.design:
      return Icons.palette_outlined;
    case ProjectDocumentType.implementation:
      return Icons.code_rounded;
    case ProjectDocumentType.story:
      return Icons.auto_stories_outlined;
    case ProjectDocumentType.research:
      return Icons.search_rounded;
    case ProjectDocumentType.reference:
      return Icons.menu_book_rounded;
  }
}

String _formatDocumentTimestamp(DateTime value) {
  final month = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][value.month - 1];
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month ${value.day}, ${value.hour}:$minute';
}
