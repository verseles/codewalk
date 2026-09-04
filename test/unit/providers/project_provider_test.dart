import 'dart:async';
import 'dart:convert';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/logging/app_logger.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/domain/entities/worktree.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

class _DelayedWorktreeProjectRepository extends FakeProjectRepository {
  _DelayedWorktreeProjectRepository({
    required super.currentProject,
    required super.projects,
    required super.worktrees,
  });

  Completer<void>? pendingWorktreeGate;

  @override
  Future<Either<Failure, List<Worktree>>> getWorktrees({
    String? directory,
  }) async {
    final gate = pendingWorktreeGate;
    if (gate != null) {
      await gate.future;
    }
    return super.getWorktrees(directory: directory);
  }
}

class _DirectoryProjectRepository extends FakeProjectRepository {
  _DirectoryProjectRepository({
    required super.currentProject,
    required super.projects,
    required this.projectsByDirectory,
  });

  final Map<String, Project> projectsByDirectory;

  @override
  Future<Either<Failure, Project>> getCurrentProject({
    String? directory,
  }) async {
    final normalized = directory?.trim();
    if (normalized != null && projectsByDirectory.containsKey(normalized)) {
      return Right(projectsByDirectory[normalized]!);
    }
    return super.getCurrentProject(directory: directory);
  }
}

class _MutableCurrentProjectRepository extends FakeProjectRepository {
  _MutableCurrentProjectRepository({
    required Project currentProject,
    required List<Project> projects,
  }) : currentProject = currentProject,
       super(currentProject: currentProject, projects: projects);

  Project currentProject;

  @override
  Future<Either<Failure, Project>> getCurrentProject({
    String? directory,
  }) async {
    if (directory == null || directory.trim().isEmpty) {
      return Right(currentProject);
    }
    return super.getCurrentProject(directory: directory);
  }
}

class _QueuedProjectListRepository extends FakeProjectRepository {
  _QueuedProjectListRepository({
    required super.currentProject,
    required super.projects,
  });

  final List<Completer<Either<Failure, List<Project>>>> queuedProjectResults =
      <Completer<Either<Failure, List<Project>>>>[];

  @override
  Future<Either<Failure, List<Project>>> getProjects() async {
    if (queuedProjectResults.isNotEmpty) {
      return queuedProjectResults.removeAt(0).future;
    }
    return super.getProjects();
  }
}

class _GatedProjectPersistenceDataSource extends InMemoryAppLocalDataSource {
  Completer<void>? saveOpenProjectsStarted;
  Completer<void>? saveOpenProjectsGate;

  @override
  Future<void> saveOpenProjectIdsJson(
    String projectIdsJson, {
    String? serverId,
  }) async {
    final started = saveOpenProjectsStarted;
    if (started != null && !started.isCompleted) {
      started.complete();
    }
    await saveOpenProjectsGate?.future;
    await super.saveOpenProjectIdsJson(projectIdsJson, serverId: serverId);
  }
}

class _FailingProjectPersistenceDataSource extends InMemoryAppLocalDataSource {
  bool failArchivedProjectsSave = false;

  @override
  Future<void> saveArchivedProjectIdsJson(
    String projectIdsJson, {
    String? serverId,
  }) async {
    if (failArchivedProjectsSave) {
      throw StateError('project persistence failed');
    }
    await super.saveArchivedProjectIdsJson(projectIdsJson, serverId: serverId);
  }
}

