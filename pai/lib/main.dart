import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/in_memory/in_memory_document_repository.dart';
import 'data/in_memory/in_memory_pai_store.dart';
import 'data/in_memory/in_memory_project_repository.dart';
import 'data/in_memory/in_memory_session_repository.dart';
import 'data/in_memory/in_memory_task_repository.dart';
import 'firebase_options.dart';
import 'layout/app_viewport.dart';
import 'models/app_appearance_mode.dart';
import 'models/app_data_snapshot.dart';
import 'models/app_sync_state.dart';
import 'models/board_project.dart';
import 'models/document_bookmark.dart';
import 'models/new_project_draft.dart';
import 'models/project.dart';
import 'models/project_document.dart';
import 'models/session_note.dart';
import 'profile_screen.dart';
import 'projects_overview_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_audio_service.dart';
import 'services/auth_bootstrap_service.dart';
import 'services/local_snapshot_storage.dart';
import 'services/manual_sync_service.dart';
import 'services/pai_data_service.dart';
import 'services/workspace_preferences_storage.dart';
import 'stats_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/global_sync_bar.dart';
import 'widgets/new_project_dialog.dart';
import 'widgets/project_board.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final workspacePreferencesStorage = WorkspacePreferencesStorage();
  final initialAppearanceMode = await workspacePreferencesStorage
      .loadAppearanceMode();
  var useFirebase = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    useFirebase = true;
  } catch (error) {
    debugPrint('Firebase initialization skipped: $error');
  }
  runApp(
    PaiApp(
      useFirebase: useFirebase,
      initialAppearanceMode: initialAppearanceMode,
    ),
  );
}

class PaiApp extends StatefulWidget {
  const PaiApp({
    super.key,
    required this.useFirebase,
    required this.initialAppearanceMode,
  });

  final bool useFirebase;
  final AppAppearanceMode initialAppearanceMode;

  @override
  State<PaiApp> createState() => _PaiAppState();
}

class _PaiAppState extends State<PaiApp> {
  final WorkspacePreferencesStorage _workspacePreferencesStorage =
      WorkspacePreferencesStorage();
  late AppAppearanceMode _appearanceMode = widget.initialAppearanceMode;

  void _setAppearanceMode(AppAppearanceMode mode) {
    if (_appearanceMode == mode) {
      return;
    }

    setState(() => _appearanceMode = mode);
    unawaited(_workspacePreferencesStorage.saveAppearanceMode(mode));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pai',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _appearanceMode.themeMode,
      home: AppShell(
        useFirebase: widget.useFirebase,
        appearanceMode: _appearanceMode,
        onAppearanceModeChanged: _setAppearanceMode,
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.useFirebase,
    required this.appearanceMode,
    required this.onAppearanceModeChanged,
  });

  final bool useFirebase;
  final AppAppearanceMode appearanceMode;
  final ValueChanged<AppAppearanceMode> onAppearanceModeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  int _mobileTabIndex = 0;

  final WorkspacePreferencesStorage _workspacePreferencesStorage =
      WorkspacePreferencesStorage();
  final LocalSnapshotStorage _localSnapshotStorage = LocalSnapshotStorage();
  final InMemoryPaiStore _store = InMemoryPaiStore();
  final AppAudioService _audioService = AppAudioService();
  late final AuthBootstrapService _authBootstrapService;
  late final PaiDataService _dataService;
  late final ManualSyncService _manualSyncService;

  List<Project> projects = const [];
  List<BoardProject> boardProjects = const [];
  List<ProjectDocument> documents = const [];
  List<DocumentBookmark> bookmarks = const [];
  bool _isLoading = true;
  bool _showWorkspaceStats = false;
  bool _isLinkingGoogle = false;
  AuthBootstrapResult _authResult = const AuthBootstrapResult.local();
  AppSyncState _syncState = const AppSyncState(
    status: AppSyncStatus.localOnly,
    pendingChangesCount: 0,
    canSync: false,
  );
  String? _loadError;
  String? selectedProjectId;
  String? _mobileOpenProjectId;
  int projectSelectionRequestId = 0;

