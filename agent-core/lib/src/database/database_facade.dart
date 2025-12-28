import 'database.dart';
import 'daos/project_dao.dart';
import 'daos/session_dao.dart';
import 'daos/message_dao.dart';
import 'daos/snippet_dao.dart';
import 'daos/project_snippet_dao.dart';
import 'daos/saved_prompt_dao.dart';
import 'daos/project_saved_prompt_dao.dart';
import 'daos/session_mutex_dao.dart';
import 'entities/snippet_entity.dart';
import 'entities/saved_prompt_entity.dart';

/// Facade to unify access to GlobalDatabase and ProjectDatabase.
/// Maintains API compatibility with the old AppDatabase where possible.
class DatabaseFacade {
  final GlobalDatabase globalDatabase;
  final ProjectDatabase? projectDatabase;
  final String? projectId;

  DatabaseFacade(this.globalDatabase, this.projectDatabase, this.projectId);

  ProjectDao get projectDao => globalDatabase.projectDao;

  SessionDao get sessionDao {
    if (projectDatabase == null) {
      throw Exception('No project selected or project database not loaded');
    }
    return projectDatabase!.sessionDao;
  }

  MessageDao get messageDao {
    if (projectDatabase == null) {
      throw Exception('No project selected or project database not loaded');
    }
    return projectDatabase!.messageDao;
  }

  SessionMutexDao get sessionMutexDao {
    if (projectDatabase == null) {
      throw Exception('No project selected or project database not loaded');
    }
    return projectDatabase!.sessionMutexDao;
  }

  late final SnippetDaoFacade snippetDao = SnippetDaoFacade(
    globalDatabase.snippetDao,
    projectDatabase?.projectSnippetDao,
  );

  late final SavedPromptDaoFacade savedPromptDao = SavedPromptDaoFacade(
    globalDatabase.savedPromptDao,
    projectDatabase?.projectSavedPromptDao,
  );

  Future<void> close() async {
    // We don't close databases here as they are managed by providers
  }
}

/// Facade for SnippetDao to handle routing between Global and Project databases.
class SnippetDaoFacade {
  final SnippetDao globalDao;
  final ProjectSnippetDao? projectDao;

  SnippetDaoFacade(this.globalDao, this.projectDao);

  Stream<List<SnippetEntity>> watchGlobalSnippets() =>
      globalDao.watchGlobalSnippets();

  Stream<List<SnippetEntity>> watchProjectSnippets(String projectId) {
    if (projectDao != null) {
      return projectDao!.watchProjectSnippets(projectId);
    }
    return Stream.value([]);
  }

  Future<List<SnippetEntity>> getGlobalSnippets() =>
      globalDao.getGlobalSnippets();

  Future<List<SnippetEntity>> getProjectSnippets(String projectId) {
    if (projectDao != null) {
      return projectDao!.getProjectSnippets(projectId);
    }
    return Future.value([]);
  }

  Future<SnippetEntity?> getSnippet(String id) async {
    final global = await globalDao.getSnippet(id);
    if (global != null) return global;

    if (projectDao != null) {
      return await projectDao!.getSnippet(id);
    }
    return null;
  }

  Stream<SnippetEntity?> watchSnippet(String id) {
    // Simple implementation: prefer global, then project.
    // Note: This doesn't merge streams perfectly but works for most cases where ID is unique.
    return globalDao.watchSnippet(id).asyncMap((global) async {
      if (global != null) return global;
      if (projectDao != null) {
        return await projectDao!.getSnippet(id);
      }
      return null;
    });
  }

  Future<List<SnippetEntity>> searchSnippets(
    String query, {
    String? projectId,
  }) async {
    if (projectId != null) {
      if (projectDao != null) {
        return projectDao!.searchSnippets(query, projectId);
      }
      return [];
    } else {
      return globalDao.searchSnippets(query);
    }
  }

  Future<int> insertSnippet(SnippetEntityCompanion snippet) {
    if (snippet.projectId.present && snippet.projectId.value != null) {
      if (projectDao == null) throw Exception('No project selected');
      return projectDao!.insertSnippet(snippet);
    } else {
      return globalDao.insertSnippet(snippet);
    }
  }

