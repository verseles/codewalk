import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/features/hosts/profile_edit_dialog.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class _UnknownEditProfiles extends MemoryProfiles {
  int edits = 0;
  @override
  Future<EndpointProfile> updateProfile(
    EndpointProfile expected, {
    required String label,
    required Uri endpoint,
  }) async {
    edits++;
    await super.updateProfile(expected, label: label, endpoint: endpoint);
    throw StateError('controlled lost acknowledgement');
  }
}

class _Rig {
  _Rig({MemoryProfiles? repository})
    : repository = repository ?? MemoryProfiles() {
    original = EndpointProfile(
      id: 'profile_one',
      label: 'Original',
      endpoint: Uri.parse('http://127.0.0.1:4096/proxy/'),
    );
    this.repository.profiles.add(original);
    this.repository.secrets[original.id] = 'fake-secret';
    hosts = HostsController(repository: this.repository, prober: prober);
  }

  final MemoryProfiles repository;
  final prober = FakeProber();
  late final EndpointProfile original;
  late final HostsController hosts;
  bool? saved;

  Future<void> mount(
    WidgetTester tester, {
    String locale = 'en',
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    await hosts.load();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      hosts.dispose();
      tester.view.reset();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open-editor'),
              onPressed: () async {
                saved = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      ProfileEditDialog(hosts: hosts, profile: original),
                );
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-editor')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('Enter saves like the primary button (#171)', (tester) async {
    final rig = _Rig();
    await rig.mount(tester, width: 1280);
    await tester.enterText(
      find.byKey(const ValueKey('edit-endpoint-label')),
      'Entered name',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(rig.saved, isTrue);
    expect(rig.repository.profiles.single.label, 'Entered name');
  });

  testWidgets('NumpadEnter saves too, before any field is focused', (
    tester,
  ) async {
    final rig = _Rig();
    await rig.mount(tester, width: 1280);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pumpAndSettle();
    expect(rig.saved, isTrue);
  });

  testWidgets('Enter on a focused Cancel cancels instead of saving', (
    tester,
  ) async {
    final rig = _Rig();
    await rig.mount(tester, width: 1280);
    await tester.enterText(
      find.byKey(const ValueKey('edit-endpoint-label')),
      'Not saved',
    );
    final cancel = find.widgetWithText(
      TextButton,
      lookupV2Localizations(const Locale('en')).commonCancel,
    );
    Focus.of(
      tester.element(find.descendant(of: cancel, matching: find.byType(Text))),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(rig.saved, isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(rig.repository.profiles.single.label, 'Original');
  });

  testWidgets('stale editor keeps typed values and reconciles before retry', (
    tester,
  ) async {
    final rig = _Rig();
    await rig.mount(tester);
    await tester.enterText(
      find.byKey(const ValueKey('edit-endpoint-label')),
      'Typed name',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-endpoint-url')),
      'http://127.0.0.1:4096/other/',
    );
    await rig.hosts.load();
    await tester.tap(find.byKey(const ValueKey('edit-endpoint-save')));
    await tester.pumpAndSettle();
    expect(
      find.text(lookupV2Localizations(const Locale('en')).hostsEditChanged),
      findsOneWidget,
    );
    expect(rig.repository.profiles.single, same(rig.original));
    final label = tester.widget<TextFormField>(
      find.byKey(const ValueKey('edit-endpoint-label')),
    );
    expect(label.controller!.text, 'Typed name');
    expect(find.byKey(const ValueKey('endpoint-secret')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('edit-endpoint-reload')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        lookupV2Localizations(const Locale('en')).hostsEditSavedProfile,
      ),
      findsOneWidget,
    );
    expect(rig.repository.profiles.single, same(rig.original));
    await tester.tap(find.byKey(const ValueKey('edit-endpoint-save')));
    await tester.pumpAndSettle();
    expect(rig.saved, isTrue);
    expect(rig.repository.profiles.single.label, 'Typed name');
    expect(rig.repository.profiles.single.bindingRevision, 1);
    expect(rig.prober.tasks, isEmpty);
  });

  testWidgets(
    'read-only reload confirms an unknown committed edit without another write',
    (tester) async {
      final repository = _UnknownEditProfiles();
      final rig = _Rig(repository: repository);
      await rig.mount(tester);
      await tester.enterText(
        find.byKey(const ValueKey('edit-endpoint-label')),
        'Committed name',
      );
      await tester.tap(find.byKey(const ValueKey('edit-endpoint-save')));
      await tester.pumpAndSettle();
      expect(rig.saved, isNull);
      expect(repository.edits, 1);
      expect(rig.hosts.storageError, isTrue);
      await tester.tap(find.byKey(const ValueKey('edit-endpoint-reload')));
      await tester.pumpAndSettle();
      expect(rig.saved, isTrue);
      expect(repository.edits, 1);
      expect(rig.hosts.profiles.single.label, 'Committed name');
      expect(rig.prober.tasks, isEmpty);
    },
  );

  for (final (locale, width, scale) in [
    ('en', 390.0, 1.0),
    ('ar', 390.0, 2.0),
    ('ur', 1280.0, 2.0),
  ]) {
    testWidgets(
      'metadata editor validates without overflow: $locale/$width/$scale',
      (tester) async {
        final rig = _Rig();
        await rig.mount(tester, locale: locale, width: width, scale: scale);
        await tester.enterText(
          find.byKey(const ValueKey('edit-endpoint-label')),
          '',
        );
        await tester.enterText(
          find.byKey(const ValueKey('edit-endpoint-url')),
          'https://user:private@example.test/',
        );
        final save = find.byKey(const ValueKey('edit-endpoint-save'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        final l = lookupV2Localizations(Locale(locale));
        expect(find.text(l.hostsEditInvalidLabel), findsOneWidget);
        expect(find.text(l.onboardingInvalidUrl), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(rig.saved, isNull);
        expect(rig.repository.profiles.single, same(rig.original));
        expect(rig.prober.tasks, isEmpty);
      },
    );
  }
}
