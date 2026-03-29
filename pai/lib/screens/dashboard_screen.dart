import 'package:flutter/material.dart';

import '../models/board_project.dart';
import '../models/new_project_draft.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';
import '../widgets/new_project_dialog.dart';
import '../widgets/project_board.dart';
import '../widgets/project_board_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.projects,
    required this.boardProjects,
    required this.showWorkspaceStats,
    required this.onProjectOpen,
    required this.onProjectMoved,
    required this.onProjectMoveEnded,
    required this.onProjectCreated,
    required this.onOpenSettings,
    required this.onShowWorkspaceStatsChanged,
  });

  final List<Project> projects;
  final List<BoardProject> boardProjects;
  final bool showWorkspaceStats;
  final ValueChanged<String> onProjectOpen;
  final void Function(String projectId, Offset nextPosition) onProjectMoved;
  final ValueChanged<String> onProjectMoveEnded;
  final Future<void> Function(NewProjectDraft draft) onProjectCreated;
  final VoidCallback onOpenSettings;
  final ValueChanged<bool> onShowWorkspaceStatsChanged;

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

    await widget.onProjectCreated(draft);
    if (!context.mounted) {
      return;
    }

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
    final colorScheme = Theme.of(context).colorScheme;
    final paiColors = context.paiColors;
    final isMobileDashboard = MediaQuery.sizeOf(context).width < 900;
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
        ? isMobileDashboard
              ? 'Browse your projects in a quick list and tap one to open its workspace.'
              : 'Drag projects into place, pan across the canvas, and zoom for the level of detail you need.'
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
                  isMobileDashboard: isMobileDashboard,
                  searchController: _searchController,
                  showWorkspaceStats: widget.showWorkspaceStats,
                  onSearchChanged: (_) => setState(() {}),
                  onClearSearch: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  onNewProject: () => _showNewProjectDialog(context),
                  onOpenSettings: widget.onOpenSettings,
                  onToggleWorkspaceStats: () => widget
                      .onShowWorkspaceStatsChanged(!widget.showWorkspaceStats),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _WorkspaceShell(
                    title: 'workspace',
                    subtitle: helperText,
                    interactionLabel: isMobileDashboard
                        ? 'Tap to open'
                        : 'Drag, zoom, open',
                    totalVisible: visibleBoardProjects.length,
                    totalProjects: widget.boardProjects.length,
                    statusStrip: widget.showWorkspaceStats
                        ? _CompactStatusStrip(
                            metrics: [
                              _StatusStripMetric(
                                label: 'Active',
                                value: '$activeProjects',
                                icon: Icons.play_arrow_rounded,
                                tone: colorScheme.tertiary,
                              ),
                              _StatusStripMetric(
                                label: 'Due soon',
                                value: '${reminders.length}',
                                icon: Icons.schedule_rounded,
                                tone: paiColors.warningForeground,
                              ),
                              _StatusStripMetric(
                                label: 'Blocked',
                                value: '$blockedProjects',
                                icon: Icons.block_rounded,
                                tone: colorScheme.error,
                              ),
                              _StatusStripMetric(
                                label: 'Total',
                                value: '${visibleProjects.length}',
                                icon: Icons.apps_rounded,
                                tone: colorScheme.primary,
                              ),
                            ],
                          )
                        : null,
                    board: isMobileDashboard
                        ? _MobileProjectList(
                            boardProjects: visibleBoardProjects,
                            onProjectOpen: widget.onProjectOpen,
                          )
                        : GlassSurface(
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.circular(28),
                            blurSigma: 18,
                            tintColor: AppTheme.tintedSurface(
                              colorScheme.surface,
                              colorScheme.primary,
                              amount:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.18
                                  : 0.04,
                            ),
                            tintOpacity: 0.68,
                            borderOpacity: 0.54,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.surface.withValues(alpha: 0.76),
                                paiColors.boardCanvasMid.withValues(
                                  alpha: 0.86,
                                ),
                                paiColors.boardCanvasEnd.withValues(
                                  alpha: 0.76,
                                ),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: paiColors.panelShadow.withValues(
                                  alpha:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? 0.22
                                      : 0.1,
                                ),
                                blurRadius: 26,
                                offset: const Offset(0, 16),
                              ),
                            ],
                            child: ProjectBoard(
                              boardProjects: visibleBoardProjects,
                              onProjectDragged: widget.onProjectMoved,
                              onProjectDragEnded: widget.onProjectMoveEnded,
                              onProjectTap: widget.onProjectOpen,
                              onAddProjectTap: () =>
                                  _showNewProjectDialog(context),
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
    required this.isMobileDashboard,
    required this.searchController,
    required this.showWorkspaceStats,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onNewProject,
    required this.onOpenSettings,
    required this.onToggleWorkspaceStats,
  });

  final bool isMobileDashboard;
  final TextEditingController searchController;
  final bool showWorkspaceStats;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onNewProject;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleWorkspaceStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 960;
        final searchField = GlassSurface(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          borderRadius: BorderRadius.circular(20),
          blurSigma: 14,
          tintColor: AppTheme.tintedSurface(
            colorScheme.surface,
            colorScheme.primary,
            amount: isDark ? 0.14 : 0.03,
          ),
          tintOpacity: 0.7,
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
                padding: EdgeInsets.symmetric(
                  horizontal: isMobileDashboard ? 12 : 16,
                  vertical: 14,
                ),
                minimumSize: Size(isMobileDashboard ? 44 : 0, 44),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(isMobileDashboard ? 'New' : 'New project'),
            ),
            GlassSurface(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(18),
              blurSigma: 12,
              tintColor: AppTheme.tintedSurface(
                colorScheme.surface,
                colorScheme.primary,
                amount: isDark ? 0.14 : 0.03,
              ),
              tintOpacity: 0.62,
              boxShadow: const [],
              child: IconButton(
                onPressed: onToggleWorkspaceStats,
                tooltip: showWorkspaceStats
                    ? 'Hide workspace stats'
                    : 'Show workspace stats',
                icon: Icon(
                  showWorkspaceStats
                      ? Icons.bar_chart_rounded
                      : Icons.bar_chart_outlined,
                ),
              ),
            ),
            if (!isMobileDashboard)
              GlassSurface(
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(18),
                blurSigma: 12,
                tintColor: AppTheme.tintedSurface(
                  colorScheme.surface,
                  colorScheme.primary,
                  amount: isDark ? 0.14 : 0.03,
                ),
                tintOpacity: 0.62,
                boxShadow: const [],
                child: IconButton(
                  onPressed: onOpenSettings,
                  tooltip: 'Settings',
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
            _ProfileBadge(
              onOpenSettings: isMobileDashboard ? onOpenSettings : null,
            ),
          ],
        );

        Widget topBarContent;
        if (isMobileDashboard) {
          topBarContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _BrandBadge(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: actions,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              searchField,
            ],
          );
        } else if (isCompact) {
          topBarContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandBadge(),
              const SizedBox(height: 12),
              actions,
              const SizedBox(height: 12),
              searchField,
            ],
          );
        } else {
          topBarContent = Row(
            children: [
              const _BrandBadge(),
              const SizedBox(width: 16),
              Expanded(child: searchField),
              const SizedBox(width: 16),
              actions,
            ],
          );
        }

        return GlassSurface(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          borderRadius: BorderRadius.circular(24),
          blurSigma: 20,
          tintColor: AppTheme.tintedSurface(
            colorScheme.surface,
            colorScheme.primary,
            amount: isDark ? 0.18 : 0.04,
          ),
          tintOpacity: 0.66,
          borderOpacity: 0.48,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface.withValues(alpha: 0.8),
              AppTheme.tintedSurface(
                colorScheme.surface,
                colorScheme.primary,
                amount: isDark ? 0.22 : 0.08,
              ).withValues(alpha: 0.84),
              AppTheme.tintedSurface(
                colorScheme.surface,
                colorScheme.secondary,
                amount: isDark ? 0.14 : 0.04,
              ).withValues(alpha: 0.72),
            ],
          ),
          child: topBarContent,
        );
      },
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(18),
      blurSigma: 12,
      tintColor: AppTheme.tintedSurface(
        colorScheme.surface,
        colorScheme.primary,
        amount: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.06,
      ),
      tintOpacity: 0.72,
      boxShadow: const [],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.grid_view_rounded, size: 14),
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
  const _ProfileBadge({this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badge = GlassSurface(
      padding: const EdgeInsets.all(4),
      borderRadius: BorderRadius.circular(999),
      blurSigma: 12,
      tintColor: AppTheme.tintedSurface(
        colorScheme.surface,
        colorScheme.primary,
        amount: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.03,
      ),
      tintOpacity: 0.62,
      boxShadow: const [],
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.tintedSurface(
          colorScheme.surface,
          colorScheme.primary,
          amount: Theme.of(context).brightness == Brightness.dark ? 0.24 : 0.12,
        ),
        child: Text(
          'P',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
          ),
        ),
      ),
    );

    if (onOpenSettings == null) {
      return badge;
    }

    return PopupMenuButton<_ProfileMenuAction>(
      tooltip: 'Profile',
      onSelected: (action) {
        switch (action) {
          case _ProfileMenuAction.settings:
            onOpenSettings?.call();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<_ProfileMenuAction>(
          value: _ProfileMenuAction.settings,
          child: Row(
            children: [
              Icon(Icons.settings_outlined),
              SizedBox(width: 12),
              Text('Settings'),
            ],
          ),
        ),
      ],
      child: badge,
    );
  }
}

