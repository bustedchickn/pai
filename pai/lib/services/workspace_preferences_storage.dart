import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_appearance_mode.dart';

class WorkspacePreferencesStorage {
  static const String _showWorkspaceStatsKey = 'show_workspace_stats_v1';
  static const String _appearanceModeKey = 'app_appearance_mode_v1';

  Future<bool> loadShowWorkspaceStats() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_showWorkspaceStatsKey) ?? false;
  }

  Future<void> saveShowWorkspaceStats(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_showWorkspaceStatsKey, value);
  }

  Future<AppAppearanceMode> loadAppearanceMode() async {
    final preferences = await SharedPreferences.getInstance();
    return AppAppearanceMode.fromStorage(
      preferences.getString(_appearanceModeKey),
    );
  }

  Future<void> saveAppearanceMode(AppAppearanceMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_appearanceModeKey, mode.storageValue);
  }
}
