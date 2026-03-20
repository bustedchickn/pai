import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/board_project.dart';

class BoardPositionStorage {
  static const String _storageKey = 'dashboard_board_positions_v1';

  Future<Map<String, Offset>> loadPositions() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_storageKey);

    if (rawValue == null || rawValue.isEmpty) {
      return const {};
    }

    final decoded = jsonDecode(rawValue);
    if (decoded is! Map<String, dynamic>) {
      return const {};
    }

    final positions = <String, Offset>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) {
        continue;
      }

      final dx = value['dx'];
      final dy = value['dy'];
      if (dx is num && dy is num) {
        positions[entry.key] = Offset(dx.toDouble(), dy.toDouble());
      }
    }

    return positions;
  }

  Future<void> savePositions(List<BoardProject> boardProjects) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = {
      for (final project in boardProjects)
        project.id: {
          'dx': project.boardPosition.dx,
          'dy': project.boardPosition.dy,
        },
    };

    await preferences.setString(_storageKey, jsonEncode(payload));
  }
}
