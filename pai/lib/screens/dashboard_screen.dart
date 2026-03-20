import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/board_project.dart';
import '../widgets/info_card.dart';
import '../widgets/project_board.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late List<BoardProject> boardProjects;

  @override
  void initState() {
    super.initState();
    boardProjects = List<BoardProject>.from(mockBoardProjects);
  }

  @override
  Widget build(BuildContext context) {
    final reminders = mockProjects
        .expand((project) => project.reminders)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              'pai',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your dashboard is a central hub for active projects, progress, and upcoming work.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            const Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                InfoCard(title: 'Active projects', value: '2'),
                InfoCard(title: 'Due soon', value: '3'),
                InfoCard(title: 'Recent sessions', value: '3'),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Project hub',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list_outlined),
                  label: const Text('Sort / Filter'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Projects float in the center as quick-glance cards with title, description, progress, category, and status.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ProjectBoard(
              boardProjects: boardProjects,
              onProjectDragged: (projectId, nextPosition) {
                setState(() {
                  boardProjects = [
                    for (final boardProject in boardProjects)
                      boardProject.id == projectId
                          ? boardProject.copyWith(boardPosition: nextPosition)
                          : boardProject,
                  ];
                });
              },
              onProjectDragEnded: (_) {},
              onAddProjectTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Project creation flow comes next.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Calendar preview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Notifications will live here'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming reminders',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: reminders.isEmpty
                          ? const Text('No reminders yet.')
                          : Column(
                              children: reminders
                                  .map(
                                    (reminder) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today_outlined,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  reminder.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '${reminder.projectTitle} - ${reminder.dueLabel}',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Later, this section can become a true calendar view with reminders and deadlines laid out by date.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
