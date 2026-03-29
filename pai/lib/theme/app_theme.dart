import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class PaiThemeColors extends ThemeExtension<PaiThemeColors> {
  const PaiThemeColors({
    required this.glassTint,
    required this.glassBorder,
    required this.glassShadow,
    required this.panelShadow,
    required this.boardCanvasStart,
    required this.boardCanvasMid,
    required this.boardCanvasEnd,
    required this.boardGrid,
    required this.boardZoneNow,
    required this.boardZoneSoon,
    required this.boardZoneIdeas,
    required this.boardZonePaused,
    required this.boardGlowBlue,
    required this.boardGlowGold,
    required this.boardGlowGreen,
    required this.warningForeground,
    required this.warningSurface,
    required this.warningBorder,
    required this.success,
  });

  final Color glassTint;
  final Color glassBorder;
  final Color glassShadow;
  final Color panelShadow;
  final Color boardCanvasStart;
  final Color boardCanvasMid;
  final Color boardCanvasEnd;
  final Color boardGrid;
  final Color boardZoneNow;
  final Color boardZoneSoon;
  final Color boardZoneIdeas;
  final Color boardZonePaused;
  final Color boardGlowBlue;
  final Color boardGlowGold;
  final Color boardGlowGreen;
  final Color warningForeground;
  final Color warningSurface;
  final Color warningBorder;
  final Color success;

  factory PaiThemeColors.light() {
    return const PaiThemeColors(
      glassTint: Color(0xFFF8FBFF),
      glassBorder: Color(0xFFFFFFFF),
      glassShadow: Color(0xFF6B7DAE),
      panelShadow: Color(0xFF7F94C8),
      boardCanvasStart: Color(0xFFF8FAFF),
      boardCanvasMid: Color(0xFFF0F5FF),
      boardCanvasEnd: Color(0xFFFDFBF6),
      boardGrid: Color(0xFFCFD7EB),
      boardZoneNow: Color(0xFFEAF2FF),
      boardZoneSoon: Color(0xFFFFF2D9),
      boardZoneIdeas: Color(0xFFE8F7F0),
      boardZonePaused: Color(0xFFF5EDF7),
      boardGlowBlue: Color(0xFFBFD7FF),
      boardGlowGold: Color(0xFFFFE5B8),
      boardGlowGreen: Color(0xFFCBEFDB),
      warningForeground: Color(0xFF9A6B18),
      warningSurface: Color(0xFFFFFBF2),
      warningBorder: Color(0xFFF0DEC0),
      success: Color(0xFF1E9E5A),
    );
  }

  factory PaiThemeColors.dark() {
    return const PaiThemeColors(
      glassTint: Color(0xFF182131),
      glassBorder: Color(0xFF2A3648),
      glassShadow: Color(0xFF04070D),
      panelShadow: Color(0xFF04070D),
      boardCanvasStart: Color(0xFF101722),
      boardCanvasMid: Color(0xFF131D2B),
      boardCanvasEnd: Color(0xFF181B25),
      boardGrid: Color(0xFF3D4A61),
      boardZoneNow: Color(0xFF1A2940),
      boardZoneSoon: Color(0xFF312518),
      boardZoneIdeas: Color(0xFF162B25),
      boardZonePaused: Color(0xFF271C2F),
      boardGlowBlue: Color(0xFF365C9E),
      boardGlowGold: Color(0xFF8A6631),
      boardGlowGreen: Color(0xFF2E7457),
      warningForeground: Color(0xFFF2C46E),
      warningSurface: Color(0xFF342914),
      warningBorder: Color(0xFF67512A),
      success: Color(0xFF6ED39A),
    );
  }

  @override
  PaiThemeColors copyWith({
    Color? glassTint,
    Color? glassBorder,
    Color? glassShadow,
    Color? panelShadow,
    Color? boardCanvasStart,
    Color? boardCanvasMid,
    Color? boardCanvasEnd,
    Color? boardGrid,
    Color? boardZoneNow,
    Color? boardZoneSoon,
    Color? boardZoneIdeas,
    Color? boardZonePaused,
    Color? boardGlowBlue,
    Color? boardGlowGold,
    Color? boardGlowGreen,
    Color? warningForeground,
    Color? warningSurface,
    Color? warningBorder,
    Color? success,
  }) {
    return PaiThemeColors(
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
      panelShadow: panelShadow ?? this.panelShadow,
      boardCanvasStart: boardCanvasStart ?? this.boardCanvasStart,
      boardCanvasMid: boardCanvasMid ?? this.boardCanvasMid,
      boardCanvasEnd: boardCanvasEnd ?? this.boardCanvasEnd,
      boardGrid: boardGrid ?? this.boardGrid,
      boardZoneNow: boardZoneNow ?? this.boardZoneNow,
      boardZoneSoon: boardZoneSoon ?? this.boardZoneSoon,
      boardZoneIdeas: boardZoneIdeas ?? this.boardZoneIdeas,
      boardZonePaused: boardZonePaused ?? this.boardZonePaused,
      boardGlowBlue: boardGlowBlue ?? this.boardGlowBlue,
      boardGlowGold: boardGlowGold ?? this.boardGlowGold,
      boardGlowGreen: boardGlowGreen ?? this.boardGlowGreen,
      warningForeground: warningForeground ?? this.warningForeground,
      warningSurface: warningSurface ?? this.warningSurface,
      warningBorder: warningBorder ?? this.warningBorder,
      success: success ?? this.success,
    );
  }

  @override
  PaiThemeColors lerp(ThemeExtension<PaiThemeColors>? other, double t) {
    if (other is! PaiThemeColors) {
      return this;
    }

    return PaiThemeColors(
      glassTint: Color.lerp(glassTint, other.glassTint, t) ?? glassTint,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t) ?? glassShadow,
      panelShadow: Color.lerp(panelShadow, other.panelShadow, t) ?? panelShadow,
      boardCanvasStart:
          Color.lerp(boardCanvasStart, other.boardCanvasStart, t) ??
          boardCanvasStart,
      boardCanvasMid:
          Color.lerp(boardCanvasMid, other.boardCanvasMid, t) ?? boardCanvasMid,
      boardCanvasEnd:
          Color.lerp(boardCanvasEnd, other.boardCanvasEnd, t) ?? boardCanvasEnd,
      boardGrid: Color.lerp(boardGrid, other.boardGrid, t) ?? boardGrid,
      boardZoneNow:
          Color.lerp(boardZoneNow, other.boardZoneNow, t) ?? boardZoneNow,
      boardZoneSoon:
          Color.lerp(boardZoneSoon, other.boardZoneSoon, t) ?? boardZoneSoon,
      boardZoneIdeas:
          Color.lerp(boardZoneIdeas, other.boardZoneIdeas, t) ?? boardZoneIdeas,
      boardZonePaused:
          Color.lerp(boardZonePaused, other.boardZonePaused, t) ??
          boardZonePaused,
      boardGlowBlue:
          Color.lerp(boardGlowBlue, other.boardGlowBlue, t) ?? boardGlowBlue,
      boardGlowGold:
          Color.lerp(boardGlowGold, other.boardGlowGold, t) ?? boardGlowGold,
      boardGlowGreen:
          Color.lerp(boardGlowGreen, other.boardGlowGreen, t) ?? boardGlowGreen,
      warningForeground:
          Color.lerp(warningForeground, other.warningForeground, t) ??
          warningForeground,
      warningSurface:
          Color.lerp(warningSurface, other.warningSurface, t) ?? warningSurface,
      warningBorder:
          Color.lerp(warningBorder, other.warningBorder, t) ?? warningBorder,
      success: Color.lerp(success, other.success, t) ?? success,
    );
  }
}

