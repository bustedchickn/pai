import 'package:flutter/material.dart';

import 'models/project.dart';
import 'models/project_document.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({
    super.key,
    required this.projects,
    required this.documents,
  });

  final List<Project> projects;
  final List<ProjectDocument> documents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reminders = projects.expand((project) => project.reminders).toList();
    final activeProjects = projects
        .where((project) => project.status.toLowerCase() == 'active')
        .length;
    final blockedProjects = projects
        .where((project) => project.status.toLowerCase() == 'blocked')
        .length;
    final totalWords =
        [
              for (final project in projects) project.brief,
              for (final document in documents) document.content,
            ]
            .map((text) => text.trim())
            .where((text) => text.isNotEmpty)
            .fold<int>(
              0,
              (sum, text) => sum + text.split(RegExp(r'\s+')).length,
            );

    DateTime? lastEdited;
    for (final project in projects) {
      if (lastEdited == null || project.updatedAt.isAfter(lastEdited)) {
        lastEdited = project.updatedAt;
      }
    }
    for (final document in documents) {
      if (lastEdited == null || document.updatedAt.isAfter(lastEdited)) {
        lastEdited = document.updatedAt;
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Text(
              'Stats',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A simple snapshot of your workspace without extra controls.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatsCard(label: 'Projects', value: '${projects.length}'),
                _StatsCard(label: 'Active', value: '$activeProjects'),
                _StatsCard(label: 'Blocked', value: '$blockedProjects'),
                _StatsCard(
                  label: 'Pages',
                  value: '${documents.length + projects.length}',
                ),
                _StatsCard(label: 'Words', value: '$totalWords'),
                _StatsCard(
                  label: 'Last edited',
                  value: lastEdited == null
                      ? 'No activity'
                      : _formatStatsTimestamp(lastEdited),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Reminders',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (reminders.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'No reminders yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...reminders.map(
                (reminder) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(reminder.title),
                      subtitle: Text(reminder.projectTitle),
                      trailing: Text(
                        reminder.dueLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
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

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 148, maxWidth: 220),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatStatsTimestamp(DateTime value) {
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
  return '$month ${value.day}';
}
