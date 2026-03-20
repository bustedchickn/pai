import 'package:flutter/material.dart';

import 'data/mock_data.dart';
import 'models/board_project.dart';
import 'models/new_project_draft.dart';
import 'models/project.dart';
import 'screens/dashboard_screen.dart';
import 'screens/projects_screen.dart';
import 'services/board_position_storage.dart';
import 'widgets/project_board.dart';

void main() {
  runApp(const PaiApp());
}

class PaiApp extends StatelessWidget {
  const PaiApp({super.key});

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
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  final BoardPositionStorage _boardPositionStorage = BoardPositionStorage();

  late List<Project> projects;
  late List<BoardProject> boardProjects;
  String? selectedProjectId;
  int projectSelectionRequestId = 0;

  @override
  void initState() {
    super.initState();
    projects = List<Project>.from(mockProjects);
    boardProjects = List<BoardProject>.from(mockBoardProjects);
    _restoreBoardPositions();
  }

  Future<void> _restoreBoardPositions() async {
    final storedPositions = await _boardPositionStorage.loadPositions();
    if (!mounted || storedPositions.isEmpty) {
      return;
    }

    setState(() {
      boardProjects = [
        for (final boardProject in boardProjects)
          boardProject.copyWith(
            boardPosition:
                storedPositions[boardProject.id] ?? boardProject.boardPosition,
          ),
      ];
    });
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
  }

  void persistBoardProjectPositions([String? _]) {
    _boardPositionStorage.savePositions(boardProjects);
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

  void createProject(NewProjectDraft draft) {
    final projectId = DateTime.now().microsecondsSinceEpoch.toString();
    final boardPosition = _defaultBoardPosition();

    final project = Project(
      id: projectId,
      title: draft.title,
      status: draft.status,
      brief: draft.brief,
      tags: draft.tags,
      nextSteps: const [],
      blockers: const [],
      sessions: const [],
      reminders: const [],
    );

    final boardProject = BoardProject(
      id: projectId,
      title: draft.title,
      brief: draft.brief,
      tags: draft.tags,
      status: draft.status,
      progress: draft.progress,
      boardPosition: boardPosition,
    );

    setState(() {
      projects = [...projects, project];
      boardProjects = [...boardProjects, boardProject];
    });

    persistBoardProjectPositions();
  }

  void selectPage(int index) {
    setState(() => selectedIndex = index);
  }

  void openProject(String projectId) {
    setState(() {
      selectedProjectId = projectId;
      projectSelectionRequestId++;
      selectedIndex = 1;
    });
  }

  void updateProject(Project nextProject) {
    setState(() {
      projects = [
        for (final project in projects)
          project.id == nextProject.id ? nextProject : project,
      ];
    });
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
    final pages = [
      DashboardScreen(
        projects: projects,
        boardProjects: boardProjects,
        onProjectOpen: openProject,
        onProjectMoved: updateBoardProjectPosition,
        onProjectMoveEnded: persistBoardProjectPositions,
        onProjectCreated: createProject,
        onOpenSettings: () => selectPage(3),
      ),
      ProjectsScreen(
        projects: projects,
        selectedProjectId: selectedProjectId,
        selectionRequestId: projectSelectionRequestId,
        onProjectUpdated: updateProject,
      ),
      RemindersScreen(projects: projects),
      const SettingsScreen(),
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

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final reminders = projects.expand((project) => project.reminders).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              'Reminders',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...reminders.map(
              (reminder) => Card(
                child: ListTile(
                  leading: const Icon(Icons.alarm_outlined),
                  title: Text(reminder.title),
                  subtitle: Text(reminder.projectTitle),
                  trailing: Text(reminder.dueLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              'Settings',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.sync_outlined),
                title: Text('Sync'),
                subtitle: Text(
                  'Start with local data first, then connect Firebase later.',
                ),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.mic_none_outlined),
                title: Text('Voice notes'),
                subtitle: Text(
                  'Enable speech-to-text after the core session flow works.',
                ),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.auto_awesome_outlined),
                title: Text('AI assistant'),
                subtitle: Text(
                  'Use simple prompts and summaries now, then add smarter AI later.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