  Future<bool> updateSnippet(SnippetEntityCompanion snippet) async {
    // If projectId is explicitly set
    if (snippet.projectId.present) {
      if (snippet.projectId.value != null) {
        if (projectDao == null) throw Exception('No project selected');
        return projectDao!.updateSnippet(snippet);
      } else {
        return (await globalDao.updateSnippet(snippet)) > 0;
      }
    }

    // If projectId is not set, try global first
    int updated = await globalDao.updateSnippet(snippet);
    if (updated > 0) return true;

    if (projectDao != null) {
      return await projectDao!.updateSnippet(snippet);
    }
    return false;
  }

  Future<int> deleteSnippet(String id) async {
    int count = await globalDao.deleteSnippet(id);
    if (count > 0) return count;

    if (projectDao != null) {
      return await projectDao!.deleteSnippet(id);
    }
    return 0;
  }

  Future<int> getMaxPosition({String? projectId}) async {
    if (projectId != null) {
      if (projectDao != null) {
        return projectDao!.getMaxPosition(projectId);
      }
      return -1;
    } else {
      return globalDao.getMaxPosition();
    }
  }
}

/// Facade for SavedPromptDao to handle routing between Global and Project databases.
class SavedPromptDaoFacade {
  final SavedPromptDao globalDao;
  final ProjectSavedPromptDao? projectDao;

  SavedPromptDaoFacade(this.globalDao, this.projectDao);

  Stream<List<SavedPromptEntity>> watchGlobalSavedPrompts() =>
      globalDao.watchGlobalSavedPrompts();

  Stream<List<SavedPromptEntity>> watchProjectSavedPrompts(String projectId) {
    if (projectDao != null) {
      return projectDao!.watchProjectSavedPrompts(projectId);
    }
    return Stream.value([]);
  }

  Future<List<SavedPromptEntity>> getGlobalSavedPrompts() =>
      globalDao.getGlobalSavedPrompts();

  Future<List<SavedPromptEntity>> getProjectSavedPrompts(String projectId) {
    if (projectDao != null) {
      return projectDao!.getProjectSavedPrompts(projectId);
    }
    return Future.value([]);
  }

  Future<SavedPromptEntity?> getSavedPrompt(String id) async {
    final global = await globalDao.getSavedPrompt(id);
    if (global != null) return global;

    if (projectDao != null) {
      return await projectDao!.getSavedPrompt(id);
    }
    return null;
  }

  Stream<SavedPromptEntity?> watchSavedPrompt(String id) {
    return globalDao.watchSavedPrompt(id).asyncMap((global) async {
      if (global != null) return global;
      if (projectDao != null) {
        return await projectDao!.getSavedPrompt(id);
      }
      return null;
    });
  }

  Future<List<SavedPromptEntity>> searchSavedPrompts(
    String query, {
    String? projectId,
  }) async {
    if (projectId != null) {
      if (projectDao != null) {
        return projectDao!.searchSavedPrompts(query, projectId: projectId);
      }
      return [];
    } else {
      return globalDao.searchSavedPrompts(query);
    }
  }

  Future<int> insertSavedPrompt(SavedPromptEntityCompanion savedPrompt) {
    if (savedPrompt.projectId.present && savedPrompt.projectId.value != null) {
      if (projectDao == null) throw Exception('No project selected');
      return projectDao!.insertSavedPrompt(savedPrompt);
    } else {
      return globalDao.insertSavedPrompt(savedPrompt);
    }
  }

  Future<bool> updateSavedPrompt(SavedPromptEntityCompanion savedPrompt) async {
    // If projectId is explicitly set
    if (savedPrompt.projectId.present) {
      if (savedPrompt.projectId.value != null) {
        if (projectDao == null) throw Exception('No project selected');
        return (await projectDao!.updateSavedPrompt(savedPrompt)) > 0;
      } else {
        return (await globalDao.updateSavedPrompt(savedPrompt)) > 0;
      }
    }

    // If projectId is not set, try global first
    int updated = await globalDao.updateSavedPrompt(savedPrompt);
    if (updated > 0) return true;

    if (projectDao != null) {
      return (await projectDao!.updateSavedPrompt(savedPrompt)) > 0;
    }
    return false;
  }

  Future<int> deleteSavedPrompt(String id) async {
    int count = await globalDao.deleteSavedPrompt(id);
    if (count > 0) return count;

    if (projectDao != null) {
      return await projectDao!.deleteSavedPrompt(id);
    }
    return 0;
  }
}
