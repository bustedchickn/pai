import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/firestore/firestore_document_repository.dart';
import 'data/firestore/firestore_project_repository.dart';
import 'data/in_memory/in_memory_document_repository.dart';
import 'data/in_memory/in_memory_pai_store.dart';
import 'data/in_memory/in_memory_project_repository.dart';
import 'data/in_memory/in_memory_session_repository.dart';
import 'data/in_memory/in_memory_task_repository.dart';
import 'models/app_data_snapshot.dart';
import 'models/board_project.dart';
import 'models/document_bookmark.dart';
import 'models/new_project_draft.dart';
import 'models/project.dart';
import 'models/project_document.dart';
import 'models/session_note.dart';
import 'screens/dashboard_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/settings_screen.dart';
import 'firebase_options.dart';
import 'services/auth_bootstrap_service.dart';
import 'services/board_position_storage.dart';
import 'services/pai_data_service.dart';
import 'services/workspace_preferences_storage.dart';
import 'widgets/project_board.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var useFirebase = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    useFirebase = true;
  } catch (error) {
    debugPrint('Firebase initialization skipped: $error');
  }
  runApp(PaiApp(useFirebase: useFirebase));
}

class PaiApp extends StatelessWidget {
  const PaiApp({super.key, required this.useFirebase});

  final bool useFirebase;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F7AE8)),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        useMaterial3: true,
      ),
      home: AppShell(useFirebase: useFirebase),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.useFirebase});

  final bool useFirebase;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  final BoardPositionStorage _boardPositionStorage = BoardPositionStorage();
  final WorkspacePreferencesStorage _workspacePreferencesStorage =
      WorkspacePreferencesStorage();
  late final AuthBootstrapService _authBootstrapService;
  late final PaiDataService _dataService;

  List<Project> projects = const [];
  List<BoardProject> boardProjects = const [];
  List<ProjectDocument> documents = const [];
  List<DocumentBookmark> bookmarks = const [];
  bool _isLoading = true;
  bool _showWorkspaceStats = false;
  String? _authUserId;
  String? _loadError;
  String? selectedProjectId;
  int projectSelectionRequestId = 0;

  @override
  void initState() {
    super.initState();
    final useFirebase = widget.useFirebase;
    final store = InMemoryPaiStore();
    _authBootstrapService = useFirebase
        ? FirebaseAuthBootstrapService()
        : const LocalAuthBootstrapService();
    final projectRepository = useFirebase
        ? FirestoreProjectRepository(localStore: store)
        : InMemoryProjectRepository(store);
    final documentRepository = useFirebase
        ? FirestoreDocumentRepository(localStore: store)
        : InMemoryDocumentRepository(store);
    _dataService = PaiDataService(
      projectRepository: projectRepository,
      taskRepository: InMemoryTaskRepository(store),
      sessionRepository: InMemorySessionRepository(store),
      documentRepository: documentRepository,
    );
    unawaited(_initializeData());
  }

  Future<void> _initializeData() async {
    try {
      final authResult = await _authBootstrapService.ensureSignedIn();
      final results = await Future.wait<Object>([
        _dataService.load(),
        _boardPositionStorage.loadPositions(),
        _workspacePreferencesStorage.loadShowWorkspaceStats(),
      ]);
      var snapshot = results[0] as AppDataSnapshot;
      final storedPositions = results[1] as Map<String, Offset>;
      final showWorkspaceStats = results[2] as bool;
      if (storedPositions.isNotEmpty) {
        final restoredBoardProjects = [
          for (final boardProject in snapshot.boardProjects)
            boardProject.copyWith(
              boardPosition:
                  storedPositions[boardProject.id] ??
                  boardProject.boardPosition,
            ),
        ];
        snapshot = await _dataService.saveBoardProjects(restoredBoardProjects);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _applySnapshot(snapshot);
        _authUserId = authResult.uid;
        _showWorkspaceStats = showWorkspaceStats;
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

  void _applySnapshot(AppDataSnapshot snapshot) {
    projects = snapshot.projects;
    boardProjects = snapshot.boardProjects;
    documents = snapshot.documents;
    bookmarks = snapshot.bookmarks;
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
    unawaited(_dataService.updateBoardProjectPosition(projectId, nextPosition));
  }

  void persistBoardProjectPositions([String? _]) {
    unawaited(_boardPositionStorage.savePositions(boardProjects));
  }

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
    if (!mounted) {
      return;
    }

    setState(() => _applySnapshot(snapshot));
    persistBoardProjectPositions();
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
    unawaited(_loadProjectPages(projectId));
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
    if (!mounted) {
      return;
    }

    setState(() => _applySnapshot(snapshot));
  }

  Future<void> addTasks(String projectId, List<String> tasks) async {
    final snapshot = await _dataService.addTasks(projectId, tasks);
    if (!mounted) {
      return;
    }

    setState(() => _applySnapshot(snapshot));
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
    if (!mounted) {
      return;
    }

    setState(() => _applySnapshot(snapshot));
  }

  Future<void> saveDocument(ProjectDocument document) async {
    final snapshot = await _dataService.saveDocument(document);
    if (!mounted) {
      return;
    }

    setState(() => _applySnapshot(snapshot));
  }

  Future<void> saveProject(Project project) async {
    final snapshot = await _dataService.updateProject(project);
    if (!mounted) {
      return;
    }

    setState(() => _applySnapshot(snapshot));
  }

  Future<void> saveBookmark(DocumentBookmark bookmark) async {
    final snapshot = await _dataService.saveBookmark(bookmark);
    if (!mounted) {
      return;
    }

    setState(() => _applySnapshot(snapshot));
  }

  Future<void> deleteDocument(String documentId) async {
    final snapshot = await _dataService.deleteDocument(documentId);
    if (!mounted) {
      return;
    }

    setState(() => _applySnapshot(snapshot));
  }

  Future<void> _loadProjectPages(String projectId) async {
    final snapshot = await _dataService.loadProjectPages(projectId);
    if (!mounted) {
      return;
    }

    setState(() => _applySnapshot(snapshot));
  }

  Widget _buildAnimatedSection(Widget child) {
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
      child: KeyedSubtree(key: ValueKey(selectedIndex), child: child),
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
              '${_authUserId == null ? '' : '\nUser: $_authUserId'}',
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
        onSessionSaved: saveSession,
        onTasksAdded: addTasks,
        onTaskCompleted: completeTask,
        onDocumentSaved: saveDocument,
        onBookmarkSaved: saveBookmark,
        onDocumentDeleted: deleteDocument,
      ),
      RemindersScreen(projects: projects),
      SettingsScreen(
        showWorkspaceStats: _showWorkspaceStats,
        onShowWorkspaceStatsChanged: setShowWorkspaceStats,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: selectPage,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.folder_outlined),
                      selectedIcon: Icon(Icons.folder),
                      label: Text('Projects'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.notifications_outlined),
                      selectedIcon: Icon(Icons.notifications),
                      label: Text('Reminders'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _buildAnimatedSection(pages[selectedIndex])),
              ],
            ),
          );
        }

        return Scaffold(
          body: _buildAnimatedSection(pages[selectedIndex]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: selectPage,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                label: 'Projects',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                label: 'Reminders',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}
