import 'dart:async';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/session_note.dart';
import '../widgets/prompt_chip.dart';
import '../widgets/section_card.dart';
import '../widgets/status_chip.dart';

const int kDefaultVisibleRecentSessions = 3;
const Duration kProjectsQuickAnimation = Duration(milliseconds: 220);
const Duration kSidebarCollapseDelay = Duration(seconds: 3);
const Duration kSidebarExpandHoverDelay = Duration(milliseconds: 700);
const double kExpandedSidebarWidth = 340;
const double kCollapsedSidebarWidth = 128;
const double kAssistantPaneWidth = 320;

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.projects,
    required this.onProjectUpdated,
    this.selectedProjectId,
    this.selectionRequestId = 0,
  });

  final List<Project> projects;
  final ValueChanged<Project> onProjectUpdated;
  final String? selectedProjectId;
  final int selectionRequestId;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late Project _selectedProject;
  final TextEditingController _sessionController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final Set<String> _completingNextSteps = <String>{};
  final Set<String> _selectedRecapTaskCandidates = <String>{};
  List<SessionNote> _pendingCompletionSessions = const [];
  List<String> _recapTaskCandidates = const [];
  bool _showAllSessions = false;
  bool _isSidebarExpanded = true;
  String? _selectedTagFilter;
  String _assistantReply =
      'Ask about a project to see a summary, blockers, or next steps.';
  Timer? _sidebarCollapseTimer;
  Timer? _sidebarExpandHoverTimer;

  @override
  void initState() {
    super.initState();
    _selectedProject = widget.projects.first;
    _applyRequestedSelection();
    _resetSidebarCollapseTimer(enabled: true);
  }

  @override
  void didUpdateWidget(covariant ProjectsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousSelectionId = _selectedProject.id;
    _selectedProject = _projectForId(previousSelectionId);
    _reconcilePendingSessionState();
    _syncSelectionToActiveFilter();

    if (widget.selectionRequestId != oldWidget.selectionRequestId) {
      _applyRequestedSelection();
    }
  }

  @override
  void dispose() {
    _sidebarCollapseTimer?.cancel();
    _sidebarExpandHoverTimer?.cancel();
    _sessionController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Project _projectForId(String? projectId) {
    return widget.projects.firstWhere(
      (project) => project.id == projectId,
      orElse: () => widget.projects.first,
    );
  }

  List<Project> _projectsMatchingTag(String? tag) {
    if (tag == null) {
      return widget.projects;
    }

    return widget.projects
        .where((project) => project.tags.contains(tag))
        .toList();
  }

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

  void _applyRequestedSelection() {
    if (widget.selectedProjectId == null) {
      return;
    }

    _selectedProject = _projectForId(widget.selectedProjectId);
    if (_selectedTagFilter != null &&
        !_selectedProject.tags.contains(_selectedTagFilter)) {
      _selectedTagFilter = null;
    }
    _resetProjectScopedUi();
  }

  void _resetProjectScopedUi() {
    _showAllSessions = false;
    _completingNextSteps.clear();
    _pendingCompletionSessions = const [];
    _selectedRecapTaskCandidates.clear();
    _recapTaskCandidates = const [];
    _sessionController.clear();
    _questionController.clear();
    _assistantReply =
        'Ask about a project to see a summary, blockers, or next steps.';
  }

  void _resetSidebarCollapseTimer({required bool enabled}) {
    _sidebarCollapseTimer?.cancel();
    if (!enabled || !_isSidebarExpanded) {
      return;
    }

    _sidebarCollapseTimer = Timer(kSidebarCollapseDelay, () {
      if (!mounted) {
        return;
      }
      setState(() => _isSidebarExpanded = false);
    });
  }

  void _noteSidebarInteraction({
    required bool enabled,
    bool expandIfNeeded = false,
  }) {
    if (!enabled) {
      return;
    }

    _sidebarExpandHoverTimer?.cancel();
    if (expandIfNeeded && !_isSidebarExpanded) {
      setState(() => _isSidebarExpanded = true);
    }
    _resetSidebarCollapseTimer(enabled: true);
  }

  void _startSidebarExpandHover({required bool enabled}) {
    if (!enabled) {
      return;
    }

    if (_isSidebarExpanded) {
      _resetSidebarCollapseTimer(enabled: true);
      return;
    }
    if (_sidebarExpandHoverTimer?.isActive ?? false) {
      return;
    }

    _sidebarExpandHoverTimer = Timer(kSidebarExpandHoverDelay, () {
      if (!mounted) {
        return;
      }
      setState(() => _isSidebarExpanded = true);
      _resetSidebarCollapseTimer(enabled: true);
    });
  }

  void _stopSidebarHover({required bool enabled}) {
    if (!enabled) {
      return;
    }

    _sidebarExpandHoverTimer?.cancel();
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

  void _syncSelectionToActiveFilter() {
    if (_selectedTagFilter == null) {
      return;
    }

    final filteredProjects = _projectsMatchingTag(_selectedTagFilter);
    if (filteredProjects.isEmpty) {
      _selectedTagFilter = null;
      return;
    }

    final selectedStillVisible = filteredProjects.any(
      (project) => project.id == _selectedProject.id,
    );
    if (selectedStillVisible) {
      return;
    }

    _selectedProject = filteredProjects.first;
    _resetProjectScopedUi();
  }

  void _selectProject(Project project) {
    setState(() {
      _selectedProject = project;
      _resetProjectScopedUi();
    });
  }

  void _toggleTagFilter(String tag) {
    setState(() {
      _selectedTagFilter = _selectedTagFilter == tag ? null : tag;
      _syncSelectionToActiveFilter();
    });
  }

  void _clearTagFilter() {
    if (_selectedTagFilter == null) {
      return;
    }

    setState(() => _selectedTagFilter = null);
  }

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
            ? _selectedProject.brief
            : _selectedProject.sessions.first.summary;
      } else {
        _assistantReply =
            '${_selectedProject.title} is ${_selectedProject.status}. ${_selectedProject.brief}';
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

  void _saveSessionRecap() {
    final recapText = _sessionController.text.trim();
    if (recapText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a short recap before saving it.')),
      );
      return;
    }

    final recapNote = SessionNote(
      id: 'session-${DateTime.now().microsecondsSinceEpoch}',
      dateLabel: 'Just now',
      summary: recapText,
    );
    final updatedProject = _selectedProject.copyWith(
      sessions: [recapNote, ..._selectedProject.sessions],
    );

    widget.onProjectUpdated(updatedProject);
    setState(() {
      _selectedProject = updatedProject;
      _sessionController.clear();
      _recapTaskCandidates = const [];
      _selectedRecapTaskCandidates.clear();
      _assistantReply = 'Saved the session recap to recent sessions.';
    });
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

  void _addTasksFromRecap() {
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

    final updatedProject = _selectedProject.copyWith(
      nextSteps: [..._selectedProject.nextSteps, ...tasksToAdd],
    );

    widget.onProjectUpdated(updatedProject);
    setState(() {
      _selectedProject = updatedProject;
      _recapTaskCandidates = const [];
      _selectedRecapTaskCandidates.clear();
      _assistantReply =
          'Added ${tasksToAdd.length} new next step${tasksToAdd.length == 1 ? '' : 's'} from the recap.';
    });
  }

  void _completeNextStep(String step) {
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

    Future<void>.delayed(kProjectsQuickAnimation, () {
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
      );

      widget.onProjectUpdated(updatedProject);
      if (!mounted) {
        return;
      }

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeSessions = _recentSessions;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1120;
            final sidebarCollapseEnabled = isWide;
            final sidebarWidth = sidebarCollapseEnabled
                ? (_isSidebarExpanded
                      ? kExpandedSidebarWidth
                      : kCollapsedSidebarWidth)
                : constraints.maxWidth;
            final projectList = _ProjectsSidebar(
              projects: widget.projects,
              selectedProjectId: _selectedProject.id,
              selectedTagFilter: _selectedTagFilter,
              isExpanded: !sidebarCollapseEnabled || _isSidebarExpanded,
              onProjectSelected: _selectProject,
              onTagSelected: (tag) {
                _noteSidebarInteraction(enabled: sidebarCollapseEnabled);
                _toggleTagFilter(tag);
              },
              onClearTagFilter: () {
                _noteSidebarInteraction(enabled: sidebarCollapseEnabled);
                _clearTagFilter();
              },
              onInteraction: () =>
                  _noteSidebarInteraction(enabled: sidebarCollapseEnabled),
              onHoverEnter: () =>
                  _startSidebarExpandHover(enabled: sidebarCollapseEnabled),
              onHoverExit: () =>
                  _stopSidebarHover(enabled: sidebarCollapseEnabled),
            );
            final detailPane = _ProjectDetailPane(
              project: _selectedProject,
              sessions: activeSessions,
              sessionCount: activeSessions.length,
              showAllSessions: _showAllSessions,
              onToggleSessions: () {
                setState(() => _showAllSessions = !_showAllSessions);
              },
              onCompleteNextStep: _completeNextStep,
              completingSteps: _completingNextSteps,
              sessionController: _sessionController,
              onRecapChanged: _handleRecapChanged,
              onSaveRecap: _saveSessionRecap,
              onExtractTasksFromRecap: _extractTasksFromRecap,
              recapTaskCandidates: _recapTaskCandidates,
              selectedRecapTaskCandidates: _selectedRecapTaskCandidates,
              onToggleRecapTaskCandidate: _toggleRecapTaskCandidate,
              onAddSelectedRecapTasks: _addTasksFromRecap,
            );
            final assistantPane = _ProjectAssistantPane(
              questionController: _questionController,
              assistantReply: _assistantReply,
              onAsk: _askAssistant,
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: sidebarWidth,
                    child: projectList,
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: detailPane),
                  const SizedBox(width: 20),
                  SizedBox(width: kAssistantPaneWidth, child: assistantPane),
                ],
              );
            }

            return ListView(
              children: [
                SizedBox(height: 360, child: projectList),
                const SizedBox(height: 16),
                detailPane,
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

class _ProjectsSidebar extends StatelessWidget {
  const _ProjectsSidebar({
    required this.projects,
    required this.selectedProjectId,
    required this.selectedTagFilter,
    required this.isExpanded,
    required this.onProjectSelected,
    required this.onTagSelected,
    required this.onClearTagFilter,
    required this.onInteraction,
    required this.onHoverEnter,
    required this.onHoverExit,
  });

  final List<Project> projects;
  final String selectedProjectId;
  final String? selectedTagFilter;
  final bool isExpanded;
  final ValueChanged<Project> onProjectSelected;
  final ValueChanged<String> onTagSelected;
  final VoidCallback onClearTagFilter;
  final VoidCallback onInteraction;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  @override
  Widget build(BuildContext context) {
    final availableTags = {
      for (final project in projects) ...project.tags,
    }.toList()..sort();
    final filteredProjects = selectedTagFilter == null
        ? projects
        : projects
              .where((project) => project.tags.contains(selectedTagFilter))
              .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final liveExpanded = isExpanded && constraints.maxWidth >= 220;
        final showSidebarDetails = liveExpanded && constraints.maxWidth >= 270;

        return MouseRegion(
          onEnter: (_) {
            if (liveExpanded) {
              onInteraction();
            } else {
              onHoverEnter();
            }
          },
          onHover: (_) {
            if (liveExpanded) {
              onInteraction();
            } else {
              onHoverEnter();
            }
          },
          onExit: (_) => onHoverExit(),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: showSidebarDetails
                      ? Padding(
                          key: const ValueKey('expanded-sidebar-header'),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Projects',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Browse the rest of your projects and jump between them quickly.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: const Color(0xFF61708B)),
                              ),
                              const SizedBox(height: 12),
                              _TagWrap(
                                tags: availableTags,
                                compact: true,
                                selectedTag: selectedTagFilter,
                                onTagTap: onTagSelected,
                              ),
                              if (selectedTagFilter != null) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: onClearTagFilter,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                  ),
                                  label: Text('Clear "$selectedTagFilter"'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Padding(
                          key: const ValueKey('collapsed-sidebar-header'),
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.folder_copy_outlined,
                                  size: 20,
                                  color: Color(0xFF596983),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Projects',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF56647D),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: filteredProjects.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No projects match this tag yet.'),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.all(liveExpanded ? 12 : 10),
                          itemCount: filteredProjects.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(height: liveExpanded ? 10 : 8),
                          itemBuilder: (context, index) {
                            final project = filteredProjects[index];

                            return _SidebarProjectTile(
                              project: project,
                              isSelected: project.id == selectedProjectId,
                              selectedTag: selectedTagFilter,
                              isExpanded: liveExpanded,
                              onTap: () {
                                onInteraction();
                                onProjectSelected(project);
                              },
                              onTagTap: (tag) {
                                onInteraction();
                                onTagSelected(tag);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProjectDetailPane extends StatelessWidget {
  const _ProjectDetailPane({
    required this.project,
    required this.sessions,
    required this.sessionCount,
    required this.showAllSessions,
    required this.onToggleSessions,
    required this.onCompleteNextStep,
    required this.completingSteps,
    required this.sessionController,
    required this.onRecapChanged,
    required this.onSaveRecap,
    required this.onExtractTasksFromRecap,
    required this.recapTaskCandidates,
    required this.selectedRecapTaskCandidates,
    required this.onToggleRecapTaskCandidate,
    required this.onAddSelectedRecapTasks,
  });

  final Project project;
  final List<SessionNote> sessions;
  final int sessionCount;
  final bool showAllSessions;
  final VoidCallback onToggleSessions;
  final ValueChanged<String> onCompleteNextStep;
  final Set<String> completingSteps;
  final TextEditingController sessionController;
  final ValueChanged<String> onRecapChanged;
  final VoidCallback onSaveRecap;
  final VoidCallback onExtractTasksFromRecap;
  final List<String> recapTaskCandidates;
  final Set<String> selectedRecapTaskCandidates;
  final ValueChanged<String> onToggleRecapTaskCandidate;
  final VoidCallback onAddSelectedRecapTasks;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        Text(
          project.title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(status: project.status),
            _MetaPill(
              icon: Icons.history_rounded,
              label: '$sessionCount sessions',
            ),
            _MetaPill(
              icon: Icons.checklist_rounded,
              label: '${project.nextSteps.length} next steps',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TagWrap(tags: project.tags),
        const SizedBox(height: 20),
        SectionCard(title: 'Current brief', child: Text(project.brief)),
        SectionCard(
          title: 'Next steps',
          child: project.nextSteps.isEmpty
              ? const Text(
                  'No active next steps right now. Marked steps will appear in recent sessions.',
                )
              : Column(
                  children: [
                    for (final step in project.nextSteps)
                      _NextStepTile(
                        step: step,
                        isCompleting: completingSteps.contains(step),
                        onCompleted: () => onCompleteNextStep(step),
                      ),
                  ],
                ),
        ),
        SectionCard(
          title: 'Recent sessions',
          child: _RecentSessionsSection(
            sessions: sessions,
            showAllSessions: showAllSessions,
            onToggleSessions: onToggleSessions,
          ),
        ),
        SectionCard(
          title: 'New session recap',
          child: Column(
            children: [
              TextField(
                controller: sessionController,
                maxLines: 5,
                onChanged: onRecapChanged,
                decoration: const InputDecoration(
                  hintText: 'What happened in this work session?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onSaveRecap,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save recap'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onExtractTasksFromRecap,
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    label: const Text('Create tasks from recap'),
                  ),
                ],
              ),
              if (recapTaskCandidates.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RecapTaskReview(
                  tasks: recapTaskCandidates,
                  selectedTasks: selectedRecapTaskCandidates,
                  onToggleTask: onToggleRecapTaskCandidate,
                  onAddSelectedTasks: onAddSelectedRecapTasks,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectAssistantPane extends StatelessWidget {
  const _ProjectAssistantPane({
    required this.questionController,
    required this.assistantReply,
    required this.onAsk,
  });

  final TextEditingController questionController;
  final String assistantReply;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assistant',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
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
            FilledButton(onPressed: onAsk, child: const Text('Ask')),
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
                PromptChip(
                  label: 'What happened last time?',
                  onTap: () =>
                      questionController.text = 'What happened last time?',
                ),
                PromptChip(
                  label: 'What should I work on next?',
                  onTap: () =>
                      questionController.text = 'What should I work on next?',
                ),
                PromptChip(
                  label: 'What is blocking this?',
                  onTap: () =>
                      questionController.text = 'What is blocking this?',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarProjectTile extends StatefulWidget {
  const _SidebarProjectTile({
    required this.project,
    required this.isSelected,
    required this.selectedTag,
    required this.isExpanded,
    required this.onTap,
    required this.onTagTap,
  });

  final Project project;
  final bool isSelected;
  final String? selectedTag;
  final bool isExpanded;
  final VoidCallback onTap;
  final ValueChanged<String> onTagTap;

  @override
  State<_SidebarProjectTile> createState() => _SidebarProjectTileState();
}

class _SidebarProjectTileState extends State<_SidebarProjectTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final showHover = _isHovered && !widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: showHover ? 1.01 : 1,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showExpandedTile =
                  widget.isExpanded && constraints.maxWidth >= 220;
              final showAvatar =
                  showExpandedTile && constraints.maxWidth >= 245;
              final showStatus =
                  showExpandedTile && constraints.maxWidth >= 295;
              final showTags = showExpandedTile && constraints.maxWidth >= 260;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..translateByDouble(0.0, showHover ? -2.0 : 0.0, 0.0, 1.0),
                padding: EdgeInsets.all(showExpandedTile ? 14 : 12),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? const Color(0xFFEFF4FF)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xFFB9C8F2)
                        : showHover
                        ? const Color(0xFFD0DAF0)
                        : const Color(0xFFE2E7F2),
                  ),
                  boxShadow: widget.isSelected || showHover
                      ? [
                          BoxShadow(
                            color: const Color(0xFF7F94C8).withValues(
                              alpha: widget.isSelected ? 0.12 : 0.09,
                            ),
                            blurRadius: widget.isSelected ? 18 : 14,
                            offset: const Offset(0, 10),
                          ),
                        ]
                      : const [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showExpandedTile) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showAvatar) ...[
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFE7EEFF),
                              child: Text(
                                widget.project.title.characters.first
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF3354A4),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              widget.project.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (showStatus) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: StatusChip(
                                  status: widget.project.status,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (showTags) ...[
                        const SizedBox(height: 10),
                        _TagWrap(
                          tags: widget.project.tags,
                          compact: true,
                          selectedTag: widget.selectedTag,
                          onTagTap: widget.onTagTap,
                        ),
                      ],
                    ] else
                      Center(
                        child: Text(
                          widget.project.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: widget.isSelected
                                    ? const Color(0xFF3354A4)
                                    : const Color(0xFF4E5E78),
                              ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NextStepTile extends StatefulWidget {
  const _NextStepTile({
    required this.step,
    required this.isCompleting,
    required this.onCompleted,
  });

  final String step;
  final bool isCompleting;
  final VoidCallback onCompleted;

  @override
  State<_NextStepTile> createState() => _NextStepTileState();
}

class _NextStepTileState extends State<_NextStepTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enableHover = !widget.isCompleting;
    final showHover = _isHovered && enableHover;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRect(
        child: AnimatedAlign(
          duration: kProjectsQuickAnimation,
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          heightFactor: widget.isCompleting ? 0 : 1,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            opacity: widget.isCompleting ? 0 : 1,
            child: AnimatedSlide(
              duration: kProjectsQuickAnimation,
              curve: Curves.easeOutCubic,
              offset: widget.isCompleting
                  ? const Offset(0.05, -0.08)
                  : Offset.zero,
              child: MouseRegion(
                cursor: enableHover
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  scale: showHover ? 1.008 : 1,
                  child: InkWell(
                    onTap: enableHover ? widget.onCompleted : null,
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      transform: Matrix4.identity()
                        ..translateByDouble(
                          0.0,
                          showHover ? -2.0 : 0.0,
                          0.0,
                          1.0,
                        ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: showHover
                            ? const Color(0xFFF4F8FF)
                            : const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: showHover
                              ? const Color(0xFFC9D7F1)
                              : const Color(0xFFDCE4F4),
                        ),
                        boxShadow: showHover
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF7F94C8,
                                  ).withValues(alpha: 0.08),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : const [],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: widget.isCompleting,
                            onChanged: enableHover
                                ? (_) => widget.onCompleted()
                                : null,
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(widget.step),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({
    required this.tags,
    this.compact = false,
    this.selectedTag,
    this.onTagTap,
  });

  final List<String> tags;
  final bool compact;
  final String? selectedTag;
  final ValueChanged<String>? onTagTap;

  @override
  Widget build(BuildContext context) {
    final chipSpacing = compact ? 4.0 : 8.0;
    final labelStyle = compact
        ? Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1,
            color: const Color(0xFF56647D),
          )
        : null;

    return Wrap(
      spacing: chipSpacing,
      runSpacing: chipSpacing,
      children: [
        for (final tag in tags)
          _TagChip(
            tag: tag,
            compact: compact,
            selected: selectedTag == tag,
            labelStyle: labelStyle,
            onTap: onTagTap == null ? null : () => onTagTap!(tag),
          ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.compact,
    required this.selected,
    required this.labelStyle,
    this.onTap,
  });

  final String tag;
  final bool compact;
  final bool selected;
  final TextStyle? labelStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEAF1FF) : const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? const Color(0xFFBED0F4) : const Color(0xFFDDE4F2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sell_outlined,
            size: compact ? 10 : 16,
            color: selected ? const Color(0xFF4468B5) : const Color(0xFF66758F),
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            tag,
            style: (labelStyle ?? Theme.of(context).textTheme.labelMedium)
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? const Color(0xFF4468B5)
                      : const Color(0xFF56647D),
                ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: child,
      ),
    );
  }
}

class _RecentSessionsSection extends StatelessWidget {
  const _RecentSessionsSection({
    required this.sessions,
    required this.showAllSessions,
    required this.onToggleSessions,
  });

  final List<SessionNote> sessions;
  final bool showAllSessions;
  final VoidCallback onToggleSessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Text('No sessions yet.');
    }

    final primarySessions = sessions
        .take(kDefaultVisibleRecentSessions)
        .toList();
    final additionalSessions = sessions
        .skip(kDefaultVisibleRecentSessions)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final session in primarySessions)
          _SessionEntryCard(session: session),
        ClipRect(
          child: AnimatedSize(
            duration: kProjectsQuickAnimation,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (final session in additionalSessions)
                  _ExpandableSessionEntry(
                    visible: showAllSessions,
                    child: _SessionEntryCard(session: session),
                  ),
              ],
            ),
          ),
        ),
        if (additionalSessions.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onToggleSessions,
              icon: Icon(
                showAllSessions
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(showAllSessions ? 'Show less' : 'View more'),
            ),
          ),
      ],
    );
  }
}

class _ExpandableSessionEntry extends StatelessWidget {
  const _ExpandableSessionEntry({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedAlign(
      duration: kProjectsQuickAnimation,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      heightFactor: visible ? 1 : 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        opacity: visible ? 1 : 0,
        child: AnimatedSlide(
          duration: kProjectsQuickAnimation,
          curve: Curves.easeOutCubic,
          offset: visible ? Offset.zero : const Offset(0, -0.04),
          child: child,
        ),
      ),
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
      margin: const EdgeInsets.only(bottom: 10),
      color: isCompletion ? const Color(0xFFF6FAFF) : null,
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCompletion
                ? const Color(0xFFE4F0FF)
                : const Color(0xFFF1F3F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isCompletion ? Icons.task_alt_rounded : Icons.notes_rounded,
            color: isCompletion
                ? const Color(0xFF3E67B8)
                : const Color(0xFF66758F),
            size: 18,
          ),
        ),
        title: Text(
          session.summary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: isCompletion ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
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
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE4F4)),
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
          const SizedBox(height: 6),
          Text(
            'Review the recap-derived tasks and add the ones that belong in next steps.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF61708B)),
          ),
          const SizedBox(height: 10),
          for (final task in tasks)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                value: selectedTasks.contains(task),
                onChanged: (_) => onToggleTask(task),
                title: Text(task),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
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

String _briefWithCompletionUpdate(
  String currentBrief, {
  required String completedStep,
  required int remainingSteps,
}) {
  const marker = ' Progress update: ';
  final markerIndex = currentBrief.indexOf(marker);
  final baseBrief = markerIndex >= 0
      ? currentBrief.substring(0, markerIndex).trim()
      : currentBrief.trim();
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
