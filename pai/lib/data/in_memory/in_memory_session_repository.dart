import '../../models/session_note.dart';
import '../../repositories/session_repository.dart';
import 'in_memory_pai_store.dart';

class InMemorySessionRepository implements SessionRepository {
  InMemorySessionRepository(this._store);

  final InMemoryPaiStore _store;

  @override
  Future<void> addSession(String projectId, SessionNote session) async {
    final project = _store.projectById(projectId);
    if (project == null) {
      throw StateError('Missing project for id $projectId');
    }

    _store.saveProject(
      project.copyWith(
        sessions: [session, ...project.sessions],
        updatedAt: DateTime.now(),
        isDirty: true,
      ),
    );
  }

  @override
  Future<List<SessionNote>> listSessions(String projectId) async {
    final project = _store.projectById(projectId);
    if (project == null) {
      throw StateError('Missing project for id $projectId');
    }

    return List<SessionNote>.from(project.sessions);
  }
}
