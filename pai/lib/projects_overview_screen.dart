import 'package:flutter/material.dart';

import 'models/project.dart';

class ProjectsOverviewScreen extends StatefulWidget {
  const ProjectsOverviewScreen({
    super.key,
    required this.projects,
    required this.title,
    required this.subtitle,
    required this.onProjectOpen,
    this.showSearch = false,
  });

  final List<Project> projects;
  final String title;
  final String subtitle;
  final ValueChanged<String> onProjectOpen;
  final bool showSearch;

  @override
  State<ProjectsOverviewScreen> createState() => _ProjectsOverviewScreenState();
}

class _ProjectsOverviewScreenState extends State<ProjectsOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _query => _searchController.text.trim().toLowerCase();

  List<Project> get _visibleProjects {
    final sortedProjects = [...widget.projects]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    final query = _query;
    if (!widget.showSearch || query.isEmpty) {
      return sortedProjects;
    }

    return sortedProjects.where((project) {
      final searchableText = [
        project.title,
        project.brief,
        project.status,
        project.tags.join(' '),
      ].join(' ').toLowerCase();
      return searchableText.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          final horizontalPadding = isCompact ? 20.0 : 28.0;
          final topPadding = isCompact ? 20.0 : 28.0;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding,
              horizontalPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (widget.showSearch) ...[
                  const SizedBox(height: 24),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search projects',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Expanded(
                  child: _visibleProjects.isEmpty
                      ? _ProjectsOverviewEmptyState(
                          showSearch: widget.showSearch,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _visibleProjects.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final project = _visibleProjects[index];
                            return _ProjectListCard(
                              project: project,
                              onTap: () => widget.onProjectOpen(project.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProjectListCard extends StatelessWidget {
  const _ProjectListCard({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preview = _previewText(project.brief);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                preview.isEmpty ? 'No notes yet.' : preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _formatLastEdited(project.updatedAt),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectsOverviewEmptyState extends StatelessWidget {
  const _ProjectsOverviewEmptyState({required this.showSearch});

  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          showSearch
              ? 'No projects match your search.'
              : 'No projects yet. Use the new project button to start one.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

String _previewText(String rawText) {
  return rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _formatLastEdited(DateTime value) {
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
  final minute = value.minute.toString().padLeft(2, '0');
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final meridiem = value.hour >= 12 ? 'PM' : 'AM';
  return 'Edited $month ${value.day}, $hour:$minute $meridiem';
}
