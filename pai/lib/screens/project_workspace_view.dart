import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/document_bookmark.dart';
import '../models/project.dart';
import '../models/project_document.dart';
import '../models/session_note.dart';
import '../layout/app_viewport.dart';
import '../services/browser_speech_to_text.dart';
import '../services/project_document_content_codec.dart';
import '../services/task_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/project_page_editor.dart';
import '../widgets/status_chip.dart';

const Duration kProjectsQuickAnimation = Duration(milliseconds: 220);
const Duration _kProjectSwitchDuration = Duration(milliseconds: 360);
const double _kProjectSwitchOutgoingScale = 0.92;
const double _kProjectSwitchIncomingScale = 0.96;
const double _kProjectSwitchMaxTranslation = 36;
const Alignment _kProjectSwitchAlignment = Alignment(-0.7, -0.92);
const double kWorkspaceSidebarExpandedWidth = 168;
const double kWorkspaceSidebarCollapsedWidth = 56;
const double kAssistantDrawerWidth = 380;

class ProjectWorkspaceView extends StatefulWidget {
  const ProjectWorkspaceView({
    super.key,
    required this.projects,
    required this.documents,
    required this.bookmarks,
    required this.onProjectSaved,
    required this.onProjectDeleted,
    required this.onSessionSaved,
    required this.onTasksAdded,
    required this.onTaskCompleted,
    required this.onDocumentSaved,
    required this.onBookmarkSaved,
    required this.onDocumentDeleted,
    this.selectedProjectId,
    this.selectionRequestId = 0,
  });

  final List<Project> projects;
  final List<ProjectDocument> documents;
  final List<DocumentBookmark> bookmarks;
  final Future<void> Function(Project project) onProjectSaved;
  final Future<void> Function(String projectId) onProjectDeleted;
  final Future<void> Function(String projectId, SessionNote session)
  onSessionSaved;
  final Future<void> Function(String projectId, List<String> tasks)
  onTasksAdded;
  final Future<void> Function(
    String projectId,
    String task,
    SessionNote completionNote,
    String updatedBrief,
  )
  onTaskCompleted;
  final Future<void> Function(ProjectDocument document) onDocumentSaved;
  final Future<void> Function(DocumentBookmark bookmark) onBookmarkSaved;
  final Future<void> Function(String documentId) onDocumentDeleted;
  final String? selectedProjectId;
  final int selectionRequestId;

  @override
  State<ProjectWorkspaceView> createState() => _ProjectWorkspaceViewState();
}