class AppTheme {
  static const Color _seedColor = Color(0xFF4F7AE8);

  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    paiColors: PaiThemeColors.light(),
  );

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    paiColors: PaiThemeColors.dark(),
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required PaiThemeColors paiColors,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final colorScheme = baseScheme.copyWith(
      primary: isDark ? const Color(0xFFA9BFFF) : const Color(0xFF3557A5),
      onPrimary: Colors.white,
      secondary: isDark ? const Color(0xFFC4D1FF) : const Color(0xFF4867B7),
      onSecondary: Colors.white,
      tertiary: isDark ? const Color(0xFF8CDEAE) : paiColors.success,
      surface: isDark ? const Color(0xFF171E29) : const Color(0xFFFFFFFF),
      onSurface: isDark ? const Color(0xFFE8EEF9) : const Color(0xFF223047),
      outline: isDark ? const Color(0xFF59667D) : const Color(0xFFB8C3D7),
      outlineVariant: isDark
          ? const Color(0xFF313D50)
          : const Color(0xFFD9E1F0),
      shadow: isDark ? const Color(0xFF04070D) : const Color(0xFF6B7DAE),
      surfaceTint: isDark ? const Color(0xFF7A9EFF) : _seedColor,
    );

    final scaffoldBackground = isDark
        ? const Color(0xFF0E141D)
        : const Color(0xFFF7F8FC);
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: scaffoldBackground,
      extensions: [paiColors],
    );

    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark
            ? const Color(0xFF121925)
            : const Color(0xFFFCFDFF),
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: colorScheme.outlineVariant,
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF121925) : Colors.white,
        hintStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.62),
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.72),
        ),
        border: _outlineBorder(colorScheme.outlineVariant),
        enabledBorder: _outlineBorder(colorScheme.outlineVariant),
        focusedBorder: _outlineBorder(colorScheme.primary, width: 1.4),
        errorBorder: _outlineBorder(colorScheme.error),
        focusedErrorBorder: _outlineBorder(colorScheme.error, width: 1.4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF111822)
            : const Color(0xFFFFFFFF),
        indicatorColor: colorScheme.primary.withValues(
          alpha: isDark ? 0.22 : 0.12,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark
            ? const Color(0xFF111822)
            : const Color(0xFFFFFFFF),
        indicatorColor: colorScheme.primary.withValues(
          alpha: isDark ? 0.22 : 0.12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.18),
          disabledForegroundColor: colorScheme.onSurface.withValues(
            alpha: 0.44,
          ),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static Color tintedSurface(
    Color surface,
    Color tint, {
    double amount = 0.08,
  }) {
    return Color.alphaBlend(tint.withValues(alpha: amount), surface);
  }

  static OutlinedBorder roundedBorder(double radius) {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  }

  static OutlineInputBorder _outlineBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

extension PaiThemeContext on BuildContext {
  PaiThemeColors get paiColors {
    final theme = Theme.of(this).extension<PaiThemeColors>();
    final brightness = Theme.of(this).brightness;
    return theme ??
        (brightness == Brightness.dark
            ? PaiThemeColors.dark()
            : PaiThemeColors.light());
  }
}

Color lerpColor(Color a, Color b, double t) =>
    Color.lerp(a, b, t) ?? (t < 0.5 ? a : b);

double lerpDoubleValue(double a, double b, double t) =>
    lerpDouble(a, b, t) ?? (t < 0.5 ? a : b);


