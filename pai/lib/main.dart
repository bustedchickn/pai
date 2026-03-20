import 'package:flutter/material.dart';

import 'models/board_project.dart';
import 'models/new_project_draft.dart';
import 'services/board_position_storage.dart';
import 'widgets/project_board.dart';
import 'widgets/new_project_dialog.dart';

void main() {
  runApp(const StatusPaAiApp());
}

class StatusPaAiApp extends StatelessWidget {
  const StatusPaAiApp({super.key});

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
      Offset(420, 188),
      Offset(744, 132),
      Offset(1088, 184),
      Offset(320, 468),
      Offset(692, 532),
      Offset(1108, 588),
      Offset(1380, 296),
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
    final column = index % 4;
    final row = index ~/ 4;
    return Offset(
      (96 + (column * 324)).clamp(40, maxX).toDouble(),
      (128 + (row * 236)).clamp(40, maxY).toDouble(),
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
      nextSteps: const [],
      blockers: const [],
      sessions: const [],
      reminders: const [],
    );

    final boardProject = BoardProject(
      id: projectId,
      title: draft.title,
      brief: draft.brief,
      category: draft.category,
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

class Project {
  final String id;
  final String title;
  final String status;
  final String brief;
  final List<String> nextSteps;
  final List<String> blockers;
  final List<SessionNote> sessions;
  final List<ReminderItem> reminders;

  const Project({
    required this.id,
    required this.title,
    required this.status,
    required this.brief,
    required this.nextSteps,
    required this.blockers,
    required this.sessions,
    required this.reminders,
  });
}

class SessionNote {
  final String id;
  final String dateLabel;
  final String summary;

  const SessionNote({
    required this.id,
    required this.dateLabel,
    required this.summary,
  });
}

class ReminderItem {
  final String id;
  final String title;
  final String dueLabel;
  final String projectTitle;

  const ReminderItem({
    required this.id,
    required this.title,
    required this.dueLabel,
    required this.projectTitle,
  });
}

const statusPaAiProject = Project(
  id: '1',
  title: 'pai',
  status: 'active',
  brief:
      'MVP is defined. Focus on project CRUD, session recaps, reminders, and later AI summaries.',
  nextSteps: [
    'Set up local models',
    'Build project detail screen',
    'Add session recap flow',
  ],
  blockers: ['Need a simple data layer that works on desktop and mobile'],
  sessions: [
    SessionNote(
      id: 's1',
      dateLabel: 'Today',
      summary:
          'Outlined the app as a local-first project assistant with synced reminders.',
    ),
    SessionNote(
      id: 's2',
      dateLabel: 'Yesterday',
      summary: 'Decided to start with mock data before adding Firebase.',
    ),
  ],
  reminders: [
    ReminderItem(
      id: 'r1',
      title: 'Create Flutter models',
      dueLabel: 'Tonight',
      projectTitle: 'pai',
    ),
    ReminderItem(
      id: 'r2',
      title: 'Design project detail page',
      dueLabel: 'Tomorrow',
      projectTitle: 'pai',
    ),
  ],
);

const eventOpsProject = Project(
  id: '2',
  title: 'Event Ops App',
  status: 'active',
  brief: 'Navigation and organization-level polish are the current focus.',
  nextSteps: ['Refine nav flow', 'Polish event pages'],
  blockers: [],
  sessions: [
    SessionNote(
      id: 's3',
      dateLabel: '2 days ago',
      summary: 'Moved the app to a Firebase-hosted SPA structure.',
    ),
  ],
  reminders: [
    ReminderItem(
      id: 'r3',
      title: 'Review billing flow',
      dueLabel: 'Friday',
      projectTitle: 'Event Ops App',
    ),
  ],
);

const practiceAppProject = Project(
  id: '3',
  title: 'Practice App',
  status: 'paused',
  brief:
      'Idea is still interesting, but the feature list needs to be reduced before moving forward.',
  nextSteps: ['Clarify the smallest useful version'],
  blockers: ['Scope is too broad right now'],
  sessions: [],
  reminders: [],
);

const mockProjects = [statusPaAiProject, eventOpsProject, practiceAppProject];

final mockBoardProjects = [
  const BoardProject(
    id: '1',
    title: 'pai',
    brief:
        'MVP is defined. Focus on project CRUD, session recaps, reminders, and later AI summaries.',
    category: 'Coding',
    status: 'active',
    progress: 0.35,
    boardPosition: Offset(120, 140),
  ),
  const BoardProject(
    id: '2',
    title: 'Event Ops App',
    brief: 'Navigation and organization-level polish are the current focus.',
    category: 'Work',
    status: 'active',
    progress: 0.70,
    boardPosition: Offset(560, 220),
  ),
  const BoardProject(
    id: '3',
    title: 'Practice App',
    brief:
        'Idea is still interesting, but the feature list needs to be reduced before moving forward.',
    category: 'Music',
    status: 'paused',
    progress: 0.20,
    boardPosition: Offset(320, 620),
  ),
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.projects,
    required this.boardProjects,
    required this.onProjectOpen,
    required this.onProjectMoved,
    required this.onProjectMoveEnded,
    required this.onProjectCreated,
    required this.onOpenSettings,
  });