enum _ProfileMenuAction { settings }

class _WorkspaceShell extends StatelessWidget {
  const _WorkspaceShell({
    required this.title,
    required this.subtitle,
    required this.interactionLabel,
    required this.totalVisible,
    required this.totalProjects,
    required this.statusStrip,
    required this.board,
  });

  final String title;
  final String subtitle;
  final String interactionLabel;
  final int totalVisible;
  final int totalProjects;
  final Widget? statusStrip;
  final Widget board;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final paiColors = context.paiColors;
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      borderRadius: BorderRadius.circular(32),
      blurSigma: 24,
      tintColor: AppTheme.tintedSurface(
        colorScheme.surface,
        colorScheme.primary,
        amount: isDark ? 0.18 : 0.04,
      ),
      tintOpacity: 0.58,
      borderOpacity: 0.46,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.surface.withValues(alpha: 0.72),
          paiColors.boardCanvasMid.withValues(alpha: 0.8),
          paiColors.boardCanvasEnd.withValues(alpha: 0.66),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: paiColors.panelShadow.withValues(alpha: isDark ? 0.24 : 0.12),
          blurRadius: 28,
          offset: const Offset(0, 18),
        ),
      ],
      child: Column(
        children: [
          _WorkspaceHeader(
            title: title,
            subtitle: subtitle,
            interactionLabel: interactionLabel,
            totalVisible: totalVisible,
            totalProjects: totalProjects,
          ),
          if (statusStrip != null) ...[
            const SizedBox(height: 8),
            statusStrip!,
            const SizedBox(height: 10),
          ],
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
    required this.interactionLabel,
    required this.totalVisible,
    required this.totalProjects,
  });

  final String title;
  final String subtitle;
  final String interactionLabel;
  final int totalVisible;
  final int totalProjects;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                color: colorScheme.onSurfaceVariant,
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
            _MiniInfoPill(
              icon: Icons.touch_app_rounded,
              label: interactionLabel,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: BorderRadius.circular(999),
      blurSigma: 12,
      tintColor: AppTheme.tintedSurface(
        colorScheme.surface,
        colorScheme.primary,
        amount: isDark ? 0.14 : 0.03,
      ),
      tintOpacity: 0.68,
      borderOpacity: 0.42,
      boxShadow: const [],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileProjectList extends StatelessWidget {
  const _MobileProjectList({
    required this.boardProjects,
    required this.onProjectOpen,
  });

  final List<BoardProject> boardProjects;
  final ValueChanged<String> onProjectOpen;

  @override
  Widget build(BuildContext context) {
    if (boardProjects.isEmpty) {
      return const _MobileProjectListEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth.clamp(0.0, 420.0).toDouble();
        final cardHeight = cardWidth * 0.47;
        return Align(
          alignment: Alignment.topCenter,
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            itemCount: boardProjects.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final boardProject = boardProjects[index];
              return Center(
                child: SizedBox(
                  width: cardWidth,
                  child: GestureDetector(
                    onTap: () => onProjectOpen(boardProject.id),
                    child: ProjectBoardCard(
                      boardProject: boardProject,
                      width: cardWidth,
                      height: cardHeight,
                      briefMaxLines: 2,
                      dense: true,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MobileProjectListEmptyState extends StatelessWidget {
  const _MobileProjectListEmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'No projects match your current search.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _CompactStatusStrip extends StatelessWidget {
  const _CompactStatusStrip({required this.metrics});

  final List<_StatusStripMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final metric in metrics) _StatusPill(metric: metric)],
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      borderRadius: BorderRadius.circular(16),
      blurSigma: 12,
      tintColor: AppTheme.tintedSurface(
        colorScheme.surface,
        metric.tone,
        amount: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.03,
      ),
      tintOpacity: 0.58,
      borderOpacity: 0.3,
      boxShadow: const [],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 108),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppTheme.tintedSurface(
                  colorScheme.surface,
                  metric.tone,
                  amount: Theme.of(context).brightness == Brightness.dark
                      ? 0.2
                      : 0.1,
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Icon(metric.icon, size: 15, color: metric.tone),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric.value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  metric.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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
