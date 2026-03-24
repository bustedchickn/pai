import 'package:shared_preferences/shared_preferences.dart';

class WorkspacePreferencesStorage {
  static const String _showWorkspaceStatsKey = 'show_workspace_stats_v1';

  Future<bool> loadShowWorkspaceStats() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_showWorkspaceStatsKey) ?? false;
  }

  Future<void> saveShowWorkspaceStats(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_showWorkspaceStatsKey, value);
  }
}