  @override
  void initState() {
    super.initState();
    _authBootstrapService = widget.useFirebase
        ? FirebaseAuthBootstrapService()
        : const LocalAuthBootstrapService();
    _dataService = PaiDataService(
      projectRepository: InMemoryProjectRepository(_store),
      taskRepository: InMemoryTaskRepository(_store),
      sessionRepository: InMemorySessionRepository(_store),
      documentRepository: InMemoryDocumentRepository(_store),
    );
    _manualSyncService = ManualSyncService(localStore: _store);
    unawaited(_audioService.warmUp());
    unawaited(_initializeData());
  }

  @override
  void dispose() {
    unawaited(_audioService.dispose());
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      final authResult = await _authBootstrapService
          .ensureSignedInAnonymously();
      _authResult = authResult;
      await _localSnapshotStorage.loadIntoStore(
        scopeKey: _storageScopeKey,
        store: _store,
      );
      final results = await Future.wait<Object>([
        _dataService.load(),
        _workspacePreferencesStorage.loadShowWorkspaceStats(),
        _manualSyncService.loadState(authResult),
      ]);
      final snapshot = results[0] as AppDataSnapshot;
      final showWorkspaceStats = results[1] as bool;
      final syncState = results[2] as AppSyncState;

      if (!mounted) {
        return;
      }

      setState(() {
        _applySnapshot(snapshot);
        _showWorkspaceStats = showWorkspaceStats;
        _syncState = syncState;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  String get _storageScopeKey => _authResult.uid ?? 'local';

  void _applySnapshot(AppDataSnapshot snapshot) {
    projects = snapshot.projects;
    boardProjects = snapshot.boardProjects;
    documents = snapshot.documents;
    bookmarks = snapshot.bookmarks;

    final nextSelectedProjectId =
        snapshot.projects.any((project) => project.id == selectedProjectId)
        ? selectedProjectId
        : snapshot.projects.isEmpty
        ? null
        : snapshot.projects.first.id;
    selectedProjectId = nextSelectedProjectId;
    _mobileOpenProjectId = nextSelectedProjectId == null
        ? null
        : _mobileOpenProjectId == null
        ? null
        : nextSelectedProjectId;
  }

  Future<void> _commitSnapshot(
    AppDataSnapshot snapshot, {
    AppSyncState? syncState,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _applySnapshot(snapshot);
      _syncState = syncState ?? _manualSyncService.describeState(_authResult);
    });
    await _localSnapshotStorage.save(scopeKey: _storageScopeKey, store: _store);
  }

  Future<void> _refreshSnapshot() async {
    final snapshot = await _dataService.load();
    await _commitSnapshot(snapshot);
  }

  Future<AppDataSnapshot?> _prepareSnapshotForAuthChange({
    required String previousScopeKey,
    required AuthBootstrapResult nextAuthResult,
  }) async {
    final nextScopeKey = nextAuthResult.uid ?? 'local';
    if (nextScopeKey == previousScopeKey) {
      return null;
    }

    final loadedExistingSnapshot = await _localSnapshotStorage.loadIntoStore(
      scopeKey: nextScopeKey,
      store: _store,
    );
    if (!loadedExistingSnapshot) {
      await _localSnapshotStorage.save(scopeKey: nextScopeKey, store: _store);
    }
    return _dataService.load();
  }

  Future<void> _linkGoogleAccount() async {
    if (_isLinkingGoogle) {
      return;
    }

    final previousScopeKey = _storageScopeKey;
    await _localSnapshotStorage.save(scopeKey: previousScopeKey, store: _store);

    setState(() => _isLinkingGoogle = true);
    try {
      final linkResult = await _authBootstrapService.signInOrLinkGoogle();
      if (!mounted) {
        return;
      }

      final nextAuthResult =
          linkResult.authResult ??
          await _authBootstrapService.refreshCurrentUser();
      final nextSnapshot = linkResult.isSuccess
          ? await _prepareSnapshotForAuthChange(
              previousScopeKey: previousScopeKey,
              nextAuthResult: nextAuthResult,
            )
          : null;
      final nextSyncState = await _manualSyncService.loadState(nextAuthResult);

      if (!mounted) {
        return;
      }

      setState(() {
        _authResult = nextAuthResult;
        if (nextSnapshot != null) {
          _applySnapshot(nextSnapshot);
        }
        _syncState = nextSyncState;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(linkResult.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-in failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isLinkingGoogle = false);
      }
    }
  }

  Future<void> _syncNow() async {
    if (!_syncState.canSync) {
      return;
    }

    setState(() {
      _syncState = _manualSyncService.describeState(
        _authResult,
        status: AppSyncStatus.syncing,
      );
    });

    try {
      final result = await _manualSyncService.sync(_authResult);
      await _commitSnapshot(result.snapshot, syncState: result.syncState);
      unawaited(_audioService.playSyncSuccess());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PAI finished syncing.')));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _syncState = _manualSyncService.describeState(
          _authResult,
          status: AppSyncStatus.failed,
          errorMessage: error.toString(),
        );
      });
      unawaited(_audioService.playSyncFailure());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $error')));
    }
  }

