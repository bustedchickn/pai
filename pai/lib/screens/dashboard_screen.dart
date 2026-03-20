import 'package:flutter/material.dart';

import '../models/board_project.dart';
import '../models/new_project_draft.dart';
import '../models/project.dart';
import '../widgets/glass_surface.dart';
import '../widgets/new_project_dialog.dart';
import '../widgets/project_board.dart';

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${draft.title} was added to pai.')));
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
        boardProject.tags.join(' '),
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
        ? 'Drag projects into place, pan across the canvas, and zoom for the level of detail you need.'
        : 'Showing ${visibleBoardProjects.length} of ${widget.boardProjects.length} projects for "${_searchController.text.trim()}".';

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 980;
          final horizontalPadding = isCompact ? 12.0 : 18.0;
          final topSpacing = isCompact ? 10.0 : 14.0;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topSpacing,
              horizontalPadding,
              12,
            ),
            child: Column(
              children: [
                _DashboardTopBar(
                  searchController: _searchController,
                  onSearchChanged: (_) => setState(() {}),
                  onClearSearch: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  onNewProject: () => _showNewProjectDialog(context),
                  onOpenSettings: widget.onOpenSettings,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _WorkspaceShell(
                    title: 'workspace',
                    subtitle: helperText,
                    totalVisible: visibleBoardProjects.length,
                    totalProjects: widget.boardProjects.length,
                    statusStrip: _CompactStatusStrip(
                      metrics: [
                        _StatusStripMetric(
                          label: 'Active',
                          value: '$activeProjects',
                          icon: Icons.play_arrow_rounded,
                          tone: const Color(0xFF1E9E5A),
                        ),
                        _StatusStripMetric(
                          label: 'Due soon',
                          value: '${reminders.length}',
                          icon: Icons.schedule_rounded,
                          tone: const Color(0xFFB87413),
                        ),
                        _StatusStripMetric(
                          label: 'Blocked',
                          value: '$blockedProjects',
                          icon: Icons.block_rounded,
                          tone: const Color(0xFFC25757),
                        ),
                        _StatusStripMetric(
                          label: 'Total',
                          value: '${visibleProjects.length}',
                          icon: Icons.apps_rounded,
                          tone: const Color(0xFF4867B7),
                        ),
                      ],
                    ),
                    board: GlassSurface(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(28),
                      blurSigma: 18,
                      tintColor: const Color(0xFFF4F8FF),
                      tintOpacity: 0.56,
                      borderOpacity: 0.54,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.34),
                          const Color(0xFFEAF1FF).withValues(alpha: 0.52),
                          const Color(0xFFFFFCF6).withValues(alpha: 0.42),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7589BC).withValues(alpha: 0.1),
                          blurRadius: 26,
                          offset: const Offset(0, 16),
                        ),
                      ],
                      child: ProjectBoard(
                        boardProjects: visibleBoardProjects,
                        onProjectDragged: widget.onProjectMoved,
                        onProjectDragEnded: widget.onProjectMoveEnded,
                        onProjectTap: widget.onProjectOpen,
                        onAddProjectTap: () => _showNewProjectDialog(context),
                        boardWidth: ProjectBoard.defaultBoardWidth,
                        boardHeight: ProjectBoard.defaultBoardHeight,
                        cardWidth: ProjectBoard.defaultCardWidth,
                        cardHeight: ProjectBoard.defaultCardHeight,
                      ),
                    ),
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

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
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
        final isCompact = constraints.maxWidth < 960;
        final searchField = GlassSurface(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          borderRadius: BorderRadius.circular(20),
          blurSigma: 14,
          tintColor: const Color(0xFFF9FBFF),
          tintOpacity: 0.62,
          borderOpacity: 0.42,
          highlightOpacity: 0.28,
          boxShadow: const [],
          child: SizedBox(
            height: 48,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search projects, categories, or status',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onNewProject,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3557A5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New project'),
            ),
            GlassSurface(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(18),
              blurSigma: 12,
              tintColor: const Color(0xFFF8FBFF),
              tintOpacity: 0.48,
              boxShadow: const [],
              child: IconButton(
                onPressed: onOpenSettings,
                tooltip: 'Settings',
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
            const _ProfileBadge(),
          ],
        );

        return GlassSurface(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          borderRadius: BorderRadius.circular(24),
          blurSigma: 20,
          tintColor: const Color(0xFFF4F8FF),
          tintOpacity: 0.56,
          borderOpacity: 0.48,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.36),
              const Color(0xFFEAF2FF).withValues(alpha: 0.5),
              const Color(0xFFFFFCF7).withValues(alpha: 0.34),
            ],
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _BrandBadge(),
                        const Spacer(),
                        actions,
                      ],
                    ),
                    const SizedBox(height: 12),
                    searchField,
                  ],
                )
              : Row(
                  children: [
                    const _BrandBadge(),
                    const SizedBox(width: 16),
                    Expanded(child: searchField),
                    const SizedBox(width: 16),
                    actions,
                  ],
                ),
        );
      },
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(18),
      blurSigma: 12,
      tintColor: const Color(0xFFEFF4FF),
      tintOpacity: 0.64,
      boxShadow: const [],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF3557A5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3557A5).withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'pai',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(4),
      borderRadius: BorderRadius.circular(999),
      blurSigma: 12,
      tintColor: const Color(0xFFF8FBFF),
      tintOpacity: 0.5,
      boxShadow: const [],
      child: const CircleAvatar(
        radius: 18,
        backgroundColor: Color(0xFFE8EEFF),
        child: Text(
          'P',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF3557A5),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceShell extends StatelessWidget {
  const _WorkspaceShell({
    required this.title,
    required this.subtitle,
    required this.totalVisible,
    required this.totalProjects,
    required this.statusStrip,
    required this.board,
  });

  final String title;
  final String subtitle;
  final int totalVisible;
  final int totalProjects;
  final Widget statusStrip;
  final Widget board;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      borderRadius: BorderRadius.circular(32),
      blurSigma: 24,
      tintColor: const Color(0xFFF4F8FF),
      tintOpacity: 0.44,
      borderOpacity: 0.46,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.3),
          const Color(0xFFEAF2FF).withValues(alpha: 0.42),
          const Color(0xFFFFFBF5).withValues(alpha: 0.28),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF8093BE).withValues(alpha: 0.12),
          blurRadius: 28,
          offset: const Offset(0, 18),
        ),
      ],
      child: Column(
        children: [
          _WorkspaceHeader(
            title: title,
            subtitle: subtitle,
            totalVisible: totalVisible,
            totalProjects: totalProjects,
          ),
          const SizedBox(height: 10),
          statusStrip,
          const SizedBox(height: 12),
          Expanded(child: board),
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
  });

  final String title;
  final String subtitle;
  final int totalVisible;
  final int totalProjects;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: isCompact ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF586783),
              ),
            ),
          ],
        );

        final meta = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            _MiniInfoPill(
              icon: Icons.grid_on_rounded,
              label: '$totalVisible visible',
            ),
            _MiniInfoPill(
              icon: Icons.layers_rounded,
              label: '$totalProjects total',
            ),
            const _MiniInfoPill(
              icon: Icons.touch_app_rounded,
              label: 'Drag, zoom, open',
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              info,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: meta),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: info),
            const SizedBox(width: 20),
            Expanded(
              child: Align(alignment: Alignment.topRight, child: meta),
            ),
          ],
        );
      },
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  const _MiniInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: BorderRadius.circular(999),
      blurSigma: 12,
      tintColor: const Color(0xFFF8FBFF),
      tintOpacity: 0.58,
      borderOpacity: 0.42,
      boxShadow: const [],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF5F6E8C)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF495871),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStatusStrip extends StatelessWidget {
  const _CompactStatusStrip({required this.metrics});

  final List<_StatusStripMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final metric in metrics) _StatusPill(metric: metric)],
    );
  }
}

class _StatusStripMetric {
  const _StatusStripMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.metric});

  final _StatusStripMetric metric;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: BorderRadius.circular(18),
      blurSigma: 14,
      tintColor: const Color(0xFFF9FBFF),
      tintOpacity: 0.6,
      borderOpacity: 0.42,
      boxShadow: const [],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 116),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: metric.tone.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              child: Icon(metric.icon, size: 16, color: metric.tone),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric.value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  metric.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF5B6985),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
