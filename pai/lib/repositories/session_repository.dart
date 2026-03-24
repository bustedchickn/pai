import '../models/session_note.dart';

abstract class SessionRepository {
  Future<List<SessionNote>> listSessions(String projectId);
  Future<void> addSession(String projectId, SessionNote session);
}