  void updateBoardProjectPosition(String projectId, Offset nextPosition) {
    setState(() {
      boardProjects = [
        for (final boardProject in boardProjects)
          boardProject.id == projectId
              ? boardProject.copyWith(boardPosition: nextPosition)
              : boardProject,
      ];
    });
    unawaited(_persistBoardProjectPosition(projectId, nextPosition));
  }

  Future<void> _persistBoardProjectPosition(
    String projectId,
    Offset nextPosition,
  ) async {
    await _dataService.updateBoardProjectPosition(projectId, nextPosition);
    await _refreshSnapshot();
  }

  void persistBoardProjectPositions([String? _]) {}

  Offset _defaultBoardPosition() {
    const candidates = [
      Offset(96, 128),
      Offset(388, 164),
      Offset(680, 120),
      Offset(972, 192),
      Offset(1264, 138),
      Offset(1556, 226),
      Offset(312, 430),
      Offset(638, 516),
      Offset(964, 468),
      Offset(1290, 552),
      Offset(1616, 430),
    ];

    final maxX =
        ProjectBoard.defaultBoardWidth - ProjectBoard.defaultCardWidth - 56;
    final maxY =
        ProjectBoard.defaultBoardHeight - ProjectBoard.defaultCardHeight - 56;

    for (final candidate in candidates) {
      final overlaps = boardProjects.any(
        (boardProject) =>
            (boardProject.boardPosition - candidate).distance < 190,
      );
      if (!overlaps) {
        return candidate;
      }
    }

    final index = boardProjects.length;
    final column = index % 6;
    final row = index ~/ 6;
    return Offset(
      (96 + (column * 292)).clamp(40, maxX).toDouble(),
      (128 + (row * 214)).clamp(40, maxY).toDouble(),
    );
  }

  Future<void> createProject(NewProjectDraft draft) async {
    final snapshot = await _dataService.createProject(
      draft: draft,
      boardPosition: _defaultBoardPosition(),
    );
    await _commitSnapshot(snapshot);
    unawaited(_audioService.playProjectCreated());
  }

  Future<void> _showNewProjectDialog(BuildContext context) async {
    final draft = await showDialog<NewProjectDraft>(
      context: context,
      builder: (context) => const NewProjectDialog(),
    );

    if (draft == null || !context.mounted) {
      return;
    }

    await createProject(draft);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${draft.title} was added to pai.')));
  }

  void selectPage(int index) {
    setState(() => selectedIndex = index);
    if (index != 1 || projects.isEmpty) {
      return;
    }

    final projectId = selectedProjectId ?? projects.first.id;
    unawaited(_loadProjectPages(projectId));
  }

  void openProject(String projectId) {
    setState(() {
      selectedProjectId = projectId;
      projectSelectionRequestId++;
      selectedIndex = 1;
    });
    unawaited(_audioService.playProjectOpened());
    unawaited(_loadProjectPages(projectId));
  }

  void openProjectOnMobile(String projectId) {
    setState(() {
      selectedProjectId = projectId;
      projectSelectionRequestId++;
      _mobileOpenProjectId = projectId;
    });
    unawaited(_audioService.playProjectOpened());
    unawaited(_loadProjectPages(projectId));
  }

  void _selectMobileTab(int index) {
    setState(() {
      _mobileTabIndex = index;
      _mobileOpenProjectId = null;
    });
  }

