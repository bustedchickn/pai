import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/project.dart';
import '../widgets/prompt_chip.dart';
import '../widgets/section_card.dart';
import '../widgets/status_chip.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  Project selectedProject = mockProjects.first;
  final TextEditingController sessionController = TextEditingController();
  final TextEditingController questionController = TextEditingController();
  String assistantReply =
      'Ask about a project to see a summary, blockers, or next steps.';

  @override
  void dispose() {
    sessionController.dispose();
    questionController.dispose();
    super.dispose();
  }

  void askAssistant() {
    final input = questionController.text.toLowerCase();
    if (input.trim().isEmpty) {
      return;
    }

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
                itemCount: mockProjects.length,
                itemBuilder: (context, index) {
                  final project = mockProjects[index];
                  final isSelected = project.id == selectedProject.id;

                  return ListTile(
                    selected: isSelected,
                    leading: CircleAvatar(
                      child: Text(project.title.substring(0, 1)),
                    ),
                    title: Text(project.title),
                    subtitle: Text(
                      project.brief,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: StatusChip(status: project.status),
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
                    StatusChip(status: selectedProject.status),
                    const SizedBox(width: 8),
                    Text('${selectedProject.sessions.length} sessions'),
                  ],
                ),
                const SizedBox(height: 20),
                SectionCard(
                  title: 'Current brief',
                  child: Text(selectedProject.brief),
                ),
                SectionCard(
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
                SectionCard(
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
                        PromptChip(
                          label: 'What happened last time?',
                          onTap: () {
                            questionController.text =
                                'What happened last time?';
                          },
                        ),
                        PromptChip(
                          label: 'What should I work on next?',
                          onTap: () {
                            questionController.text =
                                'What should I work on next?';
                          },
                        ),
                        PromptChip(
                          label: 'What is blocking this?',
                          onTap: () {
                            questionController.text = 'What is blocking this?';
                          },
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
