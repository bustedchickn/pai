import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/in_memory/in_memory_pai_store.dart';
import '../models/board_project.dart';
import '../models/document_bookmark.dart';
import '../models/project.dart';
import '../models/project_document.dart';
import '../models/sync_conflict_backup.dart';

class LocalSnapshotStorage {
  static const String _keyPrefix = 'pai.local_snapshot.';

  Future<bool> loadIntoStore({
    required String scopeKey,
    required InMemoryPaiStore store,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final rawSnapshot = preferences.getString('$_keyPrefix$scopeKey');
    if (rawSnapshot == null || rawSnapshot.isEmpty) {
      return false;
    }

    final decoded = jsonDecode(rawSnapshot);
    if (decoded is! Map) {
      return false;
    }

    final snapshot = Map<String, dynamic>.from(decoded);
    store.replaceAll(
      projects: [
        for (final item in (snapshot['projects'] as List<dynamic>? ?? const []))
          if (item is Map<String, dynamic>) Project.fromJson(item),
      ],
      boardProjects: [
        for (final item
            in (snapshot['boardProjects'] as List<dynamic>? ?? const []))
          if (item is Map<String, dynamic>) BoardProject.fromJson(item),
      ],
      documents: [
        for (final item
            in (snapshot['documents'] as List<dynamic>? ?? const []))
          if (item is Map<String, dynamic>) ProjectDocument.fromJson(item),
      ],
      bookmarks: [
        for (final item
            in (snapshot['bookmarks'] as List<dynamic>? ?? const []))
          if (item is Map<String, dynamic>) DocumentBookmark.fromJson(item),
      ],
      conflictBackups: [
        for (final item
            in (snapshot['conflictBackups'] as List<dynamic>? ?? const []))
          if (item is Map<String, dynamic>) SyncConflictBackup.fromJson(item),
      ],
      lastManualSyncAt: DateTime.tryParse(
        snapshot['lastManualSyncAt'] as String? ?? '',
      ),
    );
    return true;
  }

  Future<void> save({
    required String scopeKey,
    required InMemoryPaiStore store,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      'version': 1,
      'projects': [
        for (final project in store.listAllProjects()) project.toJson(),
      ],
      'boardProjects': [
        for (final boardProject in store.listAllBoardProjects())
          boardProject.toJson(),
      ],
      'documents': [
        for (final document in store.listAllDocuments()) document.toJson(),
      ],
      'bookmarks': [
        for (final bookmark in store.listAllBookmarks()) bookmark.toJson(),
      ],
      'conflictBackups': [
        for (final backup in store.listConflictBackups()) backup.toJson(),
      ],
      'lastManualSyncAt': store.lastManualSyncAt?.toIso8601String(),
    });
    await preferences.setString('$_keyPrefix$scopeKey', encoded);
  }
}
