import 'dart:async';

import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts/fakes.dart';
import 'storage/storage_fakes.dart';

AppDependencies _graph(FakeProber prober) {
  final profile = EndpointProfile(
    id: 'profile_health',
    label: 'Health test',
    endpoint: Uri.parse('http://127.0.0.1:4096/'),
  );
  return createAppDependencies(
    initialLink: Uri(path: '/settings'),
    metadataStore: V2MetadataStore(backend: FakeMetadataBackend()),
    profileRepository: MemoryProfiles()
      ..profiles.add(profile)
      ..secrets[profile.id] = 'test-only',
    endpointProber: prober,
  );
}

void main() {
  testWidgets(
    'bootstrap pauses health in background and cancels only owned probes',
    (tester) async {
      final prober = FakeProber()
        ..pendingResult = Completer<EndpointAssessment>().future;
      final graph = _graph(prober);
      try {
        await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
        await tester.pumpAndSettle();
        expect(prober.tasks, hasLength(1));
        expect(graph.endpointHealth?.foreground, isTrue);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        expect(prober.tasks.single.cancelled, isFalse);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        expect(prober.tasks.single.cancelled, isTrue);
        await tester.pump(const Duration(seconds: 30));
        expect(prober.tasks, hasLength(1));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(prober.tasks, hasLength(2));
        expect(prober.tasks.last.cancelled, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(graph.isDisposed, isTrue);
        expect(prober.tasks.last.cancelled, isTrue);
      } finally {
        graph.dispose();
        if (tester.binding.lifecycleState == AppLifecycleState.paused) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
        }
        if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        }
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    },
  );

  testWidgets('replacing the graph starts only its new health owner', (
    tester,
  ) async {
    final oldProber = FakeProber()
      ..pendingResult = Completer<EndpointAssessment>().future;
    final newProber = FakeProber()
      ..pendingResult = Completer<EndpointAssessment>().future;
    final oldGraph = _graph(oldProber);
    final newGraph = _graph(newProber);
    try {
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: oldGraph));
      await tester.pumpAndSettle();
      expect(oldProber.tasks, hasLength(1));
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: newGraph));
      await tester.pumpAndSettle();
      expect(oldGraph.isDisposed, isTrue);
      expect(oldProber.tasks.single.cancelled, isTrue);
      expect(newProber.tasks, hasLength(1));
      expect(newProber.tasks.single.cancelled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(newProber.tasks.single.cancelled, isTrue);
    } finally {
      oldGraph.dispose();
      newGraph.dispose();
    }
  });
}
