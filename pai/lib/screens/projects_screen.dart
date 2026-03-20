import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/session_note.dart';
import '../widgets/prompt_chip.dart';
import '../widgets/section_card.dart';
import '../widgets/status_chip.dart';

const int kDefaultVisibleRecentSessions = 3;

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
  bool _showAllSessions = false;
  String _assistantReply =
      'Ask about a project to see a summary, blockers, or next steps.';

  @override
  void initState() {
    super.initState();
    _selectedProject = widget.projects.first;
    _applyRequestedSelection();
  }

  @override
  void didUpdateWidget(covariant ProjectsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousSelectionId = _selectedProject.id;
    _selectedProject = _projectForId(previousSelectionId);

    if (widget.selectionRequestId != oldWidget.selectionRequestId) {
      _applyRequestedSelection();
    }
  }

  @override
  void dispose() {
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

  void _applyRequestedSelection() {
    if (widget.selectedProjectId == null) {
      return;
    }

    _selectedProject = _projectForId(widget.selectedProjectId);
    _resetProjectScopedUi();
  }

  void _resetProjectScopedUi() {
    _showAllSessions = false;
    _assistantReply =
        'Ask about a project to see a summary, blockers, or next steps.';
  }

  void _selectProject(Project project) {
    setState(() {
      _selectedProject = project;
      _resetProjectScopedUi();
    });
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

  void _completeNextStep(String step) {
    final remainingSteps = [
      for (final nextStep in _selectedProject.nextSteps)
        if (nextStep != step) nextStep,
    ];
    final completionNote = SessionNote(
      id: 'session-${DateTime.now().microsecondsSinceEpoch}',
      dateLabel: 'Just now',
      summary: 'Completed next step: $step',
    );
    final updatedProject = _selectedProject.copyWith(
      nextSteps: remainingSteps,
      sessions: [completionNote, ..._selectedProject.sessions],
    );

    widget.onProjectUpdated(updatedProject);
    setState(() {
      _selectedProject = updatedProject;
      _assistantReply = 'Marked "$step" complete and added it to recent sessions.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleSessions = _showAllSessions
        ? _selectedProject.sessions
        : _selectedProject.sessions
              .take(kDefaultVisibleRecentSessions)
              .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1120;
            final projectList = _ProjectsSidebar(
              projects: widget.projects,
              selectedProjectId: _selectedProject.id,
              onProjectSelected: _selectProject,
            );
            final detailPane = _ProjectDetailPane(
              project: _selectedProject,
              visibleSessions: visibleSessions,
              showAllSessions: _showAllSessions,
              onToggleSessions: () {
                setState(() => _showAllSessions = !_showAllSessions);
              },
              onCompleteNextStep: _completeNextStep,
              sessionController: _sessionController,
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
                  SizedBox(width: 340, child: projectList),
                  const SizedBox(width: 20),
                  Expanded(child: detailPane),
                  const SizedBox(width: 20),
                  SizedBox(width: 320, child: assistantPane),
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
    required this.onProjectSelected,
  });

  final List<Project> projects;
  final String selectedProjectId;
  final ValueChanged<Project> onProjectSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Projects',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse the rest of your projects and jump between them quickly.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF61708B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: projects.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final project = projects[index];
                final isSelected = project.id == selectedProjectId;

                return InkWell(
                  onTap: () => onProjectSelected(project),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEFF4FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFB9C8F2)
                            : const Color(0xFFE2E7F2),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF7F94C8).withValues(
                                  alpha: 0.12,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ]
                          : const [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFE7EEFF),
                              child: Text(
                                project.title.characters.first.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF3354A4),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                project.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusChip(status: project.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _TagWrap(tags: project.tags),
                      ],
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

class _ProjectDetailPane extends StatelessWidget {
  const _ProjectDetailPane({
    required this.project,
    required this.visibleSessions,
    required this.showAllSessions,
    required this.onToggleSessions,
    required this.onCompleteNextStep,
    required this.sessionController,
  });

  final Project project;
  final List<SessionNote> visibleSessions;
  final bool showAllSessions;
  final VoidCallback onToggleSessions;
  final ValueChanged<String> onCompleteNextStep;
  final TextEditingController sessionController;

  @override
  Widget build(BuildContext context) {
    final hasMoreSessions =
        project.sessions.length > kDefaultVisibleRecentSessions;

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
              label: '${project.sessions.length} sessions',
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
        SectionCard(
          title: 'Current brief',
          child: Text(project.brief),
        ),
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
                        onCompleted: () => onCompleteNextStep(step),
                      ),
                  ],
                ),
        ),
        SectionCard(
          title: 'Recent sessions',
          child: project.sessions.isEmpty
              ? const Text('No sessions yet.')
              : Column(
                  children: [
                    for (final session in visibleSessions)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(session.summary),
                          subtitle: Text(session.dateLabel),
                        ),
                      ),
                    if (hasMoreSessions)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onToggleSessions,
                          icon: Icon(
                            showAllSessions
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                          ),
                          label: Text(
                            showAllSessions ? 'Show less' : 'View more',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        SectionCard(
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
            FilledButton(
              onPressed: onAsk,
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
                PromptChip(
                  label: 'What happened last time?',
                  onTap: () => questionController.text = 'What happened last time?',
                ),
                PromptChip(
                  label: 'What should I work on next?',
                  onTap: () =>
                      questionController.text = 'What should I work on next?',
                ),
                PromptChip(
                  label: 'What is blocking this?',
                  onTap: () => questionController.text = 'What is blocking this?',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStepTile extends StatelessWidget {
  const _NextStepTile({required this.step, required this.onCompleted});

  final String step;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onCompleted,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE4F4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: false,
                onChanged: (_) => onCompleted(),
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(step),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          Chip(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            avatar: const Icon(Icons.sell_outlined, size: 16),
            label: Text(tag),
          ),
      ],
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
