import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

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
    });
  });
}