  void setShowWorkspaceStats(bool value) {
    if (_showWorkspaceStats == value) {
      return;
    }

    setState(() => _showWorkspaceStats = value);
    unawaited(_workspacePreferencesStorage.saveShowWorkspaceStats(value));
  }

  Future<void> saveSession(String projectId, SessionNote session) async {
    final snapshot = await _dataService.addSession(projectId, session);
    await _commitSnapshot(snapshot);
  }

  Future<void> addTasks(String projectId, List<String> tasks) async {
    final snapshot = await _dataService.addTasks(projectId, tasks);
    await _commitSnapshot(snapshot);
  }

  Future<void> completeTask(
    String projectId,
    String task,
    SessionNote completionNote,
    String updatedBrief,
  ) async {
    final snapshot = await _dataService.completeTask(
      projectId: projectId,
      task: task,
      completionNote: completionNote,
      updatedBrief: updatedBrief,
    );
    await _commitSnapshot(snapshot);
  }

  Future<void> saveDocument(ProjectDocument document) async {
    final snapshot = await _dataService.saveDocument(document);
    await _commitSnapshot(snapshot);
  }

  Future<void> saveProject(Project project) async {
    final snapshot = await _dataService.updateProject(project);
    await _commitSnapshot(snapshot);
  }

  Future<void> deleteProject(String projectId) async {
    final snapshot = await _dataService.deleteProject(projectId);
    await _commitSnapshot(snapshot);
  }

  Future<void> saveBookmark(DocumentBookmark bookmark) async {
    final snapshot = await _dataService.saveBookmark(bookmark);
    await _commitSnapshot(snapshot);
  }

  Future<void> deleteDocument(String documentId) async {
    final snapshot = await _dataService.deleteDocument(documentId);
    await _commitSnapshot(snapshot);
  }

  Future<void> _loadProjectPages(String projectId) async {
    final snapshot = await _dataService.loadProjectPages(projectId);
    await _commitSnapshot(snapshot);
  }

