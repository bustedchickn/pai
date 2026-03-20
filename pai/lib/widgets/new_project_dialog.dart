import 'package:flutter/material.dart';

import '../models/new_project_draft.dart';

class NewProjectDialog extends StatefulWidget {
  const NewProjectDialog({super.key});

  @override
  State<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<NewProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _briefController = TextEditingController();

  String _category = 'Personal';
  String _status = 'active';
  bool _includeProgress = false;
  double _progress = 0.15;

  @override
  void dispose() {
    _titleController.dispose();
    _briefController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      NewProjectDraft(
        title: _titleController.text.trim(),
        brief: _briefController.text.trim(),
        category: _category,
        status: _status,
        progress: _includeProgress ? _progress : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Project'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'pai',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Add a project title.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _briefController,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What is this project trying to do right now?',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Add a short description.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Personal',
                      child: Text('Personal'),
                    ),
                    DropdownMenuItem(value: 'Coding', child: Text('Coding')),
                    DropdownMenuItem(value: 'Work', child: Text('Work')),
                    DropdownMenuItem(
                      value: 'Creative',
                      child: Text('Creative'),
                    ),
                    DropdownMenuItem(
                      value: 'Learning',
                      child: Text('Learning'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'paused', child: Text('Paused')),
                    DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                    DropdownMenuItem(value: 'idea', child: Text('Idea')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  value: _includeProgress,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Set starting progress'),
                  subtitle: const Text('Optional for brand new ideas.'),
                  onChanged: (value) {
                    setState(() => _includeProgress = value);
                  },
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: !_includeProgress
                      ? const SizedBox.shrink()
                      : Column(
                          key: const ValueKey('progress-slider'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Starting progress: ${(_progress * 100).round()}%',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Slider(
                              value: _progress,
                              onChanged: (value) {
                                setState(() => _progress = value);
                              },
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: const Text('Create'),
        ),
      ],
    );
  }
}