  final List<Project> projects;
  final List<BoardProject> boardProjects;
  final ValueChanged<String> onProjectOpen;
  final void Function(String projectId, Offset nextPosition) onProjectMoved;
  final ValueChanged<String> onProjectMoveEnded;
  final ValueChanged<NewProjectDraft> onProjectCreated;
  final VoidCallback onOpenSettings;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  String get _searchQuery => _searchController.text.trim().toLowerCase();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showNewProjectDialog(BuildContext context) async {
    final draft = await showDialog<NewProjectDraft>(
      context: context,
      builder: (context) => const NewProjectDialog(),
    );

    if (draft == null || !context.mounted) {
      return;
    }

    widget.onProjectCreated(draft);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${draft.title} was added to your board.')),
    );
  }

  List<BoardProject> _filteredBoardProjects() {
    final query = _searchQuery;
    if (query.isEmpty) {
      return widget.boardProjects;
    }

    return widget.boardProjects.where((boardProject) {
      final searchableText = [
        boardProject.title,
        boardProject.brief,
        boardProject.category,
        boardProject.status,
      ].join(' ').toLowerCase();
      return searchableText.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleBoardProjects = _filteredBoardProjects();
    final visibleProjectIds = {
      for (final boardProject in visibleBoardProjects) boardProject.id,
    };
    final visibleProjects = widget.projects
        .where((project) => visibleProjectIds.contains(project.id))
        .toList();
    final reminders = visibleProjects
        .expand((project) => project.reminders)
        .toList();
    final activeProjects = visibleProjects
        .where((project) => project.status == 'active')
        .length;
    final blockedProjects = visibleProjects
        .where((project) => project.status == 'blocked')
        .length;
    final helperText = _searchQuery.isEmpty
        ? 'Pan, zoom, drag, and open projects from a single workspace.'
        : 'Showing ${visibleBoardProjects.length} of ${widget.boardProjects.length} projects for "${_searchController.text.trim()}".';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          children: [
            _WorkspaceTopBar(
              searchController: _searchController,
              onSearchChanged: (_) => setState(() {}),
              onClearSearch: () {
                _searchController.clear();
                setState(() {});
              },
              onNewProject: () => _showNewProjectDialog(context),
              onOpenSettings: widget.onOpenSettings,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: const Color(0xFFF9FAFD),
                  border: Border.all(color: const Color(0xFFD8DFEE)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8090C2).withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    children: [
                      _WorkspaceHeader(
                        title: 'Project workspace',
                        subtitle: helperText,
                        totalVisible: visibleBoardProjects.length,
                        totalProjects: widget.boardProjects.length,
                        metrics: [
                          _WorkspaceMetricData(
                            label: 'Active',
                            value: '$activeProjects',
                            icon: Icons.play_circle_outline,
                          ),
                          _WorkspaceMetricData(
                            label: 'Due soon',
                            value: '${reminders.length}',
                            icon: Icons.schedule_outlined,
                          ),
                          _WorkspaceMetricData(
                            label: 'Blocked',
                            value: '$blockedProjects',
                            icon: Icons.block_outlined,
                          ),
                          _WorkspaceMetricData(
                            label: 'Total',
                            value: '${visibleProjects.length}',
                            icon: Icons.apps_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ProjectBoard(
                          boardProjects: visibleBoardProjects,
                          onProjectDragged: widget.onProjectMoved,
                          onProjectDragEnded: widget.onProjectMoveEnded,
                          onProjectTap: widget.onProjectOpen,
                          onAddProjectTap: () => _showNewProjectDialog(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.projects,
    this.selectedProjectId,
    this.selectionRequestId = 0,
  });

  final List<Project> projects;
  final String? selectedProjectId;
  final int selectionRequestId;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late Project selectedProject;
  final TextEditingController sessionController = TextEditingController();
  final TextEditingController questionController = TextEditingController();
  String assistantReply =
      'Ask about a project to see a summary, blockers, or next steps.';

  @override
  void initState() {
    super.initState();
    selectedProject = widget.projects.first;
    _applyRequestedSelection();
  }

  Project _projectForId(String? projectId) {
    return widget.projects.firstWhere(
      (project) => project.id == projectId,
      orElse: () => widget.projects.first,
    );
  }

  void _applyRequestedSelection() {
    if (widget.selectedProjectId == null) return;
    selectedProject = _projectForId(widget.selectedProjectId);
    assistantReply =
        'Ask about a project to see a summary, blockers, or next steps.';
  }

  @override
  void didUpdateWidget(covariant ProjectsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.projects.any((project) => project.id == selectedProject.id)) {
      selectedProject = widget.projects.first;
    }
    if (widget.selectionRequestId != oldWidget.selectionRequestId) {
      _applyRequestedSelection();
    }
  }

  @override
  void dispose() {
    sessionController.dispose();
    questionController.dispose();
    super.dispose();
  }

  void askAssistant() {
    final input = questionController.text.toLowerCase();
    if (input.trim().isEmpty) return;

    setState(() {
      if (input.contains('next')) {
        assistantReply =
            'Next steps for ${selectedProject.title}: ${selectedProject.nextSteps.join(', ')}.';
      } else if (input.contains('block') || input.contains('stuck')) {
        assistantReply = selectedProject.blockers.isEmpty
            ? '${selectedProject.title} has no recorded blockers right now.'
            : 'Current blockers for ${selectedProject.title}: ${selectedProject.blockers.join(', ')}.';
      } else if (input.contains('latest') ||
          input.contains('summary') ||
          input.contains('what happened')) {
        assistantReply = selectedProject.brief;
      } else {
        assistantReply =
            '${selectedProject.title} is ${selectedProject.status}. ${selectedProject.brief}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1100;

            final projectList = Card(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.projects.length,
                itemBuilder: (context, index) {
                  final project = widget.projects[index];
                  final selected = project.id == selectedProject.id;
                  return ListTile(
                    selected: selected,
                    leading: CircleAvatar(
                      child: Text(project.title.characters.first),
                    ),
                    title: Text(project.title),
                    subtitle: Text(
                      project.brief,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _StatusChip(status: project.status),
                    onTap: () => setState(() => selectedProject = project),
                  );
                },
              ),
            );

            final detailPane = ListView(
              children: [
                Text(
                  selectedProject.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatusChip(status: selectedProject.status),
                    const SizedBox(width: 8),
                    Text('${selectedProject.sessions.length} sessions'),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Current brief',
                  child: Text(selectedProject.brief),
                ),
                _SectionCard(
                  title: 'Next steps',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: selectedProject.nextSteps
                        .map(
                          (step) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(step)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                _SectionCard(
                  title: 'Recent sessions',
                  child: selectedProject.sessions.isEmpty
                      ? const Text('No sessions yet.')
                      : Column(
                          children: selectedProject.sessions
                              .map(
                                (session) => Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    title: Text(session.summary),
                                    subtitle: Text(session.dateLabel),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                _SectionCard(
                  title: 'New session recap',
                  child: Column(
                    children: [
                      TextField(
                        controller: sessionController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'What happened in this work session?',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Session saving will be wired up next.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save recap'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Voice note support will come after the base flow works.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.mic_none_outlined),
                            label: const Text('Voice note'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            final assistantPane = Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assistant',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: questionController,
                      decoration: const InputDecoration(
                        hintText: 'Ask about this project',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: askAssistant,
                      child: const Text('Ask'),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(assistantReply),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PromptChip(
                          label: 'What happened last time?',
                          onTap: () => questionController.text =
                              'What happened last time?',
                        ),
                        _PromptChip(
                          label: 'What should I work on next?',
                          onTap: () => questionController.text =
                              'What should I work on next?',
                        ),
                        _PromptChip(
                          label: 'What is blocking this?',
                          onTap: () => questionController.text =
                              'What is blocking this?',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 320, child: projectList),
                  const SizedBox(width: 20),
                  Expanded(child: detailPane),
                  const SizedBox(width: 20),
                  SizedBox(width: 320, child: assistantPane),
                ],
              );
            }

            return ListView(
              children: [
                SizedBox(height: 280, child: projectList),
                const SizedBox(height: 16),
                SizedBox(height: 900, child: detailPane),
                const SizedBox(height: 16),
                assistantPane,
              ],
            );
          },
        ),
      ),
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

class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onNewProject,
    required this.onOpenSettings,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onNewProject;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 860;
        final searchField = SizedBox(
          height: 46,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search titles, categories, or status',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: onNewProject,
              icon: const Icon(Icons.add),
              label: const Text('New project'),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: onOpenSettings,
              tooltip: 'Settings',
              icon: const Icon(Icons.tune),
            ),
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFE5ECFF),
              child: Text(
                'P',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3557A5),
                ),
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [const _BrandBadge(), const Spacer(), actions]),
              const SizedBox(height: 12),
              searchField,
            ],
          );
        }

        return Row(
          children: [
            const _BrandBadge(),
            const SizedBox(width: 18),
            Expanded(child: searchField),
            const SizedBox(width: 18),
            actions,
          ],
        );
      },
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8DFEE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF3557A5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.dashboard_customize,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'pai',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.title,
    required this.subtitle,
    required this.totalVisible,
    required this.totalProjects,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final int totalVisible;
  final int totalProjects;
  final List<_WorkspaceMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1024;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        );

        final metricsRow = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            for (final metric in metrics) _WorkspaceMetric(metric: metric),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCompact) ...[
              info,
              const SizedBox(height: 14),
              metricsRow,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 16),
                  Flexible(child: metricsRow),
                ],
              ),
            const SizedBox(height: 12),
            Text(
              '$totalVisible visible / $totalProjects on the board',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: const Color(0xFF5E6B8A)),
            ),
          ],
        );
      },
    );
  }
}

class _WorkspaceMetricData {
  const _WorkspaceMetricData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _WorkspaceMetric extends StatelessWidget {
  const _WorkspaceMetric({required this.metric});

  final _WorkspaceMetricData metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8DFEE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(metric.icon, size: 18, color: const Color(0xFF5D6F96)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metric.value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                metric.label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  Color get color {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      case 'blocked':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}
