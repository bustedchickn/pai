                                           import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/board_project.dart';
import '../services/board_hover_sound_player.dart';
import '../theme/app_theme.dart';
import 'glass_surface.dart';
import 'project_board_card.dart';

typedef ProjectBoardDragCallback =
    void Function(String projectId, Offset nextPosition);
typedef ProjectBoardTapCallback = void Function(String projectId);
typedef ProjectBoardDragEndCallback = void Function(String projectId);

class ProjectBoard extends StatefulWidget {
  const ProjectBoard({
    super.key,
    required this.boardProjects,
    required this.onProjectDragged,
    required this.onAddProjectTap,
    this.onProjectTap,
    this.onProjectDragEnded,
    this.enableHoverSounds = false,
    this.viewportHeight,
    this.boardWidth = defaultBoardWidth,
    this.boardHeight = defaultBoardHeight,
    this.cardWidth = defaultCardWidth,
    this.cardHeight = defaultCardHeight,
    this.newProjectCardPosition,
  });

  final List<BoardProject> boardProjects;
  final ProjectBoardDragCallback onProjectDragged;
  final VoidCallback onAddProjectTap;
  final ProjectBoardTapCallback? onProjectTap;
  final ProjectBoardDragEndCallback? onProjectDragEnded;
  final bool enableHoverSounds;
  final double? viewportHeight;
  final double boardWidth;
  final double boardHeight;
  final double cardWidth;
  final double cardHeight;
  final Offset? newProjectCardPosition;

  static const double defaultBoardWidth = 2500;
  static const double defaultBoardHeight = 1600;
  static const double defaultViewportHeight = 760;
  static const double defaultCardWidth = 220;
  static const double defaultCardHeight = 196;
  static const double minScaleFloor = 0.22;
  static const double maxScale = 2.8;

  @override
  State<ProjectBoard> createState() => _ProjectBoardState();
}

