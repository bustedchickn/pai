import 'package:flutter/material.dart';

import '../models/board_project.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

class ProjectBoardCard extends StatelessWidget {
  const ProjectBoardCard({
    super.key,
    required this.boardProject,
    this.isHovered = false,
    this.isPressed = false,
    this.isDragging = false,
    this.width = 220,
    this.height = 196,
    this.briefMaxLines = 2,
    this.dense = false,
  });

  final BoardProject boardProject;
  final bool isHovered;
  final bool isPressed;
  final bool isDragging;
  final double? width;
  final double? height;
  final int briefMaxLines;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final paiColors = context.paiColors;
    final isDark = theme.brightness == Brightness.dark;
    final isCompactCard = (width ?? 220) <= 220 || (height ?? 196) <= 196;
    final useDenseSpacing = dense || isCompactCard;
    final visibleTags = boardProject.tags
        .take(useDenseSpacing ? 1 : 2)
        .toList();
    final remainingTagCount = boardProject.tags.length - visibleTags.length;
    final contentPadding = dense
        ? 10.0
        : isCompactCard
        ? 12.0
        : 14.0;
    final titleStyle = useDenseSpacing
        ? Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final briefLines = dense
        ? 1
        : isCompactCard
        ? 1
        : briefMaxLines;
    final tagIconSize = useDenseSpacing ? 12.0 : 16.0;
    final tagLabelStyle = useDenseSpacing
        ? Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1,
          )
        : null;
    final bodyGap = dense
        ? 6.0
        : isCompactCard
        ? 8.0
        : 10.0;
    final progressGap = dense ? 4.0 : 6.0;
    final scale = isPressed
        ? 0.992
        : isDragging
        ? 1.015
        : isHovered
        ? 1.01
        : 1.0;

    final lift = isPressed
        ? 0.0
        : isDragging
        ? -8.0
        : isHovered
        ? -4.0
        : 0.0;

    final borderColor = isDragging
        ? colorScheme.primary.withValues(alpha: isDark ? 0.7 : 0.5)
        : isHovered
        ? colorScheme.primary.withValues(alpha: isDark ? 0.46 : 0.24)
        : colorScheme.outlineVariant;

    final shadowOpacity = isDragging
        ? 0.22
        : isHovered
        ? 0.16
        : 0.10;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: Offset(0, lift / 280),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: paiColors.panelShadow.withValues(
                  alpha: isDark ? shadowOpacity * 1.4 : shadowOpacity,
                ),
                blurRadius: isDragging ? 26 : 18,
                offset: Offset(0, isDragging ? 16 : 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(contentPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        boardProject.title,
                        style: titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(status: boardProject.status),
                  ],
                ),
                SizedBox(height: dense ? 4 : 6),
                Flexible(
                  child: Text(
                    boardProject.brief,
                    maxLines: briefLines,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
                SizedBox(height: bodyGap),
                Row(
                  children: [
                    Text(
                      'Progress',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(boardProject.progress * 100).round()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: progressGap),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: boardProject.progress,
                    minHeight: useDenseSpacing ? 5 : 6,
                    backgroundColor: AppTheme.tintedSurface(
                      colorScheme.surface,
                      colorScheme.primary,
                      amount: isDark ? 0.16 : 0.08,
                    ),
                  ),
                ),
                SizedBox(height: bodyGap),
                Wrap(
                  spacing: useDenseSpacing ? 6 : 8,
                  runSpacing: useDenseSpacing ? 6 : 8,
                  children: [
                    for (final tag in visibleTags)
                      Chip(
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        labelPadding: EdgeInsets.symmetric(
                          horizontal: useDenseSpacing ? 6 : 8,
                        ),
                        labelStyle: tagLabelStyle,
                        label: Text(tag),
                        avatar: Icon(Icons.sell_outlined, size: tagIconSize),
                      ),
                    if (remainingTagCount > 0)
                      Chip(
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        labelPadding: EdgeInsets.symmetric(
                          horizontal: useDenseSpacing ? 6 : 8,
                        ),
                        labelStyle: tagLabelStyle,
                        label: Text('+$remainingTagCount'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
