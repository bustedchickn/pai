import 'package:flutter/material.dart';

import '../data/mock_data.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

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