void main() {
  group('ProjectProvider', () {
    late InMemoryAppLocalDataSource localDataSource;
    late FakeProjectRepository projectRepository;
    late ProjectProvider provider;

    setUp(() {
      AppLogger.clearEntries();
      AppLogger.setLoggingEnabled(true);
      localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test';
      projectRepository = FakeProjectRepository(
        currentProject: Project(
          id: 'proj_a',
          name: 'Project A',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        projects: <Project>[
          Project(
            id: 'proj_a',
            name: 'Project A',
            path: '/repo/a',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
          Project(
            id: 'proj_b',
            name: 'Project B',
            path: '/repo/b',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
        worktrees: const <Worktree>[
          Worktree(
            id: 'wt_1',
            name: 'Workspace A',
            directory: '/repo/a/workspace-a',
            projectId: 'proj_a',
          ),
        ],
      );
      provider = ProjectProvider(
        projectRepository: projectRepository,
        localDataSource: localDataSource,
      );
    });

    tearDown(() {
      AppLogger.clearEntries();
      AppLogger.setLoggingEnabled(false);
    });

    test('initializeProject restores scoped current project id', () async {
      await localDataSource.saveCurrentProjectId(
        'proj_b',
        serverId: 'srv_test',
      );
      await localDataSource.saveOpenProjectIdsJson(
        jsonEncode(<String>['proj_b']),
        serverId: 'srv_test',
      );

      await provider.initializeProject();

      expect(provider.status, ProjectStatus.loaded);
      expect(provider.currentProject?.id, 'proj_b');
      expect(provider.openProjectIds, contains('proj_b'));
      expect(provider.contextKey, 'srv_test::/repo/b');
    });

    test(
      'switchProject persists scoped selection and keeps context open',
      () async {
        await provider.initializeProject();

        final changed = await provider.switchProject('proj_b');
        await provider.debugWaitForProjectStatePersistence();

        expect(changed, isTrue);
        expect(provider.currentProject?.id, 'proj_b');
        expect(
          provider.openProjectIds,
          containsAll(<String>['proj_a', 'proj_b']),
        );
        expect(
          localDataSource.scopedStrings['current_project_id::srv_test'],
          'proj_b',
        );
      },
    );

    test(
      'project switches publish before serialized persistence completes',
      () async {
        final gatedLocal = _GatedProjectPersistenceDataSource()
          ..activeServerId = 'srv_test';
        provider = ProjectProvider(
          projectRepository: projectRepository,
          localDataSource: gatedLocal,
        );
        await provider.initializeProject();

        final started = Completer<void>();
        final gate = Completer<void>();
        gatedLocal
          ..saveOpenProjectsStarted = started
          ..saveOpenProjectsGate = gate;
        var notifications = 0;
        provider.addListener(() => notifications += 1);

        final switchedToB = await provider
            .switchProject('proj_b')
            .timeout(const Duration(milliseconds: 80));
        await started.future;

        expect(switchedToB, isTrue);
        expect(provider.currentProject?.id, 'proj_b');
        expect(notifications, greaterThan(0));

        final switchedBackToA = await provider
            .switchProject('proj_a')
            .timeout(const Duration(milliseconds: 80));
        expect(switchedBackToA, isTrue);
        expect(provider.currentProject?.id, 'proj_a');

        gate.complete();
        await provider.debugWaitForProjectStatePersistence();

        expect(
          gatedLocal.scopedStrings['current_project_id::srv_test'],
          'proj_a',
        );
        expect(
          jsonDecode(gatedLocal.scopedStrings['open_project_ids::srv_test']!),
          containsAll(<String>['proj_a', 'proj_b']),
        );
      },
    );

    test('switchProject does not block while worktrees refresh', () async {
      final delayedRepository = _DelayedWorktreeProjectRepository(
        currentProject: Project(
          id: 'proj_a',
          name: 'Project A',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        projects: <Project>[
          Project(
            id: 'proj_a',
            name: 'Project A',
            path: '/repo/a',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
          Project(
            id: 'proj_b',
            name: 'Project B',
            path: '/repo/b',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
        worktrees: const <Worktree>[
          Worktree(
            id: 'wt_1',
            name: 'Workspace A',
            directory: '/repo/a/workspace-a',
            projectId: 'proj_a',
          ),
        ],
      );
      provider = ProjectProvider(
        projectRepository: delayedRepository,
        localDataSource: localDataSource,
      );

      await provider.initializeProject();

      final gate = Completer<void>();
      delayedRepository.pendingWorktreeGate = gate;

      final switched = await provider
          .switchProject('proj_b')
          .timeout(const Duration(milliseconds: 80), onTimeout: () => false);

      expect(switched, isTrue);
      expect(provider.currentProject?.id, 'proj_b');

      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 1));
    });

    test(
      'close and reopen context updates open lists deterministically',
      () async {
        await provider.initializeProject();
        await provider.switchProject('proj_b');

        final closed = await provider.closeProject('proj_a');
        expect(closed, isTrue);
        expect(provider.openProjectIds, isNot(contains('proj_a')));

        final reopened = await provider.reopenProject(
          'proj_a',
          makeActive: false,
        );
        expect(reopened, isTrue);
        expect(provider.openProjectIds, contains('proj_a'));
        expect(provider.currentProject?.id, 'proj_b');
      },
    );

    test(
      'archiveClosedProject hides project from closed list and persists',
      () async {
        await provider.initializeProject();
        await provider.switchProject('proj_b');
        await provider.closeProject('proj_a');

        expect(
          provider.closedProjects.any((project) => project.id == 'proj_a'),
          isTrue,
        );

        final archived = await provider.archiveClosedProject('proj_a');
        expect(archived, isTrue);
        expect(
          provider.closedProjects.any((project) => project.id == 'proj_a'),
          isFalse,
        );
        expect(provider.hiddenProjectPaths, contains('/repo/a'));
        expect(provider.archivedProjectIds, contains('proj_a'));
        expect(
          localDataSource.scopedStrings['archived_project_ids::srv_test'],
          isNotNull,
        );
        expect(
          localDataSource.scopedStrings['hidden_project_paths::srv_test'],
          isNotNull,
        );

        final restoredProvider = ProjectProvider(
          projectRepository: projectRepository,
          localDataSource: localDataSource,
        );
        await restoredProvider.initializeProject();

        expect(
          restoredProvider.closedProjects.any(
            (project) => project.id == 'proj_a',
          ),
          isFalse,
        );
        expect(restoredProvider.hiddenProjectPaths, contains('/repo/a'));
      },
    );

    test('awaited project persistence reports storage failures', () async {
      final failingLocal = _FailingProjectPersistenceDataSource()
        ..activeServerId = 'srv_test';
      provider = ProjectProvider(
        projectRepository: projectRepository,
        localDataSource: failingLocal,
      );
      await provider.initializeProject();
      await provider.switchProject('proj_b');
      await provider.closeProject('proj_a');
      await provider.debugWaitForProjectStatePersistence();
      failingLocal.failArchivedProjectsSave = true;

      await expectLater(
        provider.archiveClosedProject('proj_a'),
        throwsA(isA<StateError>()),
      );
      await provider.debugWaitForProjectStatePersistence();
    });

    test('switchToDirectoryContext unhides a removed project path', () async {
      await provider.initializeProject();
      await provider.switchProject('proj_b');
      await provider.closeProject('proj_a');

      final archived = await provider.archiveClosedProject('proj_a');
      expect(archived, isTrue);
      expect(provider.hiddenProjectPaths, contains('/repo/a'));

      final switched = await provider.switchToDirectoryContext('/repo/a');

      expect(switched, isTrue);
      expect(provider.currentProject?.path, '/repo/a');
      expect(provider.hiddenProjectPaths, isNot(contains('/repo/a')));
    });

    test('worktree operations load/create/reset/delete', () async {
      await provider.initializeProject();

      await provider.loadWorktrees();
      expect(provider.worktreeSupported, isTrue);
      expect(provider.worktrees, hasLength(1));

      final created = await provider.createWorktree('Feature Branch');
      expect(created, isNotNull);

      final resetOk = await provider.resetWorktree(created!.id);
      expect(resetOk, isTrue);

      final deleteOk = await provider.deleteWorktree(created.id);
      expect(deleteOk, isTrue);
      expect(
        provider.projects.any((item) => item.path == created.directory),
        isFalse,
      );
      expect(provider.currentProject?.path, isNot(created.directory));
    });

    test('listDirectories returns sorted unique directories', () async {
      projectRepository.directoriesByPath['/repo/a'] = <String>[
        '/repo/a/zeta',
        '/repo/a/Alpha',
        '/repo/a/alpha',
      ];

      final listed = await provider.listDirectories('/repo/a');

      expect(listed, isNotNull);
      expect(listed, hasLength(3));
      expect(listed!.first, '/repo/a/Alpha');
    });

    test('isGitDirectory returns true for configured git path', () async {
      projectRepository.gitDirectories.add('/repo/a');

      final isGit = await provider.isGitDirectory('/repo/a');

      expect(isGit, isTrue);
    });

    test('switchToDirectoryContext switches to matching directory', () async {
      await provider.initializeProject();

      final switched = await provider.switchToDirectoryContext('/repo/b');

      expect(switched, isTrue);
      expect(provider.currentProject?.path, '/repo/b');
    });

    test(
      'switchToDirectoryContext creates directory fallback when server keeps current project',
      () async {
        await provider.initializeProject();

        final switched = await provider.switchToDirectoryContext('/repo/plain');

        expect(switched, isTrue);
        expect(provider.currentProject?.path, '/repo/plain');
        expect(provider.currentProject?.id, 'dir::/repo/plain');
        expect(
          provider.projects.any((project) => project.path == '/repo/plain'),
          isTrue,
        );
      },
    );

    test(
      'switchToDirectoryContext preserves previously open synthetic directories',
      () async {
        await provider.initializeProject();

        final openedParent = await provider.switchToDirectoryContext(
          '/home/helio',
        );
        final openedNested = await provider.switchToDirectoryContext(
          '/home/helio/MEGA/CONFIG/opencode',
        );

        expect(openedParent, isTrue);
        expect(openedNested, isTrue);
        expect(
          provider.currentProject?.id,
          'dir::/home/helio/MEGA/CONFIG/opencode',
        );
        expect(provider.openProjectIds, contains('dir::/home/helio'));
        expect(
          provider.openProjectIds,
          contains('dir::/home/helio/MEGA/CONFIG/opencode'),
        );
        expect(
          provider.openProjects.map((project) => project.path),
          containsAll(<String>[
            '/home/helio',
            '/home/helio/MEGA/CONFIG/opencode',
          ]),
        );
      },
    );

    test('loadProjects preserves open synthetic directories', () async {
      await provider.initializeProject();
      await provider.switchToDirectoryContext('/home/helio');
      await provider.switchToDirectoryContext(
        '/home/helio/MEGA/CONFIG/opencode',
      );

      await provider.loadProjects();

      expect(provider.openProjectIds, contains('dir::/home/helio'));
      expect(
        provider.openProjectIds,
        contains('dir::/home/helio/MEGA/CONFIG/opencode'),
      );
      expect(
        provider.projects.map((project) => project.path),
        containsAll(<String>[
          '/home/helio',
          '/home/helio/MEGA/CONFIG/opencode',
        ]),
      );
    });

    test(
      'opening another directory preserves previously open projects during partial refresh',
      () async {
        final projectA = Project(
          id: 'proj_a',
          name: 'Project A',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        final projectB = Project(
          id: 'proj_b',
          name: 'Project B',
          path: '/repo/b',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        );
        final serverProjects = <Project>[projectA];
        projectRepository = FakeProjectRepository(
          currentProject: projectA,
          projects: serverProjects,
        );
        provider = ProjectProvider(
          projectRepository: projectRepository,
          localDataSource: localDataSource,
        );

        await provider.initializeProject();
        serverProjects
          ..clear()
          ..add(projectB);

        final switched = await provider.switchToDirectoryContext('/repo/b');

        expect(switched, isTrue);
        expect(provider.currentProject?.id, 'proj_b');
        expect(provider.openProjectIds, contains('proj_a'));
        expect(provider.openProjectIds, contains('proj_b'));
        expect(
          provider.openProjects.map((project) => project.path),
          containsAll(<String>['/repo/a', '/repo/b']),
        );
      },
    );

    test(
      'force reload preserves open projects during same-server recovery',
      () async {
        final projectA = Project(
          id: 'proj_a',
          name: 'Project A',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        final projectB = Project(
          id: 'proj_b',
          name: 'Project B',
          path: '/repo/b',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        );
        final serverProjects = <Project>[projectA, projectB];
        projectRepository = FakeProjectRepository(
          currentProject: projectA,
          projects: serverProjects,
        );
        provider = ProjectProvider(
          projectRepository: projectRepository,
          localDataSource: localDataSource,
        );

        await provider.initializeProject();
        await provider.switchProject('proj_b');
        serverProjects
          ..clear()
          ..add(projectB);

        await provider.initializeProject(forceReload: true);

        expect(provider.currentProject?.id, 'proj_b');
        expect(
          provider.openProjectIds,
          containsAll(<String>['proj_a', 'proj_b']),
        );
        expect(
          provider.openProjects.map((project) => project.path),
          containsAll(<String>['/repo/a', '/repo/b']),
        );
      },
    );

    test('server scope change clears stale current project', () async {
      final projectA = Project(
        id: 'proj_a',
        name: 'Project A',
        path: '/repo/a',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      final projectB = Project(
        id: 'proj_b',
        name: 'Project B',
        path: '/repo/b',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      );
      final serverProjects = <Project>[projectA];
      final mutableRepository = _MutableCurrentProjectRepository(
        currentProject: projectA,
        projects: serverProjects,
      );
      localDataSource.activeServerId = 'srv_old';
      projectRepository = mutableRepository;
      provider = ProjectProvider(
        projectRepository: projectRepository,
        localDataSource: localDataSource,
      );

      await provider.initializeProject();
      localDataSource.activeServerId = 'srv_new';
      mutableRepository.currentProject = projectB;
      serverProjects
        ..clear()
        ..add(projectB);

      await provider.onServerScopeChanged();

      expect(provider.activeServerId, 'srv_new');
      expect(provider.currentProject?.id, 'proj_b');
      expect(provider.openProjectIds, contains('proj_b'));
      expect(provider.openProjectIds, isNot(contains('proj_a')));
      expect(
        localDataSource.scopedStrings['current_project_id::srv_new'],
        'proj_b',
      );
    });

    test(
      'server scope change does not fallback to stale projects on failure',
      () async {
        final projectA = Project(
          id: 'proj_a',
          name: 'Project A',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        localDataSource.activeServerId = 'srv_old';
        projectRepository = FakeProjectRepository(
          currentProject: projectA,
          projects: <Project>[projectA],
        );
        provider = ProjectProvider(
          projectRepository: projectRepository,
          localDataSource: localDataSource,
        );
        await provider.initializeProject();

        localDataSource.activeServerId = 'srv_new';
        projectRepository.getProjectsFailure = const NetworkFailure(
          'Server unavailable',
          503,
        );
        projectRepository.currentProjectFailure = const NetworkFailure(
          'Server unavailable',
          503,
        );

        await provider.onServerScopeChanged();

        expect(provider.activeServerId, 'srv_new');
        expect(provider.status, ProjectStatus.error);
        expect(provider.currentProject, isNull);
        expect(provider.projects, isEmpty);
        expect(provider.openProjectIds, isEmpty);
        expect(
          localDataSource.scopedStrings['current_project_id::srv_new'],
          isNull,
        );
      },
    );

    test(
      'server scope change ignores stale project list completions',
      () async {
        final projectA = Project(
          id: 'proj_a',
          name: 'Project A',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        final queuedRepository = _QueuedProjectListRepository(
          currentProject: projectA,
          projects: <Project>[projectA],
        );
        localDataSource.activeServerId = 'srv_old';
        projectRepository = queuedRepository;
        provider = ProjectProvider(
          projectRepository: projectRepository,
          localDataSource: localDataSource,
        );
        await provider.initializeProject();

        final staleLoad = Completer<Either<Failure, List<Project>>>();
        final newServerLoad = Completer<Either<Failure, List<Project>>>()
          ..complete(
            const Left<Failure, List<Project>>(
              NetworkFailure('Server unavailable', 503),
            ),
          );
        queuedRepository.queuedProjectResults.addAll(
          <Completer<Either<Failure, List<Project>>>>[staleLoad, newServerLoad],
        );
        localDataSource.activeServerId = 'srv_new';
        queuedRepository.currentProjectFailure = const NetworkFailure(
          'Server unavailable',
          503,
        );

        final staleLoadFuture = provider.loadProjects();
        await provider.onServerScopeChanged();

        expect(provider.projects, isEmpty);
        staleLoad.complete(Right<Failure, List<Project>>(<Project>[projectA]));
        await staleLoadFuture;

        expect(provider.activeServerId, 'srv_new');
        expect(provider.status, ProjectStatus.error);
        expect(provider.currentProject, isNull);
        expect(provider.projects, isEmpty);
        expect(provider.openProjectIds, isEmpty);
      },
    );

    test(
      'switchToDirectoryContext accepts normalized server project paths',
      () async {
        projectRepository = _DirectoryProjectRepository(
          currentProject: Project(
            id: 'proj_a',
            name: 'Project A',
            path: '/repo/a',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
          projects: <Project>[
            Project(
              id: 'proj_a',
              name: 'Project A',
              path: '/repo/a',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ],
          projectsByDirectory: <String, Project>{
            '/repo/plain': Project(
              id: 'proj_plain',
              name: 'Plain Project',
              path: '/repo/plain/',
              createdAt: DateTime.fromMillisecondsSinceEpoch(2),
            ),
          },
        );
        provider = ProjectProvider(
          projectRepository: projectRepository,
          localDataSource: localDataSource,
        );
        await provider.initializeProject();

        final switched = await provider.switchToDirectoryContext('/repo/plain');

        expect(switched, isTrue);
        expect(provider.currentProject?.id, 'proj_plain');
        expect(provider.currentProject?.path, '/repo/plain/');
        expect(provider.currentDirectory, '/repo/plain');
        expect(
          provider.projects.any((project) => project.id == 'proj_plain'),
          isTrue,
        );
      },
    );

    test(
      'switchToDirectoryContext returns false when directory is unchanged',
      () async {
        await provider.initializeProject();

        final switched = await provider.switchToDirectoryContext('/repo/a');

        expect(switched, isFalse);
        expect(provider.currentProject?.path, '/repo/a');
      },
    );

    test(
      'initializeProject restores synthetic directory contexts from storage',
      () async {
        await localDataSource.saveCurrentProjectId(
          'dir::/repo/plain',
          serverId: 'srv_test',
        );
        await localDataSource.saveOpenProjectIdsJson(
          jsonEncode(<String>['proj_a', 'dir::/repo/plain']),
          serverId: 'srv_test',
        );

        await provider.initializeProject();

        expect(provider.currentProject?.id, 'dir::/repo/plain');
        expect(provider.currentProject?.path, '/repo/plain');
        expect(provider.currentDirectory, '/repo/plain');
        expect(provider.openProjectIds, contains('dir::/repo/plain'));
        expect(
          provider.projects.any((project) => project.id == 'dir::/repo/plain'),
          isTrue,
        );
        expect(provider.contextKey, 'srv_test::/repo/plain');
      },
    );

    test('listDirectories surfaces errors and logs them', () async {
      projectRepository.directoryFailure = const NetworkFailure(
        'Client error',
        400,
      );

      final listed = await provider.listDirectories('/repo/a');

      expect(listed, isNull);
      expect(provider.error, 'Failed to list directories: Client error');
      expect(
        AppLogger.entries.value.any(
          (entry) => entry.message.contains('Directory list failed'),
        ),
        isTrue,
      );
    });

    test('logs workspace create failure in app logger', () async {
      await provider.initializeProject();
      projectRepository.worktreeFailure = const NetworkFailure(
        'Client error',
        400,
      );

      final created = await provider.createWorktree(
        'Feature Broken',
        directory: '/repo/a',
      );

      expect(created, isNull);
      expect(provider.error, 'Failed to create workspace: Client error');
      expect(
        AppLogger.entries.value.any(
          (entry) => entry.message.contains('Workspace create failed'),
        ),
        isTrue,
      );
      expect(
        AppLogger.entries.value.any(
          (entry) => entry.message.contains('Failed to create workspace'),
        ),
        isTrue,
      );
    });

    test('filters synthetic root project when real contexts exist', () async {
      final rootProject = Project(
        id: '/',
        name: '/',
        path: '/',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      projectRepository = FakeProjectRepository(
        currentProject: rootProject,
        projects: <Project>[
          rootProject,
          Project(
            id: 'proj_real',
            name: 'Project Real',
            path: '/repo/real',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );
      provider = ProjectProvider(
        projectRepository: projectRepository,
        localDataSource: localDataSource,
      );

      await provider.initializeProject();

      expect(provider.projects.map((item) => item.id), isNot(contains('/')));
      expect(provider.currentProject?.id, 'proj_real');
      expect(provider.currentDirectory, '/repo/real');
    });

    test(
      'treats global root project as placeholder when real contexts exist',
      () async {
        final globalProject = Project(
          id: 'global',
          name: 'Global',
          path: '/',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        projectRepository = FakeProjectRepository(
          currentProject: globalProject,
          projects: <Project>[
            globalProject,
            Project(
              id: 'proj_real',
              name: 'Project Real',
              path: '/repo/real',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ],
        );
        provider = ProjectProvider(
          projectRepository: projectRepository,
          localDataSource: localDataSource,
        );

        await provider.initializeProject();

        expect(
          provider.projects.map((item) => item.id),
          isNot(contains('global')),
        );
        expect(provider.currentProject?.id, 'proj_real');
        expect(provider.currentDirectory, '/repo/real');
      },
    );

    test(
      'never persists the placeholder root as the last project',
      () async {
        final globalProject = Project(
          id: 'global',
          name: 'Global',
          path: '/',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        projectRepository = FakeProjectRepository(
          currentProject: globalProject,
          projects: <Project>[globalProject],
        );
        provider = ProjectProvider(
          projectRepository: projectRepository,
          localDataSource: localDataSource,
        );

        await provider.initializeProject();
        await provider.debugWaitForProjectStatePersistence();

        expect(
          localDataSource.scopedStrings['current_project_id::srv_test'],
          isNull,
        );
        expect(
          localDataSource.scopedStrings['open_project_ids::srv_test'],
          '[]',
        );
      },
    );

    test(
      'treats a persisted global id as missing on restore',
      () async {
        await localDataSource.saveCurrentProjectId(
          'global',
          serverId: 'srv_test',
        );
        await localDataSource.saveOpenProjectIdsJson(
          jsonEncode(<String>['global']),
          serverId: 'srv_test',
        );

        await provider.initializeProject();

        expect(provider.status, ProjectStatus.loaded);
        expect(provider.currentProject?.id, 'proj_a');
        expect(provider.openProjectIds, isNot(contains('global')));
      },
    );

    test(
      'root path uses project id as scope and no directory filter',
      () async {
        projectRepository = FakeProjectRepository(
          currentProject: Project(
            id: 'proj_root',
            name: 'Root',
            path: '/',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
          projects: <Project>[
            Project(
              id: 'proj_root',
              name: 'Root',
              path: '/',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ],
        );
        provider = ProjectProvider(
          projectRepository: projectRepository,
          localDataSource: localDataSource,
        );

        await provider.initializeProject();

        expect(provider.currentDirectory, isNull);
        expect(provider.currentScopeId, 'proj_root');
        expect(provider.contextKey, 'srv_test::proj_root');
      },
    );
  });
}
