import '../../models/board_project.dart';
import '../../models/project.dart';
import '../../repositories/project_repository.dart';
import 'in_memory_pai_store.dart';

class InMemoryProjectRepository implements ProjectRepository {
  InMemoryProjectRepository(this._store);

  final InMemoryPaiStore _store;

  @override
  Future<void> createProject({
    required Project project,
    required BoardProject boardProject,
  }) async {
    _store.addProject(project, boardProject);
  }

  @override
  Future<Project?> getProjectById(String projectId) async {
    return _store.projectById(projectId);
  }

  @override
  Future<List<BoardProject>> listBoardProjects() async {
    return _store.listBoardProjects();
  }

  @override
  Future<List<Project>> listProjects() async {
    return _store.listProjects();
  }

  @override
  Future<void> saveBoardProject(BoardProject boardProject) async {
    _store.saveBoardProject(boardProject);
  }

  @override
  Future<void> saveProject(Project project) async {
    _store.saveProject(project);
  }
}