  Widget _buildAnimatedSection(Widget child, {Object? transitionKey}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final fadeAnimation = Tween<double>(
          begin: 0,
          end: 1,
        ).animate(animation);
        final slideAnimation =
            Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        final scaleAnimation = Tween<double>(begin: 0.99, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(transitionKey ?? selectedIndex),
        child: child,
      ),
    );
  }

  Widget _buildSyncedContent(
    BuildContext context,
    Widget child, {
    bool compact = false,
  }) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 16,
              compact ? 10 : 12,
              compact ? 12 : 16,
              0,
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 320 : 420),
                child: GlobalSyncBar(
                  syncState: _syncState,
                  onSyncRequested: _syncNow,
                  compact: compact,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load app data.\n$_loadError'
              '${_authResult.uid == null ? '' : '\nUser: ${_authResult.uid}'}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final pages = [
      DashboardScreen(
        projects: projects,
        boardProjects: boardProjects,
        showWorkspaceStats: _showWorkspaceStats,
        onProjectOpen: openProject,
        onProjectMoved: updateBoardProjectPosition,
        onProjectMoveEnded: persistBoardProjectPositions,
        onProjectCreated: createProject,
        onOpenSettings: () => selectPage(3),
        onShowWorkspaceStatsChanged: setShowWorkspaceStats,
      ),
      ProjectsScreen(
        projects: projects,
        documents: documents,
        bookmarks: bookmarks,
        selectedProjectId: selectedProjectId,
        selectionRequestId: projectSelectionRequestId,
        onProjectSaved: saveProject,
        onProjectDeleted: deleteProject,
        onSessionSaved: saveSession,
        onTasksAdded: addTasks,
        onTaskCompleted: completeTask,
        onDocumentSaved: saveDocument,
        onBookmarkSaved: saveBookmark,
        onDocumentDeleted: deleteDocument,
      ),
      RemindersScreen(projects: projects),
      SettingsScreen(
        appearanceMode: widget.appearanceMode,
        onAppearanceModeChanged: widget.onAppearanceModeChanged,
        showWorkspaceStats: _showWorkspaceStats,
        onShowWorkspaceStatsChanged: setShowWorkspaceStats,
        syncState: _syncState,
        onSyncRequested: _syncNow,
        authState: _authResult,
        onLinkGoogleRequested: _linkGoogleAccount,
        isLinkingGoogle: _isLinkingGoogle,
      ),
    ];

    final mobileTabs = [
      ProjectsOverviewScreen(
        projects: projects,
        title: 'Projects',
        subtitle: 'A focused list of your recent work.',
        onProjectOpen: openProjectOnMobile,
      ),
      ProjectsOverviewScreen(
        projects: projects,
        title: 'Search',
        subtitle: 'Find a project quickly and open it with one tap.',
        onProjectOpen: openProjectOnMobile,
        showSearch: true,
      ),
      StatsScreen(projects: projects, documents: documents),
      ProfileScreen(
        appearanceMode: widget.appearanceMode,
        onAppearanceModeChanged: widget.onAppearanceModeChanged,
        showWorkspaceStats: _showWorkspaceStats,
        onShowWorkspaceStatsChanged: setShowWorkspaceStats,
        authState: _authResult,
        onLinkGoogleRequested: _linkGoogleAccount,
        isLinkingGoogle: _isLinkingGoogle,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportMode = AppViewport.fromWidth(constraints.maxWidth);
        final isDesktop = viewportMode != AppViewportMode.mobile;
        final isCompactDesktop = viewportMode == AppViewportMode.compactDesktop;
        final railDestinations = [
          NavigationRailDestination(
            icon: const Tooltip(
              message: 'Dashboard',
              child: Icon(Icons.dashboard_outlined),
            ),
            selectedIcon: const Tooltip(
              message: 'Dashboard',
              child: Icon(Icons.dashboard),
            ),
            label: const Text('Dashboard'),
          ),
          NavigationRailDestination(
            icon: const Tooltip(
              message: 'Projects',
              child: Icon(Icons.folder_outlined),
            ),
            selectedIcon: const Tooltip(
              message: 'Projects',
              child: Icon(Icons.folder),
            ),
            label: const Text('Projects'),
          ),
          NavigationRailDestination(
            icon: const Tooltip(
              message: 'Reminders',
              child: Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Tooltip(
              message: 'Reminders',
              child: Icon(Icons.notifications),
            ),
            label: const Text('Reminders'),
          ),
          NavigationRailDestination(
            icon: const Tooltip(
              message: 'Settings',
              child: Icon(Icons.settings_outlined),
            ),
            selectedIcon: const Tooltip(
              message: 'Settings',
              child: Icon(Icons.settings),
            ),
            label: const Text('Settings'),
          ),
        ];

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: selectPage,
                  extended: false,
                  labelType: isCompactDesktop
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  minWidth: isCompactDesktop ? 68 : 76,
                  minExtendedWidth: 176,
                  destinations: railDestinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _buildSyncedContent(
                    context,
                    _buildAnimatedSection(
                      pages[selectedIndex],
                      transitionKey: selectedIndex,
                    ),
                    compact: isCompactDesktop,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: _buildSyncedContent(
            context,
            _buildAnimatedSection(
              _mobileOpenProjectId == null
                  ? mobileTabs[_mobileTabIndex]
                  : ProjectsScreen(
                      projects: projects,
                      documents: documents,
                      bookmarks: bookmarks,
                      selectedProjectId: selectedProjectId,
                      selectionRequestId: projectSelectionRequestId,
                      onProjectSaved: saveProject,
                      onProjectDeleted: deleteProject,
                      onSessionSaved: saveSession,
                      onTasksAdded: addTasks,
                      onTaskCompleted: completeTask,
                      onDocumentSaved: saveDocument,
                      onBookmarkSaved: saveBookmark,
                      onDocumentDeleted: deleteDocument,
                    ),
              transitionKey: _mobileOpenProjectId == null
                  ? 'mobile-tab-$_mobileTabIndex'
                  : 'mobile-project-$selectedProjectId-$projectSelectionRequestId',
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _mobileOpenProjectId == null
                ? () => _showNewProjectDialog(context)
                : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Project'),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _mobileTabIndex,
            onDestinationSelected: _selectMobileTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: 'Projects',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Stats',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
