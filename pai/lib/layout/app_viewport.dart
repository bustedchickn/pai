enum AppViewportMode { mobile, compactDesktop, fullDesktop }

class AppViewport {
  const AppViewport._();

  static const double mobileMaxWidth = 900;
  static const double compactDesktopMaxWidth = 1280;

  static AppViewportMode fromWidth(double width) {
    if (width < mobileMaxWidth) {
      return AppViewportMode.mobile;
    }
    if (width < compactDesktopMaxWidth) {
      return AppViewportMode.compactDesktop;
    }
    return AppViewportMode.fullDesktop;
  }

  static bool isMobileWidth(double width) =>
      fromWidth(width) == AppViewportMode.mobile;

  static bool isCompactDesktopWidth(double width) =>
      fromWidth(width) == AppViewportMode.compactDesktop;

  static bool isFullDesktopWidth(double width) =>
      fromWidth(width) == AppViewportMode.fullDesktop;
}
