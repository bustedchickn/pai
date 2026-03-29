import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  Color _colorFor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final paiColors = context.paiColors;

    switch (status) {
      case 'active':
        return colorScheme.tertiary;
      case 'paused':
        return paiColors.warningForeground;
      case 'blocked':
        return colorScheme.error;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context);
    final surface = Theme.of(context).colorScheme.surface;

    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      label: Text(status),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: AppTheme.tintedSurface(
        surface,
        color,
        amount: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.1,
      ),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
