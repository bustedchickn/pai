import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/document_bookmark.dart';
import '../models/project.dart';
import '../models/project_document.dart';
import '../models/session_note.dart';
import '../services/browser_speech_to_text.dart';
import '../services/project_document_content_codec.dart';
import '../widgets/project_page_editor.dart';
import '../widgets/status_chip.dart';

const Duration kProjectsQuickAnimation = Duration(milliseconds: 220);
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

class _ProjectWorkspaceViewState extends State<ProjectWorkspaceView> {
  final GlobalKey<ScaffoldState> _assistantDrawerScaffoldKey =
      GlobalKey<ScaffoldState>();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _sessionController = TextEditingController();
  final TextEditingController _pageContentController = TextEditingController();
  final FocusNode _pageContentFocusNode = FocusNode();
  late final BrowserSpeechToText _speechToText = createBrowserSpeechToText();
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

    _selectedProject = _projectForId(widget.selectedProjectId);
    _resetProjectScopedUi();
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
    if (project.id == _selectedProject.id) {
      return;
    }

    setState(() {
      _selectedProject = project;
      _resetProjectScopedUi();
      _loadPageIntoEditor(_defaultPageForProject());
    });
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
          content: Text('Speech-to-text is not available in this browser.'),
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
    final needsLeadingSpace = before.isNotEmpty &&
        !RegExp(r'[\s(\[{]$').hasMatch(before);
    final needsTrailingSpace =
        after.isNotEmpty && !RegExp(r'^[\s,.;:!?)]').hasMatch(after);
    final inserted = '${needsLeadingSpace ? ' ' : ''}$text'
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
      final updatedProject = _selectedProject.copyWith(
        brief: _pageContentController.text,
        updatedAt: DateTime.now(),
        lastOpenedPageId: selectedPage.id,
      );
      setState(() => _selectedProject = updatedProject);
      await widget.onProjectSaved(updatedProject);
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
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
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
      selectedPage.document!.copyWith(title: nextTitle, updatedAt: DateTime.now()),
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
      final updatedProject = _selectedProject.copyWith(updatedAt: DateTime.now());
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
    final candidates = _extractRecapTaskCandidates(_sessionController.text);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No task-like lines found yet. Try bullets or action phrasing.',
          ),
        ),
      );
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
    final selectedPage = _selectedPage ?? _defaultPageForProject();
    final assistantPane = _WorkspaceDrawer(
      questionController: _questionController,
      assistantReply: _assistantReply,
      onAsk: _askAssistant,
      onClose: _closeAssistantDrawer,
    );

    return SafeArea(
      child: Scaffold(
        key: _assistantDrawerScaffoldKey,
        backgroundColor: Colors.transparent,
        endDrawerEnableOpenDragGesture: false,
        onEndDrawerChanged: (isOpen) {
          if (_isAssistantDrawerOpen != isOpen) {
            setState(() => _isAssistantDrawerOpen = isOpen);
          }
        },
        endDrawer: SizedBox(
          width: _assistantDrawerWidth(context),
          child: Drawer(
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
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _WorkspaceTopBar(
                project: _selectedProject,
                page: selectedPage,
                hasUnsavedChanges: _hasPageChanges,
                isShowingProjectHub: _isShowingProjectHub,
                isSidebarExpanded: _isSidebarExpanded,
                isAssistantDrawerOpen: _isAssistantDrawerOpen,
                onProjectNamePressed: _toggleProjectHub,
                onNewPage: () {
                  unawaited(_createPage());
                },
                onToggleAssistantDrawer: _toggleAssistantDrawer,
                onToggleSidebar: () {
                  setState(() => _isSidebarExpanded = !_isSidebarExpanded);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1040;
                    final sidebarWidth = _isSidebarExpanded
                        ? kWorkspaceSidebarExpandedWidth
                        : kWorkspaceSidebarCollapsedWidth;
                    final sidebar = _WorkspaceSidebar(
                      projects: widget.projects,
                      selectedProject: _selectedProject,
                      selectedPageId: selectedPage.id,
                      briefPage: _briefPage,
                      pinnedPages: _pinnedPages,
                      documentPages: _documentPages,
                      isExpanded: !isWide || _isSidebarExpanded,
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
                      onRenamePage: selectedPage.kind == _WorkspacePageKind.document
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
                      onDeletePage: selectedPage.kind == _WorkspacePageKind.document
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
                      selectedRecapTaskCandidates:
                          _selectedRecapTaskCandidates,
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
                          Expanded(child: mainPanel),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        SizedBox(height: 300, child: sidebar),
                        const SizedBox(height: 16),
                        Expanded(child: mainPanel),
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
    required this.onProjectNamePressed,
    required this.onNewPage,
    required this.onToggleAssistantDrawer,
    required this.onToggleSidebar,
  });

  final Project project;
  final _WorkspacePage page;
  final bool hasUnsavedChanges;
  final bool isShowingProjectHub;
  final bool isSidebarExpanded;
  final bool isAssistantDrawerOpen;
  final VoidCallback onProjectNamePressed;
  final VoidCallback onNewPage;
  final VoidCallback onToggleAssistantDrawer;
  final VoidCallback onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: isSidebarExpanded ? 'Collapse sidebar' : 'Expand sidebar',
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
                isShowingProjectHub
                    ? 'Projects / ${project.title} / Project Hub'
                    : 'Projects / ${project.title} / ${page.title}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF66758F),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: InkWell(
                      key: const ValueKey('project-hub-toggle'),
                      onTap: onProjectNamePressed,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                project.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isShowingProjectHub
                                  ? Icons.flip_to_front_rounded
                                  : Icons.flip_to_back_rounded,
                              size: 18,
                              color: const Color(0xFF5A6B88),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  StatusChip(status: project.status),
                  if (isShowingProjectHub) ...[
                    const SizedBox(width: 10),
                    Text(
                      'Project Hub',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF4767B4),
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
                color: const Color(0xFF4867B7),
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
  final ValueChanged<Project> onProjectSelected;
  final ValueChanged<_WorkspacePage> onPageSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDE4F2)),
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
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFDCE4F4)),
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
                        radius: 22,
                        backgroundColor: const Color(0xFFEAF1FF),
                        child: Text(
                          selectedProject.title.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF3256A8),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const Divider(height: 1, color: Color(0xFFE7ECF5)),
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
                  color: const Color(0xFF62718B),
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
            color: isSelected ? const Color(0xFFEFF4FF) : const Color(0xFFF9FBFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFBFD0F3)
                  : const Color(0xFFE2E8F3),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                _iconForPage(page),
                size: 18,
                color: isSelected
                    ? const Color(0xFF4169BA)
                    : const Color(0xFF677791),
              ),
              if (isExpanded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    page.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

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
            ...(currentChild != null ? <Widget>[currentChild] : const <Widget>[]),
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
    return Container(
      key: const ValueKey('project-hub-view'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDDE4F2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F94C8).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        child: ListView(
          children: [
            Text(
              'Project Hub',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sessions and recordings live here, separate from the page editor and separate from the assistant.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF61708B)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF8FBFF), Color(0xFFF2F6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD8E3F7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6EEFF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.mic_none_rounded,
                          color: Color(0xFF4268B8),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record Session',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Capture a session note, save it to this project, and optionally turn it into next steps.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF61708B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const ValueKey('project-hub-record-session'),
                    onPressed: onShowSessionComposer,
                    icon: const Icon(Icons.mic_rounded),
                    label: Text(
                      isSessionComposerVisible
                          ? 'Recording In Progress'
                          : 'Record Session',
                    ),
                  ),
                  if (isSessionComposerVisible) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'What happened',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          key: const ValueKey('project-hub-speech-button'),
                          onPressed: onToggleSpeechToText,
                          icon: Icon(
                            isSpeechToTextListening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            color: isSpeechToTextListening
                                ? const Color(0xFFC24A4A)
                                : null,
                          ),
                          label: Text(
                            isSpeechToTextListening
                                ? 'Listening'
                                : isSpeechToTextAvailable
                                ? 'Dictate'
                                : 'Speech Unavailable',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('project-hub-session-field'),
                      controller: sessionController,
                      minLines: 4,
                      maxLines: 8,
                      onChanged: onRecapChanged,
                      decoration: const InputDecoration(
                        hintText: 'What happened in this session?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (isSpeechToTextListening || liveSessionTranscript.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBF2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFF0DEC0),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isSpeechToTextListening
                                    ? Icons.graphic_eq_rounded
                                    : Icons.subtitles_outlined,
                                size: 18,
                                color: const Color(0xFF9A6B18),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  liveSessionTranscript.isEmpty
                                      ? 'Listening for speech...'
                                      : liveSessionTranscript,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF7C6125),
                                        fontStyle: liveSessionTranscript.isEmpty
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                      ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE5F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: isCompleting ? null : onCompleted,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCE4F4)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isCompleting,
                onChanged: isCompleting ? null : (_) => onCompleted(),
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
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
        for (final session in sessions.take(6)) _SessionEntryCard(session: session),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCompletion ? const Color(0xFFF5F9FF) : Colors.white,
      child: ListTile(
        dense: true,
        leading: Icon(
          isCompletion ? Icons.task_alt_rounded : Icons.notes_rounded,
          color: isCompletion
              ? const Color(0xFF3E67B8)
              : const Color(0xFF66758F),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE4F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Candidate tasks',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDE4F2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF5E6D88)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF55647D),
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

List<String> _extractRecapTaskCandidates(String recapText) {
  final rawLines = recapText
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final lineCandidates = <String>[
    for (final line in rawLines)
      if (_looksLikeRecapTask(line)) _normalizeRecapTask(line),
  ];
  if (lineCandidates.isNotEmpty) {
    return _dedupeTasks(lineCandidates);
  }

  final sentenceCandidates = recapText
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && _looksLikeRecapTask(line))
      .map(_normalizeRecapTask)
      .toList();
  return _dedupeTasks(sentenceCandidates);
}

bool _looksLikeRecapTask(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) {
    return false;
  }

  final normalized = cleaned.toLowerCase();
  if (RegExp(r'^(\-|\*|•|\[ ?\]|\d+[.)])\s+').hasMatch(cleaned)) {
    return true;
  }

  const actionPhrases = [
    'todo',
    'next',
    'need to',
    'should',
    'follow up',
    'add ',
    'build ',
    'write ',
    'refine ',
    'fix ',
    'polish ',
    'review ',
    'create ',
    'design ',
    'ship ',
    'update ',
    'investigate ',
    'test ',
    'document ',
    'prepare ',
    'send ',
    'draft ',
    'clean up ',
    'set up ',
    'implement ',
    'wire ',
    'connect ',
    'plan ',
    'clarify ',
    'move ',
    'rename ',
  ];

  return actionPhrases.any((phrase) => normalized.startsWith(phrase));
}

String _normalizeRecapTask(String text) {
  var normalized = text.trim();
  normalized = normalized.replaceFirst(
    RegExp(r'^(\-|\*|•|\[ ?\]|\d+[.)])\s*'),
    '',
  );
  normalized = normalized.replaceFirst(
    RegExp(r'^(todo|next)\s*[:\-]\s*', caseSensitive: false),
    '',
  );
  normalized = normalized.replaceFirst(
    RegExp(r'^(need to|should)\s+', caseSensitive: false),
    '',
  );
  normalized = normalized.replaceFirst(RegExp(r'[.!?]+$'), '');
  if (normalized.isEmpty) {
    return normalized;
  }

  return normalized[0].toUpperCase() + normalized.substring(1);
}

List<String> _dedupeTasks(List<String> tasks) {
  final seen = <String>{};
  final result = <String>[];
  for (final task in tasks) {
    final trimmed = task.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final key = trimmed.toLowerCase();
    if (seen.add(key)) {
      result.add(trimmed);
    }
  }
  return result;
}