class _ProjectWorkspaceViewState extends State<ProjectWorkspaceView>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _assistantDrawerScaffoldKey =
      GlobalKey<ScaffoldState>();
  final GlobalKey _projectTitleAnchorKey = GlobalKey();
  final GlobalKey _projectSelectorAnchorKey = GlobalKey();
  final GlobalKey _projectWorkspaceShellKey = GlobalKey();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _sessionController = TextEditingController();
  final TextEditingController _pageContentController = TextEditingController();
  final FocusNode _pageContentFocusNode = FocusNode();
  late final BrowserSpeechToText _speechToText = createBrowserSpeechToText();
  late final AnimationController _projectSwitchController =
      AnimationController(vsync: this, duration: _kProjectSwitchDuration)
        ..addListener(_handleProjectSwitchProgress)
        ..addStatusListener(_handleProjectSwitchStatus);
  final Set<String> _completingNextSteps = <String>{};
  final Set<String> _selectedRecapTaskCandidates = <String>{};

  late Project _selectedProject;
  StreamSubscription<BrowserSpeechTranscription>? _speechSubscription;
  StreamSubscription<bool>? _speechListeningSubscription;
  List<SessionNote> _pendingCompletionSessions = const [];
  List<String> _recapTaskCandidates = const [];
  String? _selectedPageId;
  bool _isSidebarExpanded = true;
  bool _isAssistantDrawerOpen = false;
  bool _isShowingProjectHub = false;
  bool _isSessionComposerVisible = false;
  bool _isSpeechToTextAvailable = false;
  bool _isSpeechToTextListening = false;
  bool _hasAppliedQueuedProject = false;
  String? _queuedProjectId;
  String _liveSessionTranscript = '';
  String _assistantReply =
      'Ask about this project to get a quick summary, blockers, or next steps.';

  @override
  void initState() {
    super.initState();
    _selectedProject = widget.projects.first;
    _speechSubscription = _speechToText.transcriptions.listen(
      _handleSpeechTranscription,
    );
    _speechListeningSubscription = _speechToText.listeningChanges.listen(
      _handleSpeechListeningChanged,
    );
    unawaited(_initializeSpeechToText());
    _applyRequestedSelection();
    _syncPageSelection(resetForProject: true);
  }

  @override
  void didUpdateWidget(covariant ProjectWorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousProjectId = _selectedProject.id;
    _selectedProject = _projectForId(previousProjectId);
    _reconcilePendingSessionState();

    if (widget.selectionRequestId != oldWidget.selectionRequestId) {
      _applyRequestedSelection();
    }

    _syncPageSelection(
      resetForProject: previousProjectId != _selectedProject.id,
    );
  }

  @override
  void dispose() {
    _projectSwitchController
      ..removeListener(_handleProjectSwitchProgress)
      ..removeStatusListener(_handleProjectSwitchStatus)
      ..dispose();
    _speechSubscription?.cancel();
    _speechListeningSubscription?.cancel();
    _speechToText.dispose();
    _questionController.dispose();
    _sessionController.dispose();
    _pageContentController.dispose();
    _pageContentFocusNode.dispose();
    super.dispose();
  }

  Project _projectForId(String? projectId) {
    return widget.projects.firstWhere(
      (project) => project.id == projectId,
      orElse: () => widget.projects.first,
    );
  }

  List<ProjectDocument> get _projectDocuments {
    final documents = [
      for (final document in widget.documents)
        if (document.projectId == _selectedProject.id) document,
    ];
    documents.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return documents;
  }

  List<_WorkspacePage> get _workspacePages {
    final pages = <_WorkspacePage>[
      _WorkspacePage(
        id: _selectedProject.briefPageId,
        projectId: _selectedProject.id,
        title: 'Project Brief',
        content: _selectedProject.brief,
        kind: _WorkspacePageKind.brief,
        isPinned: false,
        createdAt: _selectedProject.createdAt,
        updatedAt: _selectedProject.updatedAt,
      ),
      for (final document in _projectDocuments)
        _WorkspacePage(
          id: document.id,
          projectId: document.projectId,
          title: document.title,
          content: document.content,
          kind: _WorkspacePageKind.document,
          isPinned: document.pinned,
          createdAt: document.createdAt,
          updatedAt: document.updatedAt,
          document: document,
        ),
    ];
    return pages;
  }

  _WorkspacePage get _briefPage => _workspacePages.first;

  _WorkspacePage? get _selectedPage {
    final selectedPageId = _selectedPageId;
    if (selectedPageId == null) {
      return null;
    }

    for (final page in _workspacePages) {
      if (page.id == selectedPageId) {
        return page;
      }
    }
    return null;
  }

  List<DocumentBookmark> get _selectedPageBookmarks {
    final selectedPageId = _selectedPageId;
    if (selectedPageId == null) {
      return const [];
    }

    final bookmarks = [
      for (final bookmark in widget.bookmarks)
        if (bookmark.documentId == selectedPageId) bookmark,
    ];
    bookmarks.sort(
      (left, right) =>
          left.label.toLowerCase().compareTo(right.label.toLowerCase()),
    );
    return bookmarks;
  }

  List<_WorkspacePage> get _pinnedPages => [
    for (final page in _workspacePages)
      if (page.kind == _WorkspacePageKind.document && page.isPinned) page,
  ];

  List<_WorkspacePage> get _documentPages => [
    for (final page in _workspacePages)
      if (page.kind == _WorkspacePageKind.document && !page.isPinned) page,
  ];

  List<SessionNote> get _recentSessions {
    final persistedIds = _selectedProject.sessions
        .map((session) => session.id)
        .toSet();
    final pendingSessions = [
      for (final session in _pendingCompletionSessions)
        if (!persistedIds.contains(session.id)) session,
    ];

    return [...pendingSessions, ..._selectedProject.sessions];
  }

  bool get _hasPageChanges {
    final selectedPage = _selectedPage;
    if (selectedPage == null) {
      return false;
    }
    return _pageContentController.text != selectedPage.content;
  }

  void _applyRequestedSelection() {
    if (widget.selectedProjectId == null) {
      return;
    }

    _applyProjectSelection(_projectForId(widget.selectedProjectId));
  }

  bool get _reduceProjectMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _applyProjectSelection(Project project) {
    _selectedProject = project;
    _resetProjectScopedUi();
    _loadPageIntoEditor(_defaultPageForProject());
  }

  void _resetProjectScopedUi() {
    unawaited(_speechToText.stop());
    _pendingCompletionSessions = const [];
    _recapTaskCandidates = const [];
    _selectedRecapTaskCandidates.clear();
    _sessionController.clear();
    _assistantReply =
        'Ask about this project to get a quick summary, blockers, or next steps.';
    _selectedPageId = null;
    _isShowingProjectHub = false;
    _isSessionComposerVisible = false;
    _liveSessionTranscript = '';
    _pageContentController.clear();
  }

  void _queueProjectSwitch(Project project) {
    if (project.id == _selectedProject.id &&
        !_projectSwitchController.isAnimating) {
      return;
    }

    if (_reduceProjectMotion) {
      setState(() => _applyProjectSelection(project));
      return;
    }

    _queuedProjectId = project.id;
    if (_projectSwitchController.isAnimating) {
      return;
    }

    _hasAppliedQueuedProject = false;
    _projectSwitchController
      ..duration = _kProjectSwitchDuration
      ..forward(from: 0);
    setState(() {});
  }

  void _handleProjectSwitchProgress() {
    if (_hasAppliedQueuedProject || _projectSwitchController.value < 0.5) {
      return;
    }

    final targetProjectId = _queuedProjectId;
    if (targetProjectId == null) {
      _hasAppliedQueuedProject = true;
      return;
    }

    _hasAppliedQueuedProject = true;
    if (!mounted) {
      return;
    }

    setState(() {
      _applyProjectSelection(_projectForId(targetProjectId));
      _queuedProjectId = null;
    });
  }

  void _handleProjectSwitchStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }

    _hasAppliedQueuedProject = false;
    final queuedProjectId = _queuedProjectId;
    if (!mounted ||
        queuedProjectId == null ||
        queuedProjectId == _selectedProject.id) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _projectSwitchController.forward(from: 0);
    setState(() {});
  }

  void _reconcilePendingSessionState() {
    final persistedIds = _selectedProject.sessions
        .map((session) => session.id)
        .toSet();
    _pendingCompletionSessions = [
      for (final session in _pendingCompletionSessions)
        if (!persistedIds.contains(session.id)) session,
    ];
    _completingNextSteps.removeWhere(
      (step) => !_selectedProject.nextSteps.contains(step),
    );
  }

  void _syncPageSelection({required bool resetForProject}) {
    final pages = _workspacePages;
    if (pages.isEmpty) {
      _selectedPageId = null;
      _pageContentController.clear();
      return;
    }

    if (resetForProject) {
      _loadPageIntoEditor(_defaultPageForProject());
      return;
    }

    final selectedPage = _selectedPage;
    if (selectedPage == null) {
      _loadPageIntoEditor(_defaultPageForProject());
      return;
    }

    if (!_hasPageChanges) {
      _pageContentController.text = selectedPage.content;
    }
  }

  _WorkspacePage _defaultPageForProject() {
    final lastOpenedPageId = _selectedProject.lastOpenedPageId;
    if (lastOpenedPageId != null) {
      for (final page in _workspacePages) {
        if (page.id == lastOpenedPageId) {
          return page;
        }
      }
    }

    return _briefPage;
  }

  void _loadPageIntoEditor(_WorkspacePage page) {
    _selectedPageId = page.id;
    _pageContentController.value = TextEditingValue(
      text: page.content,
      selection: TextSelection.collapsed(offset: page.content.length),
    );
  }

  Future<void> _persistLastOpenedPage(String pageId) async {
    if (_selectedProject.lastOpenedPageId == pageId) {
      return;
    }

    final updatedProject = _selectedProject.copyWith(lastOpenedPageId: pageId);
    setState(() => _selectedProject = updatedProject);
    await widget.onProjectSaved(updatedProject);
  }

  void _selectProject(Project project) {
    _queueProjectSwitch(project);
  }

  void _selectPage(_WorkspacePage page) {
    final shouldPersist = _selectedProject.lastOpenedPageId != page.id;
    unawaited(_speechToText.stop());
    setState(() {
      _isShowingProjectHub = false;
      _isSessionComposerVisible = false;
      _liveSessionTranscript = '';
      _loadPageIntoEditor(page);
    });
    if (shouldPersist) {
      unawaited(_persistLastOpenedPage(page.id));
    }
  }

  Future<void> _openMobileNavigatorSheet() async {
    final selectedPage = _selectedPage ?? _defaultPageForProject();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: _WorkspaceSidebar(
              projects: widget.projects,
              selectedProject: _selectedProject,
              selectedPageId: selectedPage.id,
              briefPage: _briefPage,
              pinnedPages: _pinnedPages,
              documentPages: _documentPages,
              isExpanded: true,
              projectSelectorAnchorKey: _projectSelectorAnchorKey,
              onProjectSelected: (project) {
                Navigator.of(sheetContext).pop();
                _selectProject(project);
              },
              onPageSelected: (page) {
                Navigator.of(sheetContext).pop();
                _selectPage(page);
              },
            ),
          ),
        );
      },
    );
  }

  void _toggleProjectHub() {
    if (_isShowingProjectHub) {
      unawaited(_speechToText.stop());
    }
    setState(() {
      _isShowingProjectHub = !_isShowingProjectHub;
      if (_isShowingProjectHub) {
        _isSessionComposerVisible = false;
        _liveSessionTranscript = '';
      }
    });
  }

  void _showSessionComposer() {
    setState(() {
      _isShowingProjectHub = true;
      _isSessionComposerVisible = true;
    });
  }

  Future<void> _initializeSpeechToText() async {
    final available = await _speechToText.initialize();
    if (!mounted) {
      return;
    }

    setState(() => _isSpeechToTextAvailable = available);
  }

  void _handleSpeechListeningChanged(bool isListening) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isSpeechToTextListening = isListening;
      if (!isListening) {
        _liveSessionTranscript = '';
      }
    });
  }

  void _handleSpeechTranscription(BrowserSpeechTranscription transcription) {
    if (!mounted) {
      return;
    }

    if (transcription.isFinal) {
      _insertSpeechTranscriptionIntoSessionField(transcription.text);
      setState(() => _liveSessionTranscript = '');
      return;
    }

    setState(() => _liveSessionTranscript = transcription.text);
  }

  Future<void> _toggleSpeechToText() async {
    if (!_isSpeechToTextAvailable) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dictation is not available in this browser.'),
        ),
      );
      return;
    }

    if (_isSpeechToTextListening) {
      await _speechToText.stop();
      return;
    }

    await _speechToText.start();
  }

  void _insertSpeechTranscriptionIntoSessionField(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return;
    }

    final value = _sessionController.value;
    final normalizedSelection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final start = normalizedSelection.start.clamp(0, value.text.length);
    final end = normalizedSelection.end.clamp(0, value.text.length);
    final before = value.text.substring(0, start);
    final after = value.text.substring(end);
    final needsLeadingSpace =
        before.isNotEmpty && !RegExp(r'[\s(\[{]$').hasMatch(before);
    final needsTrailingSpace =
        after.isNotEmpty && !RegExp(r'^[\s,.;:!?)]').hasMatch(after);
    final inserted =
        '${needsLeadingSpace ? ' ' : ''}$text'
        '${needsTrailingSpace ? ' ' : ''}';
    final updatedText = '$before$inserted$after';
    final caretOffset = before.length + inserted.length;
    _sessionController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: caretOffset),
    );
  }

  Future<void> _savePage() async {
    final selectedPage = _selectedPage;
    if (selectedPage == null) {
      return;
    }

    if (selectedPage.kind == _WorkspacePageKind.brief) {
      final updatedAt = DateTime.now();
      final updatedProject = _selectedProject.copyWith(
        brief: _pageContentController.text,
        updatedAt: updatedAt,
        lastOpenedPageId: selectedPage.id,
      );
      setState(() => _selectedProject = updatedProject);
      final briefDocument = ProjectDocument(
        id: selectedPage.id,
        projectId: _selectedProject.id,
        title: selectedPage.title,
        kind: ProjectPageKind.brief,
        type: ProjectDocumentType.reference,
        content: _pageContentController.text,
        pinned: false,
        createdAt: selectedPage.createdAt,
        updatedAt: updatedAt,
        orderIndex: 0,
      );
      await Future.wait<void>([
        widget.onDocumentSaved(briefDocument),
        widget.onProjectSaved(updatedProject),
      ]);
      return;
    }

    final document = selectedPage.document!;
    await widget.onDocumentSaved(
      document.copyWith(
        content: _pageContentController.text,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _createPage() async {
    final now = DateTime.now();
    final document = ProjectDocument(
      id: 'doc-${now.microsecondsSinceEpoch}',
      projectId: _selectedProject.id,
      title: 'Untitled page',
      type: ProjectDocumentType.implementation,
      content: '',
      pinned: false,
      createdAt: now,
      updatedAt: now,
    );
    await widget.onDocumentSaved(document);
    if (!mounted) {
      return;
    }

    setState(() => _loadPageIntoEditor(_WorkspacePage.fromDocument(document)));
    unawaited(_persistLastOpenedPage(document.id));
  }

  Future<String?> _promptForPageTitle({
    required String title,
    required String confirmLabel,
    required String heading,
  }) async {
    final controller = TextEditingController(text: title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(heading),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Page title',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) =>
                Navigator.of(context).pop(controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    final trimmed = result?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<void> _renameSelectedPage() async {
    final selectedPage = _selectedPage;
    if (selectedPage == null || selectedPage.kind == _WorkspacePageKind.brief) {
      return;
    }

    final nextTitle = await _promptForPageTitle(
      title: selectedPage.title,
      confirmLabel: 'Rename',
      heading: 'Rename page',
    );
    if (nextTitle == null) {
      return;
    }

    await widget.onDocumentSaved(
      selectedPage.document!.copyWith(
        title: nextTitle,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _duplicateSelectedPage() async {
    final selectedPage = _selectedPage;
    if (selectedPage == null || selectedPage.kind == _WorkspacePageKind.brief) {
      return;
    }

    final now = DateTime.now();
    final duplicate = selectedPage.document!.copyWith(
      id: 'doc-${now.microsecondsSinceEpoch}',
      title: '${selectedPage.title} copy',
      createdAt: now,
      updatedAt: now,
    );
    await widget.onDocumentSaved(duplicate);
    if (!mounted) {
      return;
    }

    setState(() => _loadPageIntoEditor(_WorkspacePage.fromDocument(duplicate)));
    unawaited(_persistLastOpenedPage(duplicate.id));
  }

  Future<void> _deleteSelectedPage() async {
    final selectedPage = _selectedPage;
    if (selectedPage == null || selectedPage.kind == _WorkspacePageKind.brief) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete page?'),
          content: Text('Delete "${selectedPage.title}" and its bookmarks?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await widget.onDocumentDeleted(selectedPage.id);
    if (!mounted) {
      return;
    }

    setState(() => _loadPageIntoEditor(_briefPage));
    unawaited(_persistLastOpenedPage(_briefPage.id));
  }

  Future<void> _deleteSelectedProject() async {
    final project = _selectedProject;
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete project?'),
          content: const Text(
            'This will remove the project from your workspace and sync the deletion to your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await widget.onProjectDeleted(project.id);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted "${project.title}". Run sync when you are ready to remove it from your other devices.',
        ),
      ),
    );
  }

  Future<void> _toggleSelectedPagePinned() async {
    final selectedPage = _selectedPage;
    if (selectedPage == null || selectedPage.kind == _WorkspacePageKind.brief) {
      return;
    }

    await widget.onDocumentSaved(
      selectedPage.document!.copyWith(
        pinned: !selectedPage.isPinned,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _createBookmark(
    String label,
    String anchor,
    String? note,
  ) async {
    final selectedPageId = _selectedPageId;
    if (selectedPageId == null) {
      return;
    }

    final bookmark = DocumentBookmark(
      id: 'bookmark-${DateTime.now().microsecondsSinceEpoch}',
      documentId: selectedPageId,
      label: label,
      anchor: anchor,
      note: note,
    );
    await widget.onBookmarkSaved(bookmark);
    if (_selectedPage?.kind == _WorkspacePageKind.brief) {
      final updatedProject = _selectedProject.copyWith(
        updatedAt: DateTime.now(),
      );
      setState(() => _selectedProject = updatedProject);
      await widget.onProjectSaved(updatedProject);
    }
  }

  void _toggleAssistantDrawer() {
    if (_isAssistantDrawerOpen) {
      _closeAssistantDrawer();
      return;
    }

    _assistantDrawerScaffoldKey.currentState?.openEndDrawer();
  }

  void _closeAssistantDrawer() {
    if (!_isAssistantDrawerOpen) {
      return;
    }

    Navigator.of(context).maybePop();
  }

  double _assistantDrawerWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth < 720) {
      return (screenWidth - 24).clamp(280.0, 420.0).toDouble();
    }
    if (AppViewport.isCompactDesktopWidth(screenWidth)) {
      return 340;
    }
    return kAssistantDrawerWidth;
  }

  String get _projectBriefSummary =>
      ProjectDocumentContentCodec.previewText(_selectedProject.brief);

  void _askAssistant() {
    final input = _questionController.text.toLowerCase().trim();
    if (input.isEmpty) {
      return;
    }

    setState(() {
      if (input.contains('next')) {
        _assistantReply = _selectedProject.nextSteps.isEmpty
            ? '${_selectedProject.title} has no active next steps right now.'
            : 'Next steps for ${_selectedProject.title}: ${_selectedProject.nextSteps.join(', ')}.';
      } else if (input.contains('block') || input.contains('stuck')) {
        _assistantReply = _selectedProject.blockers.isEmpty
            ? '${_selectedProject.title} has no recorded blockers right now.'
            : 'Current blockers for ${_selectedProject.title}: ${_selectedProject.blockers.join(', ')}.';
      } else if (input.contains('latest') ||
          input.contains('summary') ||
          input.contains('what happened')) {
        _assistantReply = _selectedProject.sessions.isEmpty
            ? _projectBriefSummary
            : _selectedProject.sessions.first.summary;
      } else {
        _assistantReply =
            '${_selectedProject.title} is ${_selectedProject.status}. $_projectBriefSummary';
      }
    });
  }

  void _handleRecapChanged(String _) {
    if (_recapTaskCandidates.isEmpty && _selectedRecapTaskCandidates.isEmpty) {
      return;
    }

    setState(() {
      _recapTaskCandidates = const [];
      _selectedRecapTaskCandidates.clear();
    });
  }

  Future<void> _saveSessionRecap() async {
    final recapText = _sessionController.text.trim();
    if (recapText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a short recap before saving it.')),
      );
      return;
    }

    await _speechToText.stop();
    final recapNote = SessionNote(
      id: 'session-${DateTime.now().microsecondsSinceEpoch}',
      dateLabel: 'Just now',
      summary: recapText,
    );
    setState(() {
      _selectedProject = _selectedProject.copyWith(
        sessions: [recapNote, ..._selectedProject.sessions],
        updatedAt: DateTime.now(),
      );
      _sessionController.clear();
      _recapTaskCandidates = const [];
      _selectedRecapTaskCandidates.clear();
      _isSessionComposerVisible = false;
      _liveSessionTranscript = '';
      _assistantReply = 'Saved the session recap to recent sessions.';
    });

    await widget.onSessionSaved(_selectedProject.id, recapNote);
  }

  void _extractTasksFromRecap() {
    final result = parseTasks(_sessionController.text);
    final candidates = result.finalTasks
        .map((task) => task.title)
        .toList(growable: false);
    final hasActionableClauses = hasActionableTaskClauses(result);
    if (candidates.isEmpty) {
      final message = !hasActionableClauses && result.signals.ambiguityDetected
          ? 'I found intent, but not enough detail to suggest safe tasks yet.'
          : 'No task-like phrases found yet. Try an action plus object.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    setState(() {
      _recapTaskCandidates = candidates;
      _selectedRecapTaskCandidates
        ..clear()
        ..addAll(candidates);
      _assistantReply =
          'Review the proposed tasks and add the ones you want to keep.';
    });
  }

  void _toggleRecapTaskCandidate(String task) {
    setState(() {
      if (_selectedRecapTaskCandidates.contains(task)) {
        _selectedRecapTaskCandidates.remove(task);
      } else {
        _selectedRecapTaskCandidates.add(task);
      }
    });
  }

  Future<void> _addTasksFromRecap() async {
    if (_selectedRecapTaskCandidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one candidate task first.'),
        ),
      );
      return;
    }

    final existingStepsLower = _selectedProject.nextSteps
        .map((step) => step.toLowerCase())
        .toSet();
    final tasksToAdd = [
      for (final task in _recapTaskCandidates)
        if (_selectedRecapTaskCandidates.contains(task) &&
            !existingStepsLower.contains(task.toLowerCase()))
          task,
    ];

    if (tasksToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Those tasks are already in the next steps list.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedProject = _selectedProject.copyWith(
        nextSteps: [..._selectedProject.nextSteps, ...tasksToAdd],
        updatedAt: DateTime.now(),
      );
      _recapTaskCandidates = const [];
      _selectedRecapTaskCandidates.clear();
      _assistantReply =
          'Added ${tasksToAdd.length} new next step${tasksToAdd.length == 1 ? '' : 's'} from the recap.';
    });

    await widget.onTasksAdded(_selectedProject.id, tasksToAdd);
  }

  Future<void> _completeNextStep(String step) async {
    final completionNote = SessionNote(
      id: 'session-${DateTime.now().microsecondsSinceEpoch}',
      dateLabel: 'Just now',
      summary: 'Completed: $step',
      type: SessionNoteType.completion,
    );
    final projectId = _selectedProject.id;
    if (_completingNextSteps.contains(step)) {
      return;
    }

    setState(() {
      _completingNextSteps.add(step);
      _pendingCompletionSessions = [
        completionNote,
        ..._pendingCompletionSessions,
      ];
      _assistantReply =
          'Checked off "$step". The recap entry is already in recent sessions.';
    });

    await Future<void>.delayed(kProjectsQuickAnimation);
    if (!mounted) {
      return;
    }

    final currentProject = _projectForId(projectId);
    if (!currentProject.nextSteps.contains(step)) {
      setState(() {
        _completingNextSteps.remove(step);
        _pendingCompletionSessions = [
          for (final session in _pendingCompletionSessions)
            if (session.id != completionNote.id) session,
        ];
      });
      return;
    }

    final updatedProject = currentProject.copyWith(
      brief: _briefWithCompletionUpdate(
        currentProject.brief,
        completedStep: step,
        remainingSteps: currentProject.nextSteps.length - 1,
      ),
      nextSteps: [
        for (final nextStep in currentProject.nextSteps)
          if (nextStep != step) nextStep,
      ],
      sessions: [completionNote, ...currentProject.sessions],
      updatedAt: DateTime.now(),
    );

    setState(() {
      if (_selectedProject.id == projectId) {
        _selectedProject = updatedProject;
        _assistantReply =
            'Marked "$step" complete and added it to recent sessions.';
      }
      _completingNextSteps.remove(step);
      _pendingCompletionSessions = [
        for (final session in _pendingCompletionSessions)
          if (session.id != completionNote.id) session,
      ];
    });

    await widget.onTaskCompleted(
      projectId,
      step,
      completionNote,
      updatedProject.brief,
    );
  }

  int _wordCountForRawContent(String rawContent) {
    final plainText = ProjectDocumentContentCodec.toPlainText(rawContent);
    if (plainText.isEmpty) {
      return 0;
    }
    return plainText
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
  }

  _ProjectStats get _projectStats {
    var totalWords = 0;
    var lastEdited = _selectedProject.updatedAt;
    for (final page in _workspacePages) {
      totalWords += _wordCountForRawContent(page.content);
      if (page.updatedAt.isAfter(lastEdited)) {
        lastEdited = page.updatedAt;
      }
    }

    return _ProjectStats(
      pageCount: _workspacePages.length,
      pinnedCount: _pinnedPages.length,
      totalWordCount: totalWords,
      lastEdited: lastEdited,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final viewportMode = AppViewport.fromWidth(screenWidth);
    final isMobileLayout = viewportMode == AppViewportMode.mobile;
    final isCompactDesktop = viewportMode == AppViewportMode.compactDesktop;
    final selectedPage = _selectedPage ?? _defaultPageForProject();
    final assistantPane = _WorkspaceDrawer(
      questionController: _questionController,
      assistantReply: _assistantReply,
      onAsk: _askAssistant,
      onClose: _closeAssistantDrawer,
    );

    return SafeArea(
      bottom: !isMobileLayout,
      child: Scaffold(
        key: _assistantDrawerScaffoldKey,
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        endDrawerEnableOpenDragGesture: false,
        onEndDrawerChanged: (isOpen) {
          if (_isAssistantDrawerOpen != isOpen) {
            setState(() => _isAssistantDrawerOpen = isOpen);
          }
        },
        endDrawer: SizedBox(
          width: _assistantDrawerWidth(context),
          child: Drawer(
            backgroundColor: AppTheme.tintedSurface(
              colorScheme.surface,
              colorScheme.primary,
              amount: theme.brightness == Brightness.dark ? 0.08 : 0.02,
            ),
            child: SafeArea(
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    DismissIntent: CallbackAction<DismissIntent>(
                      onInvoke: (intent) {
                        _closeAssistantDrawer();
                        return null;
                      },
                    ),
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: assistantPane,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobileLayout
                ? 10
                : isCompactDesktop
                ? 14
                : 20,
            isMobileLayout
                ? 8
                : isCompactDesktop
                ? 14
                : 20,
            isMobileLayout
                ? 10
                : isCompactDesktop
                ? 14
                : 20,
            isMobileLayout
                ? 0
                : isCompactDesktop
                ? 14
                : 20,
          ),
          child: Column(
            children: [
              _WorkspaceTopBar(
                project: _selectedProject,
                page: selectedPage,
                hasUnsavedChanges: _hasPageChanges,
                isShowingProjectHub: _isShowingProjectHub,
                isSidebarExpanded: _isSidebarExpanded,
                isAssistantDrawerOpen: _isAssistantDrawerOpen,
                projectSwitchAnimation: _projectSwitchController,
                isProjectSwitchAnimating: _projectSwitchController.isAnimating,
                projectTitleAnchorKey: _projectTitleAnchorKey,
                isMobileLayout: isMobileLayout,
                isCompactDesktop: isCompactDesktop,
                onProjectNamePressed: _toggleProjectHub,
                onOpenNavigatorSheet: _openMobileNavigatorSheet,
                onNewPage: () {
                  unawaited(_createPage());
                },
                onDeleteProject: () {
                  unawaited(_deleteSelectedProject());
                },
                onToggleAssistantDrawer: _toggleAssistantDrawer,
                onToggleSidebar: () {
                  setState(() => _isSidebarExpanded = !_isSidebarExpanded);
                },
              ),
              SizedBox(
                height: isMobileLayout
                    ? 8
                    : isCompactDesktop
                    ? 12
                    : 16,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide =
                        !isCompactDesktop && constraints.maxWidth >= 1040;
                    final sidebarWidth = _isSidebarExpanded
                        ? isCompactDesktop
                              ? 144.0
                              : kWorkspaceSidebarExpandedWidth
                        : kWorkspaceSidebarCollapsedWidth;
                    final sidebar = _WorkspaceSidebar(
                      projects: widget.projects,
                      selectedProject: _selectedProject,
                      selectedPageId: selectedPage.id,
                      briefPage: _briefPage,
                      pinnedPages: _pinnedPages,
                      documentPages: _documentPages,
                      isExpanded: isCompactDesktop
                          ? true
                          : !isWide || _isSidebarExpanded,
                      projectSelectorAnchorKey: _projectSelectorAnchorKey,
                      onProjectSelected: _selectProject,
                      onPageSelected: _selectPage,
                    );
                    final editor = _WorkspaceEditorPane(
                      project: _selectedProject,
                      page: selectedPage,
                      hasChanges: _hasPageChanges,
                      bookmarks: _selectedPageBookmarks,
                      pageContentController: _pageContentController,
                      pageContentFocusNode: _pageContentFocusNode,
                      onCreatePage: () {
                        unawaited(_createPage());
                      },
                      onRenamePage:
                          selectedPage.kind == _WorkspacePageKind.document
                          ? () {
                              unawaited(_renameSelectedPage());
                            }
                          : null,
                      onDuplicatePage:
                          selectedPage.kind == _WorkspacePageKind.document
                          ? () {
                              unawaited(_duplicateSelectedPage());
                            }
                          : null,
                      onDeletePage:
                          selectedPage.kind == _WorkspacePageKind.document
                          ? () {
                              unawaited(_deleteSelectedPage());
                            }
                          : null,
                      onTogglePinned:
                          selectedPage.kind == _WorkspacePageKind.document
                          ? () {
                              unawaited(_toggleSelectedPagePinned());
                            }
                          : null,
                      compactDesktop: isCompactDesktop,
                      onPageDraftChanged: () => setState(() {}),
                      onSavePage: () {
                        unawaited(_savePage());
                      },
                      onBookmarkCreated: _createBookmark,
                    );
                    final projectHub = _ProjectHubPane(
                      key: ValueKey('project-hub-${_selectedProject.id}'),
                      project: _selectedProject,
                      briefSummary: _projectBriefSummary,
                      stats: _projectStats,
                      sessions: _recentSessions,
                      sessionController: _sessionController,
                      isSessionComposerVisible: _isSessionComposerVisible,
                      isSpeechToTextAvailable: _isSpeechToTextAvailable,
                      isSpeechToTextListening: _isSpeechToTextListening,
                      liveSessionTranscript: _liveSessionTranscript,
                      recapTaskCandidates: _recapTaskCandidates,
                      selectedRecapTaskCandidates: _selectedRecapTaskCandidates,
                      onShowSessionComposer: _showSessionComposer,
                      onToggleSpeechToText: () {
                        unawaited(_toggleSpeechToText());
                      },
                      onRecapChanged: _handleRecapChanged,
                      onSaveRecap: () {
                        unawaited(_saveSessionRecap());
                      },
                      onExtractTasksFromRecap: _extractTasksFromRecap,
                      onToggleRecapTaskCandidate: _toggleRecapTaskCandidate,
                      onAddSelectedRecapTasks: () {
                        unawaited(_addTasksFromRecap());
                      },
                      onCompleteNextStep: (step) {
                        unawaited(_completeNextStep(step));
                      },
                      completingSteps: _completingNextSteps,
                    );
                    final mainPanel = _MainPanelFlipSwitcher(
                      showProjectHub: _isShowingProjectHub,
                      editor: editor,
                      projectHub: projectHub,
                    );

                    if (isWide) {
                      final switchedMainPanel =
                          _ProjectWorkspaceSwitchTransition(
                            key: ValueKey(
                              'project-shell-${_selectedProject.id}',
                            ),
                            shellKey: _projectWorkspaceShellKey,
                            primaryAnchorKey: _projectTitleAnchorKey,
                            fallbackAnchorKey: _projectSelectorAnchorKey,
                            animation: _projectSwitchController,
                            enabled: _projectSwitchController.isAnimating,
                            child: mainPanel,
                          );
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            duration: kProjectsQuickAnimation,
                            curve: Curves.easeOutCubic,
                            width: sidebarWidth,
                            child: sidebar,
                          ),
                          const SizedBox(width: 20),
                          Expanded(child: switchedMainPanel),
                        ],
                      );
                    }

                    final switchedMainPanel = _ProjectWorkspaceSwitchTransition(
                      key: ValueKey('project-shell-${_selectedProject.id}'),
                      shellKey: _projectWorkspaceShellKey,
                      primaryAnchorKey: _projectTitleAnchorKey,
                      fallbackAnchorKey: _projectSelectorAnchorKey,
                      animation: _projectSwitchController,
                      enabled: _projectSwitchController.isAnimating,
                      child: mainPanel,
                    );

                    if (isCompactDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: kWorkspaceSidebarCollapsedWidth,
                            child: _WorkspaceSidebar(
                              projects: widget.projects,
                              selectedProject: _selectedProject,
                              selectedPageId: selectedPage.id,
                              briefPage: _briefPage,
                              pinnedPages: _pinnedPages,
                              documentPages: _documentPages,
                              isExpanded: false,
                              projectSelectorAnchorKey:
                                  _projectSelectorAnchorKey,
                              onProjectSelected: _selectProject,
                              onPageSelected: _selectPage,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: switchedMainPanel),
                        ],
                      );
                    }

                    if (isMobileLayout) {
                      return switchedMainPanel;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 300, child: sidebar),
                        const SizedBox(height: 16),
                        Expanded(child: switchedMainPanel),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.project,
    required this.page,
    required this.hasUnsavedChanges,
    required this.isShowingProjectHub,
    required this.isSidebarExpanded,
    required this.isAssistantDrawerOpen,
    required this.projectSwitchAnimation,
    required this.isProjectSwitchAnimating,
    required this.projectTitleAnchorKey,
    required this.isMobileLayout,
    required this.isCompactDesktop,
    required this.onProjectNamePressed,
    required this.onOpenNavigatorSheet,
    required this.onNewPage,
    required this.onDeleteProject,
    required this.onToggleAssistantDrawer,
    required this.onToggleSidebar,
  });

  final Project project;
  final _WorkspacePage page;
  final bool hasUnsavedChanges;
  final bool isShowingProjectHub;
  final bool isSidebarExpanded;
  final bool isAssistantDrawerOpen;
  final Animation<double> projectSwitchAnimation;
  final bool isProjectSwitchAnimating;
  final GlobalKey projectTitleAnchorKey;
  final bool isMobileLayout;
  final bool isCompactDesktop;
  final VoidCallback onProjectNamePressed;
  final VoidCallback onOpenNavigatorSheet;
  final VoidCallback onNewPage;
  final VoidCallback onDeleteProject;
  final VoidCallback onToggleAssistantDrawer;
  final VoidCallback onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final breadcrumb = isShowingProjectHub
        ? 'Projects / ${project.title} / Project Hub'
        : 'Projects / ${project.title} / ${page.title}';

    Widget projectTitleButton = KeyedSubtree(
      key: projectTitleAnchorKey,
      child: InkWell(
        key: const ValueKey('project-hub-toggle'),
        onTap: onProjectNamePressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isShowingProjectHub
                    ? Icons.flip_to_front_rounded
                    : Icons.flip_to_back_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );

    if (isProjectSwitchAnimating) {
      projectTitleButton = AnimatedBuilder(
        animation: projectSwitchAnimation,
        child: projectTitleButton,
        builder: (context, child) {
          final pulse = math
              .sin(projectSwitchAnimation.value * math.pi)
              .clamp(0.0, 1.0);
          final scale = lerpDouble(1.0, 1.016, pulse)!;
          final highlightOpacity = lerpDouble(0.0, 0.12, pulse)!;
          return Transform.scale(
            scale: scale,
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.tintedSurface(
                  colorScheme.surface,
                  colorScheme.primary,
                  amount: Theme.of(context).brightness == Brightness.dark
                      ? 0.18
                      : 0.08,
                ).withValues(alpha: highlightOpacity),
                borderRadius: BorderRadius.circular(14),
              ),
              child: child,
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useMobileTopBar = isMobileLayout || constraints.maxWidth < 760;

        if (isCompactDesktop) {
          return Row(
            children: [
              IconButton(
                tooltip: 'Project pages',
                onPressed: onOpenNavigatorSheet,
                icon: const Icon(Icons.menu_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(child: projectTitleButton),
                        const SizedBox(width: 8),
                        Flexible(child: StatusChip(status: project.status)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isShowingProjectHub ? 'Project hub' : page.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasUnsavedChanges)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.circle,
                    size: 9,
                    color: colorScheme.primary,
                  ),
                ),
              Tooltip(
                message: 'New page',
                child: IconButton(
                  onPressed: onNewPage,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              const SizedBox(width: 4),
              FilledButton(
                key: const ValueKey('assistant-drawer-button'),
                onPressed: onToggleAssistantDrawer,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Icon(
                  isAssistantDrawerOpen
                      ? Icons.auto_awesome_motion_rounded
                      : Icons.auto_awesome_outlined,
                  size: 18,
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Project actions',
                onSelected: (value) {
                  switch (value) {
                    case 'hub':
                      onProjectNamePressed();
                      return;
                    case 'delete-project':
                      onDeleteProject();
                      return;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'hub',
                    child: Text(
                      isShowingProjectHub ? 'Open editor' : 'Open project hub',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete-project',
                    child: Text(
                      'Delete project',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          );
        }
        if (useMobileTopBar) {
          return Row(
            children: [
              IconButton(
                key: const ValueKey('mobile-workspace-navigator'),
                tooltip: 'Project pages',
                onPressed: onOpenNavigatorSheet,
                icon: const Icon(Icons.menu_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isShowingProjectHub ? 'Project hub' : page.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasUnsavedChanges)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.circle,
                    size: 10,
                    color: colorScheme.primary,
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'More actions',
                onSelected: (value) {
                  switch (value) {
                    case 'pages':
                      onOpenNavigatorSheet();
                      return;
                    case 'hub':
                      onProjectNamePressed();
                      return;
                    case 'assistant':
                      onToggleAssistantDrawer();
                      return;
                    case 'new-page':
                      onNewPage();
                      return;
                    case 'delete-project':
                      onDeleteProject();
                      return;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'pages',
                    child: Text('Project pages'),
                  ),
                  PopupMenuItem<String>(
                    value: 'hub',
                    child: Text(
                      isShowingProjectHub ? 'Open editor' : 'Open project hub',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'assistant',
                    child: Text(
                      isAssistantDrawerOpen ? 'Hide AI panel' : 'Open AI panel',
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'new-page',
                    child: Text('New page'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete-project',
                    child: Text(
                      'Delete project',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          );
        }

        return Row(
          children: [
            IconButton(
              tooltip: isSidebarExpanded
                  ? 'Collapse sidebar'
                  : 'Expand sidebar',
              onPressed: onToggleSidebar,
              icon: Icon(
                isSidebarExpanded
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    breadcrumb,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(child: projectTitleButton),
                      const SizedBox(width: 10),
                      StatusChip(status: project.status),
                      if (isShowingProjectHub) ...[
                        const SizedBox(width: 10),
                        Text(
                          'Project Hub',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  'Unsaved changes',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: onNewPage,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Page'),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Project actions',
              onSelected: (value) {
                switch (value) {
                  case 'hub':
                    onProjectNamePressed();
                    return;
                  case 'new-page':
                    onNewPage();
                    return;
                  case 'delete-project':
                    onDeleteProject();
                    return;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'hub',
                  child: Text(
                    isShowingProjectHub ? 'Open editor' : 'Open project hub',
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'new-page',
                  child: Text('New page'),
                ),
                PopupMenuItem<String>(
                  value: 'delete-project',
                  child: Text(
                    'Delete project',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
              icon: const Icon(Icons.more_horiz_rounded),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const ValueKey('assistant-drawer-button'),
              onPressed: onToggleAssistantDrawer,
              icon: Icon(
                isAssistantDrawerOpen
                    ? Icons.auto_awesome_motion_rounded
                    : Icons.auto_awesome_outlined,
              ),
              label: const Text('AI'),
            ),
          ],
        );
      },
    );
  }
}

class _WorkspaceEditorPane extends StatelessWidget {
  const _WorkspaceEditorPane({
    required this.project,
    required this.page,
    required this.hasChanges,
    required this.bookmarks,
    required this.pageContentController,
    required this.pageContentFocusNode,
    required this.onCreatePage,
    required this.onPageDraftChanged,
    required this.onSavePage,
    required this.onBookmarkCreated,
    this.compactDesktop = false,
    this.onRenamePage,
    this.onDuplicatePage,
    this.onDeletePage,
    this.onTogglePinned,
  });

  final Project project;
  final _WorkspacePage page;
  final bool hasChanges;
  final List<DocumentBookmark> bookmarks;
  final TextEditingController pageContentController;
  final FocusNode pageContentFocusNode;
  final VoidCallback onCreatePage;
  final VoidCallback onPageDraftChanged;
  final VoidCallback onSavePage;
  final BookmarkCreateCallback onBookmarkCreated;
  final bool compactDesktop;
  final VoidCallback? onRenamePage;
  final VoidCallback? onDuplicatePage;
  final VoidCallback? onDeletePage;
  final VoidCallback? onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final metaLabels = <String>[
      _formatTimestamp(page.updatedAt),
      if (page.kind == _WorkspacePageKind.document &&
          page.document?.type != null)
        page.document!.type.label,
      if (page.isPinned) 'Pinned',
    ];

    return ProjectPageEditor(
      pageId: page.id,
      pageTitle: page.title,
      contentController: pageContentController,
      contentFocusNode: pageContentFocusNode,
      bookmarks: bookmarks,
      hasChanges: hasChanges,
      pageKindLabel: page.kind == _WorkspacePageKind.brief
          ? 'Brief page'
          : 'Document page',
      metaLabels: metaLabels,
      storageFormat: page.kind == _WorkspacePageKind.brief
          ? ProjectPageStorageFormat.markdown
          : ProjectPageStorageFormat.richTextJson,
      onCreatePage: onCreatePage,
      onRenamePage: onRenamePage,
      onDuplicatePage: onDuplicatePage,
      onDeletePage: onDeletePage,
      onTogglePinned: onTogglePinned,
      isPinned: page.isPinned,
      onPageDraftChanged: onPageDraftChanged,
      onSavePage: onSavePage,
      onBookmarkCreated: onBookmarkCreated,
      compactDesktop: compactDesktop,
    );
  }
}

class _WorkspaceSidebar extends StatelessWidget {
  const _WorkspaceSidebar({
    required this.projects,
    required this.selectedProject,
    required this.selectedPageId,
    required this.briefPage,
    required this.pinnedPages,
    required this.documentPages,
    required this.isExpanded,
    required this.projectSelectorAnchorKey,
    required this.onProjectSelected,
    required this.onPageSelected,
  });

  final List<Project> projects;
  final Project selectedProject;
  final String selectedPageId;
  final _WorkspacePage briefPage;
  final List<_WorkspacePage> pinnedPages;
  final List<_WorkspacePage> documentPages;
  final bool isExpanded;
  final GlobalKey projectSelectorAnchorKey;
  final ValueChanged<Project> onProjectSelected;
  final ValueChanged<_WorkspacePage> onPageSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedProject.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      PopupMenuButton<Project>(
                        tooltip: 'Switch project',
                        onSelected: onProjectSelected,
                        itemBuilder: (context) => [
                          for (final project in projects)
                            PopupMenuItem<Project>(
                              value: project,
                              child: Text(project.title),
                            ),
                        ],
                        child: Container(
                          key: projectSelectorAnchorKey,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.tintedSurface(
                              colorScheme.surface,
                              colorScheme.primary,
                              amount: isDark ? 0.12 : 0.04,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_copy_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedProject.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: PopupMenuButton<Project>(
                      tooltip: 'Switch project',
                      onSelected: onProjectSelected,
                      itemBuilder: (context) => [
                        for (final project in projects)
                          PopupMenuItem<Project>(
                            value: project,
                            child: Text(project.title),
                          ),
                      ],
                      child: CircleAvatar(
                        key: projectSelectorAnchorKey,
                        radius: 22,
                        backgroundColor: AppTheme.tintedSurface(
                          colorScheme.surface,
                          colorScheme.primary,
                          amount: isDark ? 0.24 : 0.12,
                        ),
                        child: Text(
                          selectedProject.title.characters.first.toUpperCase(),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                _WorkspacePageSection(
                  title: 'Brief',
                  visible: isExpanded,
                  pages: [briefPage],
                  selectedPageId: selectedPageId,
                  onPageSelected: onPageSelected,
                ),
                if (pinnedPages.isNotEmpty)
                  _WorkspacePageSection(
                    title: 'Pinned',
                    visible: isExpanded,
                    pages: pinnedPages,
                    selectedPageId: selectedPageId,
                    onPageSelected: onPageSelected,
                  ),
                _WorkspacePageSection(
                  title: 'Documents',
                  visible: isExpanded,
                  pages: documentPages,
                  selectedPageId: selectedPageId,
                  onPageSelected: onPageSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspacePageSection extends StatelessWidget {
  const _WorkspacePageSection({
    required this.title,
    required this.visible,
    required this.pages,
    required this.selectedPageId,
    required this.onPageSelected,
  });

  final String title;
  final bool visible;
  final List<_WorkspacePage> pages;
  final String selectedPageId;
  final ValueChanged<_WorkspacePage> onPageSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final page in pages)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _WorkspacePageTile(
                page: page,
                isSelected: selectedPageId == page.id,
                isExpanded: visible,
                onTap: () => onPageSelected(page),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkspacePageTile extends StatelessWidget {
  const _WorkspacePageTile({
    required this.page,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  final _WorkspacePage page;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('page-nav-${page.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? 8 : 6,
            vertical: isExpanded ? 8 : 7,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.tintedSurface(
                    colorScheme.surface,
                    colorScheme.primary,
                    amount: isDark ? 0.22 : 0.1,
                  )
                : AppTheme.tintedSurface(
                    colorScheme.surface,
                    colorScheme.primary,
                    amount: isDark ? 0.1 : 0.03,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: isDark ? 0.46 : 0.24)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                _iconForPage(page),
                size: 18,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              if (isExpanded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    page.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectWorkspaceSwitchTransition extends StatelessWidget {
  const _ProjectWorkspaceSwitchTransition({
    super.key,
    required this.shellKey,
    required this.primaryAnchorKey,
    required this.fallbackAnchorKey,
    required this.animation,
    required this.enabled,
    required this.child,
  });

  final GlobalKey shellKey;
  final GlobalKey primaryAnchorKey;
  final GlobalKey fallbackAnchorKey;
  final Animation<double> animation;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: shellKey,
      child: IgnorePointer(
        ignoring: enabled,
        child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            if (!enabled || child == null) {
              return child ?? const SizedBox.shrink();
            }

            final shellBox = shellKey.currentContext?.findRenderObject();
            final anchorGlobal =
                _globalCenterFor(primaryAnchorKey) ??
                _globalCenterFor(fallbackAnchorKey);
            if (shellBox is! RenderBox ||
                !shellBox.hasSize ||
                anchorGlobal == null) {
              return child;
            }

            final shellSize = shellBox.size;
            final shellTopLeft = shellBox.localToGlobal(Offset.zero);
            final shellCenter = shellTopLeft + shellSize.center(Offset.zero);
            final centerToAnchor = anchorGlobal - shellCenter;
            final direction = _normalizedDirection(centerToAnchor);
            final directionalOffset = direction * _kProjectSwitchMaxTranslation;

            final progress = animation.value.clamp(0.0, 1.0);
            final outgoingPhase = (progress / 0.45).clamp(0.0, 1.0);
            final incomingPhase = ((progress - 0.55) / 0.45).clamp(0.0, 1.0);

            double scale;
            double opacity;
            Offset offset;

            if (progress <= 0.45) {
              final curved = Curves.easeInCubic.transform(outgoingPhase);
              scale = lerpDouble(1.0, _kProjectSwitchOutgoingScale, curved)!;
              opacity = lerpDouble(1.0, 0.0, curved)!;
              offset = Offset.lerp(Offset.zero, directionalOffset, curved)!;
            } else if (progress < 0.55) {
              final isOutgoingHold = progress < 0.5;
              scale = isOutgoingHold
                  ? _kProjectSwitchOutgoingScale
                  : _kProjectSwitchIncomingScale;
              opacity = 0.0;
              offset = directionalOffset;
            } else {
              final curved = Curves.easeOutCubic.transform(incomingPhase);
              scale = lerpDouble(_kProjectSwitchIncomingScale, 1.0, curved)!;
              opacity = lerpDouble(0.0, 1.0, curved)!;
              offset = Offset.lerp(directionalOffset, Offset.zero, curved)!;
            }

            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: offset,
                child: Transform.scale(
                  alignment: _kProjectSwitchAlignment,
                  scale: scale,
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Offset? _globalCenterFor(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
  }

  Offset _normalizedDirection(Offset vector) {
    final distance = vector.distance;
    if (distance <= 0.001) {
      return const Offset(-0.72, -0.68);
    }

    return Offset(vector.dx / distance, vector.dy / distance);
  }
}

class _MainPanelFlipSwitcher extends StatelessWidget {
  const _MainPanelFlipSwitcher({
    required this.showProjectHub,
    required this.editor,
    required this.projectHub,
  });

  final bool showProjectHub;
  final Widget editor;
  final Widget projectHub;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedSwitcher(
      duration: reduceMotion
          ? const Duration(milliseconds: 120)
          : const Duration(milliseconds: 360),
      reverseDuration: reduceMotion
          ? const Duration(milliseconds: 90)
          : const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            ...(currentChild != null
                ? <Widget>[currentChild]
                : const <Widget>[]),
          ],
        );
      },
      transitionBuilder: (child, animation) {
        if (reduceMotion) {
          return FadeTransition(opacity: animation, child: child);
        }

        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final curved = Curves.easeInOutCubic.transform(animation.value);
            final rotation = (1 - curved) * (math.pi / 2);
            final scale = 0.98 + (curved * 0.02);
            return Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(rotation)
                  ..scaleByDouble(scale, scale, 1, 1),
                child: child,
              ),
            );
          },
        );
      },
      child: KeyedSubtree(
        key: ValueKey(showProjectHub ? 'project-hub' : 'editor'),
        child: showProjectHub ? projectHub : editor,
      ),
    );
  }
}

class _ProjectHubPane extends StatelessWidget {
  const _ProjectHubPane({
    super.key,
    required this.project,
    required this.briefSummary,
    required this.stats,
    required this.sessions,
    required this.sessionController,
    required this.isSessionComposerVisible,
    required this.isSpeechToTextAvailable,
    required this.isSpeechToTextListening,
    required this.liveSessionTranscript,
    required this.recapTaskCandidates,
    required this.selectedRecapTaskCandidates,
    required this.onShowSessionComposer,
    required this.onToggleSpeechToText,
    required this.onRecapChanged,
    required this.onSaveRecap,
    required this.onExtractTasksFromRecap,
    required this.onToggleRecapTaskCandidate,
    required this.onAddSelectedRecapTasks,
    required this.onCompleteNextStep,
    required this.completingSteps,
  });

  final Project project;
  final String briefSummary;
  final _ProjectStats stats;
  final List<SessionNote> sessions;
  final TextEditingController sessionController;
  final bool isSessionComposerVisible;
  final bool isSpeechToTextAvailable;
  final bool isSpeechToTextListening;
  final String liveSessionTranscript;
  final List<String> recapTaskCandidates;
  final Set<String> selectedRecapTaskCandidates;
  final VoidCallback onShowSessionComposer;
  final VoidCallback onToggleSpeechToText;
  final ValueChanged<String> onRecapChanged;
  final VoidCallback onSaveRecap;
  final VoidCallback onExtractTasksFromRecap;
  final ValueChanged<String> onToggleRecapTaskCandidate;
  final VoidCallback onAddSelectedRecapTasks;
  final ValueChanged<String> onCompleteNextStep;
  final Set<String> completingSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final paiColors = context.paiColors;
    final isDark = theme.brightness == Brightness.dark;
    final isMobileLayout = MediaQuery.sizeOf(context).width < 900;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = isMobileLayout
            ? (constraints.maxWidth * 0.9)
                  .clamp(0.0, constraints.maxWidth)
                  .toDouble()
            : constraints.maxWidth;
        final shellPadding = isMobileLayout
            ? const EdgeInsets.fromLTRB(14, 14, 14, 16)
            : const EdgeInsets.fromLTRB(28, 26, 28, 26);
        final sectionPadding = isMobileLayout
            ? const EdgeInsets.all(16)
            : const EdgeInsets.all(20);

        Widget buildSpeechButton() {
          return OutlinedButton.icon(
            key: const ValueKey('project-hub-speech-button'),
            onPressed: onToggleSpeechToText,
            icon: Icon(
              isSpeechToTextListening
                  ? Icons.mic_rounded
                  : Icons.mic_none_rounded,
              color: isSpeechToTextListening ? colorScheme.error : null,
            ),
            label: Text(
              isSpeechToTextListening
                  ? 'Listening'
                  : isSpeechToTextAvailable
                  ? 'Dictate'
                  : 'Dictation unavailable',
            ),
          );
        }

        final recordSessionButton = isMobileLayout
            ? SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('project-hub-record-session'),
                  onPressed: onShowSessionComposer,
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(
                    isSessionComposerVisible
                        ? 'Recording In Progress'
                        : 'Record Session',
                  ),
                ),
              )
            : FilledButton.icon(
                key: const ValueKey('project-hub-record-session'),
                onPressed: onShowSessionComposer,
                icon: const Icon(Icons.mic_rounded),
                label: Text(
                  isSessionComposerVisible
                      ? 'Recording In Progress'
                      : 'Record Session',
                ),
              );

        return Container(
          key: const ValueKey('project-hub-view'),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(isMobileLayout ? 24 : 28),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: paiColors.panelShadow.withValues(
                  alpha: isDark ? 0.18 : 0.08,
                ),
                blurRadius: isMobileLayout ? 18 : 24,
                offset: Offset(0, isMobileLayout ? 10 : 14),
              ),
            ],
          ),
          child: Padding(
            padding: shellPadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
                  ),
                  children: [
                    if (!isMobileLayout) ...[
                      Text(
                        'Project Hub',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sessions and recordings live here, separate from the page editor and separate from the assistant.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Container(
                      padding: sectionPadding,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.tintedSurface(
                              colorScheme.surface,
                              colorScheme.primary,
                              amount: isDark ? 0.16 : 0.04,
                            ),
                            AppTheme.tintedSurface(
                              colorScheme.surface,
                              colorScheme.secondary,
                              amount: isDark ? 0.14 : 0.03,
                            ),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.tintedSurface(
                                    colorScheme.surface,
                                    colorScheme.primary,
                                    amount: isDark ? 0.24 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.mic_none_rounded,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Record Session',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    if (!isMobileLayout) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Capture a session note, save it to this project, and optionally turn it into next steps.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          recordSessionButton,
                          if (isSessionComposerVisible) ...[
                            const SizedBox(height: 16),
                            if (isMobileLayout)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'What happened',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  buildSpeechButton(),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Text(
                                    'What happened',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  buildSpeechButton(),
                                ],
                              ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey('project-hub-session-field'),
                              controller: sessionController,
                              minLines: isMobileLayout ? 5 : 4,
                              maxLines: isMobileLayout ? 10 : 8,
                              onChanged: onRecapChanged,
                              decoration: const InputDecoration(
                                hintText: 'What happened in this session?',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (isSpeechToTextListening ||
                                liveSessionTranscript.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: paiColors.warningSurface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: paiColors.warningBorder,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        isSpeechToTextListening
                                            ? Icons.graphic_eq_rounded
                                            : Icons.subtitles_outlined,
                                        size: 18,
                                        color: paiColors.warningForeground,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          liveSessionTranscript.isEmpty
                                              ? 'Listening for dictation...'
                                              : liveSessionTranscript,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    paiColors.warningForeground,
                                                fontStyle:
                                                    liveSessionTranscript
                                                        .isEmpty
                                                    ? FontStyle.italic
                                                    : FontStyle.normal,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: onSaveRecap,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Save session'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: onExtractTasksFromRecap,
                                  icon: const Icon(Icons.auto_fix_high_rounded),
                                  label: const Text('Extract tasks'),
                                ),
                              ],
                            ),
                            if (recapTaskCandidates.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _RecapTaskReview(
                                tasks: recapTaskCandidates,
                                selectedTasks: selectedRecapTaskCandidates,
                                onToggleTask: onToggleRecapTaskCandidate,
                                onAddSelectedTasks: onAddSelectedRecapTasks,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DrawerSection(
                      title: 'Recent Sessions',
                      child: _RecentSessionsSection(sessions: sessions),
                    ),
                    _DrawerSection(
                      title: 'Project Summary',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(briefSummary),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaPill(
                                icon: Icons.description_outlined,
                                label: '${stats.pageCount} pages',
                              ),
                              _MetaPill(
                                icon: Icons.push_pin_outlined,
                                label: '${stats.pinnedCount} pinned',
                              ),
                              _MetaPill(
                                icon: Icons.text_fields_rounded,
                                label: '${stats.totalWordCount} words',
                              ),
                              _MetaPill(
                                icon: Icons.schedule_rounded,
                                label: _formatTimestamp(stats.lastEdited),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (project.nextSteps.isNotEmpty)
                      _DrawerSection(
                        title: 'Current Next Steps',
                        child: Column(
                          children: [
                            for (final step in project.nextSteps.take(4))
                              _NextStepTile(
                                step: step,
                                isCompleting: completingSteps.contains(step),
                                onCompleted: () => onCompleteNextStep(step),
                              ),
                          ],
                        ),
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

class _WorkspaceDrawer extends StatelessWidget {
  const _WorkspaceDrawer({
    required this.questionController,
    required this.assistantReply,
    required this.onAsk,
    required this.onClose,
  });

  final TextEditingController questionController;
  final String assistantReply;
  final VoidCallback onAsk;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Assistant',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(
              key: const ValueKey('assistant-drawer-close'),
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              _DrawerSection(
                title: 'Ask',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const ValueKey('assistant-question-field'),
                      controller: questionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Ask about this project or page',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: onAsk,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Ask assistant'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      assistantReply,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.tintedSurface(
          colorScheme.surface,
          colorScheme.primary,
          amount: isDark ? 0.1 : 0.03,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _NextStepTile extends StatelessWidget {
  const _NextStepTile({
    required this.step,
    required this.isCompleting,
    required this.onCompleted,
  });

  final String step;
  final bool isCompleting;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: isCompleting ? null : onCompleted,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isCompleting,
                onChanged: isCompleting ? null : (_) => onCompleted(),
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(step)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSessionsSection extends StatelessWidget {
  const _RecentSessionsSection({required this.sessions});

  final List<SessionNote> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Text('No sessions yet.');
    }

    return Column(
      children: [
        for (final session in sessions.take(6))
          _SessionEntryCard(session: session),
      ],
    );
  }
}

class _SessionEntryCard extends StatelessWidget {
  const _SessionEntryCard({required this.session});

  final SessionNote session;

  @override
  Widget build(BuildContext context) {
    final isCompletion = session.type == SessionNoteType.completion;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCompletion
          ? AppTheme.tintedSurface(
              colorScheme.surface,
              colorScheme.primary,
              amount: isDark ? 0.16 : 0.06,
            )
          : colorScheme.surface,
      child: ListTile(
        dense: true,
        leading: Icon(
          isCompletion ? Icons.task_alt_rounded : Icons.notes_rounded,
          color: isCompletion
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        title: Text(session.summary),
        subtitle: Text(session.dateLabel),
      ),
    );
  }
}

class _RecapTaskReview extends StatelessWidget {
  const _RecapTaskReview({
    required this.tasks,
    required this.selectedTasks,
    required this.onToggleTask,
    required this.onAddSelectedTasks,
  });

  final List<String> tasks;
  final Set<String> selectedTasks;
  final ValueChanged<String> onToggleTask;
  final VoidCallback onAddSelectedTasks;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Candidate tasks',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final task in tasks)
            CheckboxListTile(
              value: selectedTasks.contains(task),
              onChanged: (_) => onToggleTask(task),
              title: Text(task),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAddSelectedTasks,
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Add selected tasks'),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.tintedSurface(
          colorScheme.surface,
          colorScheme.primary,
          amount: isDark ? 0.12 : 0.02,
        ),
        borderRadius: BorderRadius.circular(999),
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

enum _WorkspacePageKind { brief, document }

class _WorkspacePage {
  const _WorkspacePage({
    required this.id,
    required this.projectId,
    required this.title,
    required this.content,
    required this.kind,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    this.document,
  });

  factory _WorkspacePage.fromDocument(ProjectDocument document) {
    return _WorkspacePage(
      id: document.id,
      projectId: document.projectId,
      title: document.title,
      content: document.content,
      kind: _WorkspacePageKind.document,
      isPinned: document.pinned,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
      document: document,
    );
  }

  final String id;
  final String projectId;
  final String title;
  final String content;
  final _WorkspacePageKind kind;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProjectDocument? document;
}

class _ProjectStats {
  const _ProjectStats({
    required this.pageCount,
    required this.pinnedCount,
    required this.totalWordCount,
    required this.lastEdited,
  });

  final int pageCount;
  final int pinnedCount;
  final int totalWordCount;
  final DateTime lastEdited;
}

IconData _iconForPage(_WorkspacePage page) {
  if (page.kind == _WorkspacePageKind.brief) {
    return Icons.assignment_outlined;
  }

  if (page.isPinned) {
    return Icons.push_pin_outlined;
  }

  return switch (page.document?.type) {
    ProjectDocumentType.design => Icons.palette_outlined,
    ProjectDocumentType.implementation => Icons.code_rounded,
    ProjectDocumentType.story => Icons.auto_stories_outlined,
    ProjectDocumentType.research => Icons.search_rounded,
    ProjectDocumentType.reference => Icons.menu_book_rounded,
    null => Icons.description_outlined,
  };
}

String _formatTimestamp(DateTime value) {
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

String _briefWithCompletionUpdate(
  String currentBrief, {
  required String completedStep,
  required int remainingSteps,
}) {
  const marker = ' Progress update: ';
  final markdown = currentBrief.trim();
  final markerIndex = markdown.indexOf(marker);
  final baseBrief = markerIndex >= 0
      ? markdown.substring(0, markerIndex).trim()
      : markdown;
  final remainingLabel = remainingSteps == 1 ? 'next step' : 'next steps';
  final update = remainingSteps <= 0
      ? 'Completed "$completedStep". All tracked next steps are done for now.'
      : 'Completed "$completedStep". $remainingSteps $remainingLabel still active.';
  return '$baseBrief$marker$update';
}