class _ProjectBoardState extends State<ProjectBoard>
    with SingleTickerProviderStateMixin {
  static const Duration _resetCollapseDelay = Duration(milliseconds: 2300);

  final GlobalKey _boardViewportKey = GlobalKey();
  final BoardHoverSoundPlayer _soundPlayer = BoardHoverSoundPlayer();

  late final AnimationController _idleController;
  late final TransformationController _transformationController;
  late List<String> _renderOrder;

  Timer? _resetCollapseTimer;
  Size _viewportSize = Size.zero;
  bool _hasInitializedView = false;
  bool _hasCustomizedViewport = false;
  bool _isPointerOverBoard = false;
  bool _isPointerNearResetArea = false;
  bool _isResetControlHovered = false;
  bool _isResetControlExpanded = true;
  String? _hoveredProjectId;
  String? _pressedProjectId;
  String? _draggingProjectId;
  Offset? _dragGrabOffset;

  @override
  void initState() {
    super.initState();
    _soundPlayer.enabled = widget.enableHoverSounds;
    unawaited(_soundPlayer.warmUp());
    _transformationController = TransformationController();
    _renderOrder = [for (final project in widget.boardProjects) project.id];
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
    _scheduleResetControlCollapse();
  }

  @override
  void didUpdateWidget(covariant ProjectBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _soundPlayer.enabled = widget.enableHoverSounds;
    final knownIds = _renderOrder.toSet();
    final nextOrder = [
      for (final id in _renderOrder)
        if (widget.boardProjects.any((project) => project.id == id)) id,
      for (final project in widget.boardProjects)
        if (!knownIds.contains(project.id)) project.id,
    ];

    if (!_sameOrder(_renderOrder, nextOrder)) {
      _renderOrder = nextOrder;
    }
  }

  @override
  void dispose() {
    _resetCollapseTimer?.cancel();
    _soundPlayer.dispose();
    _transformationController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  void _clearPressed(String projectId) {
    if (_pressedProjectId != projectId) {
      return;
    }

    setState(() => _pressedProjectId = null);
  }

  bool _sameOrder(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }

  void _bringProjectToFront(String projectId) {
    if (_renderOrder.isNotEmpty && _renderOrder.last == projectId) {
      return;
    }

    setState(() {
      _renderOrder = [
        for (final id in _renderOrder)
          if (id != projectId) id,
        projectId,
      ];
    });
  }

  List<BoardProject> get _orderedBoardProjects {
    final orderIndex = {
      for (var index = 0; index < _renderOrder.length; index++)
        _renderOrder[index]: index,
    };

    final sortedProjects = [...widget.boardProjects];
    sortedProjects.sort((left, right) {
      final leftIndex = orderIndex[left.id] ?? -1;
      final rightIndex = orderIndex[right.id] ?? -1;
      return leftIndex.compareTo(rightIndex);
    });
    return sortedProjects;
  }

  Offset _idleOffsetFor(BoardProject boardProject) {
    final isInteractive =
        _hoveredProjectId == boardProject.id ||
        _pressedProjectId == boardProject.id ||
        _draggingProjectId == boardProject.id;

    if (isInteractive) {
      return Offset.zero;
    }

    final seed = boardProject.id.codeUnits.fold<int>(
      0,
      (sum, unit) => sum + unit,
    );
    final phase = seed * 0.37;
    final time = _idleController.value * math.pi * 2;
    final dx = math.sin(time + phase) * (3 + (seed % 3));
    final dy = math.cos((time * 0.75) + phase) * (2 + (seed % 2));
    return Offset(dx, dy);
  }

  double _currentScale() {
    return math.max(
      _transformationController.value.getMaxScaleOnAxis(),
      0.0001,
    );
  }

  Offset _currentBoardPosition(BoardProject boardProject) {
    final currentProject = widget.boardProjects.firstWhere(
      (project) => project.id == boardProject.id,
      orElse: () => boardProject,
    );
    return currentProject.boardPosition;
  }

  double get _maxCardX =>
      math.max(widget.boardWidth - widget.cardWidth - 56, 0);

  double get _maxCardY =>
      math.max(widget.boardHeight - widget.cardHeight - 56, 0);

  Offset get _newProjectCardPosition =>
      widget.newProjectCardPosition ??
      Offset(widget.boardWidth - 252, widget.boardHeight - 206);

  Offset? _scenePositionForGlobal(Offset globalPosition) {
    final renderObject =
        _boardViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObject == null) {
      return null;
    }

    final viewportPosition = renderObject.globalToLocal(globalPosition);
    return _transformationController.toScene(viewportPosition);
  }

  double _minimumScaleFor(Size viewportSize) {
    final availableWidth = math.max(viewportSize.width - 72, 1);
    final availableHeight = math.max(viewportSize.height - 72, 1);
    final fitScale = math.min(
      availableWidth / widget.boardWidth,
      availableHeight / widget.boardHeight,
    );
    return (fitScale * 0.96).clamp(ProjectBoard.minScaleFloor, 0.62).toDouble();
  }

  double _resetScaleFor(Size viewportSize) {
    final minimumScale = _minimumScaleFor(viewportSize);
    return math
        .max(minimumScale * 1.9, 0.84)
        .clamp(minimumScale, 1.0)
        .toDouble();
  }

  Matrix4 _buildResetTransform(Size viewportSize) {
    if (viewportSize.isEmpty) {
      return Matrix4.identity();
    }

    final scale = _resetScaleFor(viewportSize);
    final dx = (viewportSize.width - (widget.boardWidth * scale)) / 2;
    final dy =
        ((viewportSize.height - (widget.boardHeight * scale)) / 2) -
        math.min(26.0, viewportSize.height * 0.05);

    return Matrix4.translationValues(dx, dy, 0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
  }

  void _syncViewport(Size viewportSize) {
    final sizeChanged =
        (viewportSize.width - _viewportSize.width).abs() > 0.5 ||
        (viewportSize.height - _viewportSize.height).abs() > 0.5;

    _viewportSize = viewportSize;
    if (!sizeChanged && _hasInitializedView) {
      return;
    }

    if (!_hasInitializedView || !_hasCustomizedViewport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _viewportSize.isEmpty) {
          return;
        }
        _transformationController.value = _buildResetTransform(_viewportSize);
      });
    }

    _hasInitializedView = true;
  }

  void _revealResetControl({bool scheduleCollapse = true}) {
    _resetCollapseTimer?.cancel();

    if (!_isResetControlExpanded) {
      setState(() => _isResetControlExpanded = true);
    }

    if (scheduleCollapse) {
      _scheduleResetControlCollapse();
    }
  }

  void _scheduleResetControlCollapse() {
    _resetCollapseTimer?.cancel();
    _resetCollapseTimer = Timer(_resetCollapseDelay, () {
      if (!mounted || _isPointerNearResetArea || _isResetControlHovered) {
        return;
      }

      if (_isResetControlExpanded) {
        setState(() => _isResetControlExpanded = false);
      }
    });
  }

  void _noteBoardInteraction({bool scheduleCollapse = true}) {
    _hasCustomizedViewport = true;
    _revealResetControl(scheduleCollapse: scheduleCollapse);
  }

  bool _isNearResetArea(Offset localPosition) {
    if (_viewportSize.isEmpty) {
      return false;
    }

    final activeWidth = math.min(240.0, _viewportSize.width * 0.32);
    return localPosition.dx >= _viewportSize.width - activeWidth &&
        localPosition.dy <= 100;
  }

  void _handleBoardHover(PointerHoverEvent event) {
    final isNearResetArea = _isNearResetArea(event.localPosition);
    if (isNearResetArea != _isPointerNearResetArea) {
      setState(() => _isPointerNearResetArea = isNearResetArea);
    }

    if (isNearResetArea) {
      _revealResetControl(scheduleCollapse: false);
    } else if (!_isResetControlHovered) {
      _scheduleResetControlCollapse();
    }
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    final currentScale = _currentScale();
    final scrollDelta = event.scrollDelta.dy;
    final zoomFactor = math.exp(-scrollDelta / 240);
    final targetScale = (currentScale * zoomFactor).clamp(
      _viewportSize.isEmpty
          ? ProjectBoard.minScaleFloor
          : _minimumScaleFor(_viewportSize),
      ProjectBoard.maxScale,
    );
    final scaleDelta = targetScale / currentScale;

    if ((scaleDelta - 1).abs() < 0.001) {
      return;
    }

    _noteBoardInteraction();

    final focalPoint = event.localPosition;
    final zoomMatrix = Matrix4.identity()
      ..multiply(Matrix4.translationValues(focalPoint.dx, focalPoint.dy, 0))
      ..multiply(Matrix4.diagonal3Values(scaleDelta, scaleDelta, 1))
      ..multiply(Matrix4.translationValues(-focalPoint.dx, -focalPoint.dy, 0));

    zoomMatrix.multiply(_transformationController.value);
    _transformationController.value = zoomMatrix;
  }

  void _resetBoardView() {
    _hasCustomizedViewport = false;
    _transformationController.value = _buildResetTransform(_viewportSize);
    _revealResetControl();
  }

  @override
  Widget build(BuildContext context) {
    final paiColors = context.paiColors;
    final viewportChild = LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        _syncViewport(viewportSize);
        final minScale = _minimumScaleFor(viewportSize);

        return Container(
          key: _boardViewportKey,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                paiColors.boardCanvasStart,
                paiColors.boardCanvasMid,
                paiColors.boardCanvasEnd,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(320),
                  minScale: minScale,
                  maxScale: ProjectBoard.maxScale,
                  onInteractionStart: (_) =>
                      _noteBoardInteraction(scheduleCollapse: false),
                  onInteractionUpdate: (_) =>
                      _noteBoardInteraction(scheduleCollapse: false),
                  onInteractionEnd: (_) => _scheduleResetControlCollapse(),
                  child: AnimatedBuilder(
                    animation: _idleController,
                    builder: (context, child) {
                      return SizedBox(
                        width: widget.boardWidth,
                        height: widget.boardHeight,
                        child: Stack(
                          children: [
                            _BoardBackdrop(
                              boardWidth: widget.boardWidth,
                              boardHeight: widget.boardHeight,
                            ),
                            Positioned(
                              left: 40,
                              top: 32,
                              child: const _BoardZoneLabel(title: 'Now'),
                            ),
                            Positioned(
                              left: widget.boardWidth - 144,
                              top: 32,
                              child: const _BoardZoneLabel(title: 'Soon'),
                            ),
                            Positioned(
                              left: 40,
                              top: widget.boardHeight - 92,
                              child: const _BoardZoneLabel(title: 'Ideas'),
                            ),
                            Positioned(
                              left: widget.boardWidth - 164,
                              top: widget.boardHeight - 92,
                              child: const _BoardZoneLabel(title: 'Paused'),
                            ),
                            ..._orderedBoardProjects.map((boardProject) {
                              final isHovered =
                                  _hoveredProjectId == boardProject.id;
                              final isPressed =
                                  _pressedProjectId == boardProject.id;
                              final isDragging =
                                  _draggingProjectId == boardProject.id;
                              final idleOffset = _idleOffsetFor(boardProject);
                              final displayPosition =
                                  boardProject.boardPosition + idleOffset;

                              return AnimatedPositioned(
                                key: ValueKey(boardProject.id),
                                duration: isDragging
                                    ? Duration.zero
                                    : const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                left: displayPosition.dx,
                                top: displayPosition.dy,
                                child: MouseRegion(
                                  cursor: widget.onProjectTap == null
                                      ? SystemMouseCursors.grab
                                      : SystemMouseCursors.click,
                                  onEnter: (_) {
                                    _soundPlayer.playProjectHover();
                                    setState(
                                      () => _hoveredProjectId = boardProject.id,
                                    );
                                  },
                                  onExit: (_) {
                                    if (_hoveredProjectId == boardProject.id) {
                                      setState(() => _hoveredProjectId = null);
                                    }
                                  },
                                  child: GestureDetector(
                                    onTapDown: (_) {
                                      _noteBoardInteraction();
                                      _bringProjectToFront(boardProject.id);
                                      setState(
                                        () =>
                                            _pressedProjectId = boardProject.id,
                                      );
                                    },
                                    onTapCancel: () =>
                                        _clearPressed(boardProject.id),
                                    onTapUp: (_) =>
                                        _clearPressed(boardProject.id),
                                    onTap: () {
                                      _noteBoardInteraction();
                                      _bringProjectToFront(boardProject.id);
                                      widget.onProjectTap?.call(
                                        boardProject.id,
                                      );
                                    },
                                    onPanStart: (details) {
                                      final scenePosition =
                                          _scenePositionForGlobal(
                                            details.globalPosition,
                                          );
                                      final currentPosition =
                                          _currentBoardPosition(boardProject);

                                      _noteBoardInteraction(
                                        scheduleCollapse: false,
                                      );
                                      _bringProjectToFront(boardProject.id);
                                      setState(() {
                                        _draggingProjectId = boardProject.id;
                                        _pressedProjectId = null;
                                        _dragGrabOffset = scenePosition == null
                                            ? Offset.zero
                                            : scenePosition - currentPosition;
                                      });
                                    },
                                    onPanUpdate: (details) {
                                      final scenePosition =
                                          _scenePositionForGlobal(
                                            details.globalPosition,
                                          );
                                      final grabOffset = _dragGrabOffset;
                                      if (scenePosition == null ||
                                          grabOffset == null) {
                                        return;
                                      }

                                      _noteBoardInteraction(
                                        scheduleCollapse: false,
                                      );
                                      final nextPosition =
                                          scenePosition - grabOffset;

                                      widget.onProjectDragged(
                                        boardProject.id,
                                        Offset(
                                          nextPosition.dx.clamp(0, _maxCardX),
                                          nextPosition.dy.clamp(0, _maxCardY),
                                        ),
                                      );
                                    },
                                    onPanEnd: (_) {
                                      widget.onProjectDragEnded?.call(
                                        boardProject.id,
                                      );
                                      _scheduleResetControlCollapse();
                                      setState(() {
                                        _draggingProjectId = null;
                                        _dragGrabOffset = null;
                                      });
                                    },
                                    onPanCancel: () {
                                      _scheduleResetControlCollapse();
                                      setState(() {
                                        _draggingProjectId = null;
                                        _dragGrabOffset = null;
                                      });
                                    },
                                    child: Material(
                                      color: Colors.transparent,
                                      child: ProjectBoardCard(
                                        boardProject: boardProject,
                                        isHovered: isHovered,
                                        isPressed: isPressed,
                                        isDragging: isDragging,
                                        width: widget.cardWidth,
                                        height: widget.cardHeight,
                                        briefMaxLines: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            Positioned(
                              left: _newProjectCardPosition.dx,
                              top: _newProjectCardPosition.dy,
                              child: _NewProjectBoardCard(
                                onTap: widget.onAddProjectTap,
                                onHoverEnter: _soundPlayer.playNewProjectHover,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: _ResetBoardViewControl(
                  expanded:
                      _isResetControlExpanded ||
                      _isPointerNearResetArea ||
                      _isResetControlHovered,
                  onPressed: _resetBoardView,
                  onHoverChanged: (isHovered) {
                    if (_isResetControlHovered == isHovered) {
                      return;
                    }

                    setState(() => _isResetControlHovered = isHovered);
                    if (isHovered) {
                      _revealResetControl(scheduleCollapse: false);
                    } else if (!_isPointerNearResetArea) {
                      _scheduleResetControlCollapse();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isPointerOverBoard = true),
        onHover: _handleBoardHover,
        onExit: (_) {
          setState(() {
            _isPointerOverBoard = false;
            _isPointerNearResetArea = false;
          });
          if (!_isResetControlHovered) {
            _scheduleResetControlCollapse();
          }
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (event) {
            if (!_isPointerOverBoard || event is! PointerScrollEvent) {
              return;
            }

            GestureBinding.instance.pointerSignalResolver.register(event, (
              resolvedEvent,
            ) {
              _handlePointerScroll(resolvedEvent as PointerScrollEvent);
            });
          },
          child: widget.viewportHeight == null
              ? SizedBox.expand(child: viewportChild)
              : SizedBox(
                  height:
                      widget.viewportHeight ??
                      ProjectBoard.defaultViewportHeight,
                  child: viewportChild,
                ),
        ),
      ),
    );
  }
}

class _ResetBoardViewControl extends StatelessWidget {
  const _ResetBoardViewControl({
    required this.expanded,
    required this.onPressed,
    required this.onHoverChanged,
  });

  final bool expanded;
  final VoidCallback onPressed;
  final ValueChanged<bool> onHoverChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final paiColors = context.paiColors;
    final isDark = theme.brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        opacity: expanded ? 1 : 0.82,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          scale: expanded ? 1 : 0.96,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: expanded ? 152 : 52,
            height: 48,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(999),
                child: GlassSurface(
                  padding: EdgeInsets.symmetric(
                    horizontal: expanded ? 12 : 8,
                    vertical: 8,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  blurSigma: 16,
                  tintColor: AppTheme.tintedSurface(
                    colorScheme.surface,
                    colorScheme.primary,
                    amount: isDark ? 0.16 : 0.04,
                  ),
                  tintOpacity: expanded ? 0.74 : 0.62,
                  borderOpacity: 0.52,
                  highlightOpacity: 0.3,
                  boxShadow: [
                    BoxShadow(
                      color: paiColors.panelShadow.withValues(
                        alpha: isDark ? 0.24 : 0.14,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  child: Row(
                    mainAxisAlignment: expanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.center_focus_strong_rounded,
                        size: 18,
                        color: colorScheme.onSurface,
                      ),
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.horizontal,
                                child: child,
                              ),
                            );
                          },
                          child: expanded
                              ? Padding(
                                  key: const ValueKey('reset-label'),
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    'Reset view',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('reset-empty'),
                                  width: 0,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardBackdrop extends StatelessWidget {
  const _BoardBackdrop({required this.boardWidth, required this.boardHeight});

  final double boardWidth;
  final double boardHeight;

  @override
  Widget build(BuildContext context) {
    final paiColors = context.paiColors;
    final zoneWidth = (boardWidth - 124) / 2;
    final zoneHeight = (boardHeight - 164) / 2;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _BoardGridPainter(color: paiColors.boardGrid),
          ),
        ),
        Positioned(
          left: -80,
          top: -120,
          child: _GlowOrb(
            size: 260,
            color: paiColors.boardGlowBlue.withValues(alpha: 0.45),
          ),
        ),
        Positioned(
          right: -40,
          top: boardHeight * 0.18,
          child: _GlowOrb(
            size: 220,
            color: paiColors.boardGlowGold.withValues(alpha: 0.4),
          ),
        ),
        Positioned(
          left: boardWidth * 0.35,
          bottom: -70,
          child: _GlowOrb(
            size: 240,
            color: paiColors.boardGlowGreen.withValues(alpha: 0.34),
          ),
        ),
        Positioned(
          left: 36,
          top: 68,
          child: _BoardZonePanel(
            width: zoneWidth,
            height: zoneHeight,
            color: paiColors.boardZoneNow,
          ),
        ),
        Positioned(
          left: boardWidth - zoneWidth - 36,
          top: 68,
          child: _BoardZonePanel(
            width: zoneWidth,
            height: zoneHeight,
            color: paiColors.boardZoneSoon,
          ),
        ),
        Positioned(
          left: 36,
          top: boardHeight - zoneHeight - 44,
          child: _BoardZonePanel(
            width: zoneWidth,
            height: zoneHeight,
            color: paiColors.boardZoneIdeas,
          ),
        ),
        Positioned(
          left: boardWidth - zoneWidth - 36,
          top: boardHeight - zoneHeight - 44,
          child: _BoardZonePanel(
            width: zoneWidth,
            height: zoneHeight,
            color: paiColors.boardZonePaused,
          ),
        ),
      ],
    );
  }
}

class _BoardZonePanel extends StatelessWidget {
  const _BoardZonePanel({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final paiColors = context.paiColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface.withValues(alpha: isDark ? 0.06 : 0.2),
            color.withValues(alpha: 0.56),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.8 : 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: paiColors.panelShadow.withValues(
              alpha: isDark ? 0.18 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _BoardGridPainter extends CustomPainter {
  _BoardGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.55);
    const spacing = 44.0;

    for (double x = 20; x < size.width; x += spacing) {
      for (double y = 20; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _NewProjectBoardCard extends StatelessWidget {
  const _NewProjectBoardCard({required this.onTap, this.onHoverEnter});

  final VoidCallback onTap;
  final VoidCallback? onHoverEnter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverEnter?.call(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: GlassSurface(
          padding: const EdgeInsets.all(14),
          borderRadius: BorderRadius.circular(22),
          blurSigma: 16,
          tintColor: AppTheme.tintedSurface(
            colorScheme.surface,
            colorScheme.primary,
            amount: Theme.of(context).brightness == Brightness.dark
                ? 0.16
                : 0.04,
          ),
          tintOpacity: 0.76,
          borderOpacity: 0.5,
          child: SizedBox(
            width: 196,
            height: 144,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, size: 30),
                const SizedBox(height: 8),
                Text(
                  'New Project',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Drop in a fresh idea.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardZoneLabel extends StatelessWidget {
  const _BoardZoneLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      borderRadius: BorderRadius.circular(999),
      blurSigma: 10,
      tintColor: AppTheme.tintedSurface(
        colorScheme.surface,
        colorScheme.primary,
        amount: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.03,
      ),
      tintOpacity: 0.68,
      borderOpacity: 0.5,
      boxShadow: const [],
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}




