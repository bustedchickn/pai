import 'package:flutter/material.dart';

import '../models/board_project.dart';
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
  });

  final BoardProject boardProject;
  final bool isHovered;
  final bool isPressed;
  final bool isDragging;
  final double? width;
  final double? height;
  final int briefMaxLines;

  @override
  Widget build(BuildContext context) {
    final isCompactCard = (width ?? 220) <= 220 || (height ?? 196) <= 196;
    final visibleTags = boardProject.tags.take(isCompactCard ? 1 : 2).toList();
    final remainingTagCount = boardProject.tags.length - visibleTags.length;
    final contentPadding = isCompactCard ? 12.0 : 14.0;
    final titleStyle = isCompactCard
        ? Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final briefLines = isCompactCard ? 1 : briefMaxLines;
    final tagIconSize = isCompactCard ? 12.0 : 16.0;
    final tagLabelStyle = isCompactCard
        ? Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1,
          )
        : null;
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
        ? const Color(0xFF9AA7D9)
        : isHovered
        ? const Color(0xFFC9D3F3)
        : const Color(0xFFD9DFEE);

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8090C2).withValues(alpha: shadowOpacity),
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
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    boardProject.brief,
                    maxLines: briefLines,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF53627F),
                      height: 1.3,
                    ),
                  ),
                ),
                SizedBox(height: isCompactCard ? 8 : 10),
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
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF5E6B8A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: boardProject.progress,
                    minHeight: isCompactCard ? 5 : 6,
                    backgroundColor: const Color(0xFFE7E9F4),
                  ),
                ),
                SizedBox(height: isCompactCard ? 8 : 10),
                Wrap(
                  spacing: isCompactCard ? 6 : 8,
                  runSpacing: isCompactCard ? 6 : 8,
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
                          horizontal: isCompactCard ? 6 : 8,
                        ),
                        labelStyle: tagLabelStyle,
                        label: Text(tag),
                        avatar: Icon(
                          Icons.sell_outlined,
                          size: tagIconSize,
                        ),
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
                          horizontal: isCompactCard ? 6 : 8,
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
