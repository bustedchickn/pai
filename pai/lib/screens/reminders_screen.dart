import 'package:flutter/material.dart';

import '../models/project.dart';

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
