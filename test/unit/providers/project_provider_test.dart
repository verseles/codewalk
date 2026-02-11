import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/logging/app_logger.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/domain/entities/worktree.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';

import '../../support/fakes.dart';

void main() {
  group('ProjectProvider', () {
    late InMemoryAppLocalDataSource localDataSource;
    late FakeProjectRepository projectRepository;
    late ProjectProvider provider;

    setUp(() {
      AppLogger.clearEntries();
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
        expect(provider.archivedProjectIds, contains('proj_a'));
        expect(
          localDataSource.scopedStrings['archived_project_ids::srv_test'],
          isNotNull,
        );
      },
    );

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
      'switchToDirectoryContext returns false when directory is unchanged',
      () async {
        await provider.initializeProject();

        final switched = await provider.switchToDirectoryContext('/repo/a');

        expect(switched, isFalse);
        expect(provider.currentProject?.path, '/repo/a');
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
