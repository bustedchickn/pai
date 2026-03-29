import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurSigma = 18,
    this.tintColor,
    this.tintOpacity = 0.66,
    this.borderColor,
    this.borderOpacity = 0.5,
    this.gradient,
    this.boxShadow,
    this.highlightOpacity = 0.2,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final double tintOpacity;
  final Color? borderColor;
  final double borderOpacity;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final double highlightOpacity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final paiColors = context.paiColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedTintColor = tintColor ?? paiColors.glassTint;
    final resolvedBorderColor = borderColor ?? paiColors.glassBorder;
    final resolvedShadow =
        boxShadow ??
        [
          BoxShadow(
            color: paiColors.glassShadow.withValues(
              alpha: isDark ? 0.28 : 0.12,
            ),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: resolvedShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: resolvedBorderColor.withValues(alpha: borderOpacity),
              ),
              color: resolvedTintColor.withValues(alpha: tintOpacity),
              gradient:
                  gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.onSurface.withValues(
                        alpha: isDark ? 0.08 : 0.05,
                      ),
                      resolvedTintColor.withValues(alpha: tintOpacity),
                    ],
                  ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.onSurface.withValues(
                              alpha: highlightOpacity * (isDark ? 0.36 : 1),
                            ),
                            colorScheme.onSurface.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
