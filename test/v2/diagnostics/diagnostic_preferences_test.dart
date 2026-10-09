import 'dart:async';

import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/diagnostics/diagnostics_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

void main() {
  test(
    'failed reload retains already hydrated consent and collected events',
    () async {
      final backend = FakeMetadataBackend();
      backend.values['cw2.settings.loggingEnabled'] = true;
      backend.values['cw2.settings.shortcuts'] = 'invalid';
      final logs = DiagnosticsController();
      final preferences = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
        diagnostics: logs,
      );
      await preferences.initialize();
      logs.record(DiagnosticOperation.hostProbe, DiagnosticOutcome.success);
      backend.failRead = true;
      await preferences.retryPersistence();
      expect(preferences.loggingEnabled, isTrue);
      expect(preferences.hasPersistenceError, isTrue);
      expect(logs.enabled, isTrue);
      expect(
        logs.events.any((e) => e.operation == DiagnosticOperation.hostProbe),
        isTrue,
      );
      expect(logs.events.last.operation, DiagnosticOperation.preferencesLoad);
      expect(logs.events.last.outcome, DiagnosticOutcome.failure);
      preferences.dispose();
      logs.dispose();
    },
  );

  test(
    'preserves opt-in and exposes failed saves without retaining after OFF',
    () async {
      final backend = FakeMetadataBackend();
      backend.values['cw2.settings.loggingEnabled'] = true;
      final logs = DiagnosticsController();
      final preferences = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
        diagnostics: logs,
      );
      await preferences.initialize();
      expect(preferences.loggingEnabled, isTrue);
      expect(logs.enabled, isTrue);
      backend.failWrite = 'cw2.settings.loggingEnabled';
      preferences.setLoggingEnabled(false);
      expect(logs.events, isEmpty);
      await preferences.flush();
      expect(preferences.hasPersistenceError, isTrue);
      expect(logs.enabled, isFalse);
      expect(backend.values['cw2.settings.loggingEnabled'], isTrue);
      backend.failWrite = null;
      await preferences.retryPersistence();
      expect(backend.values['cw2.settings.loggingEnabled'], isFalse);
      expect(preferences.hasPersistenceError, isFalse);
      preferences.dispose();
      logs.dispose();
    },
  );

  test(
    'pending ON save cannot undo a newer OFF choice or repopulate logs',
    () async {
      final backend = FakeMetadataBackend();
      backend.values[V2MetadataStore.schemaKey] = 1;
      backend.blockedKey = 'cw2.settings.loggingEnabled';
      backend.entered = Completer<void>();
      backend.release = Completer<void>();
      final logs = DiagnosticsController();
      final preferences = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
        diagnostics: logs,
      );
      await preferences.initialize();
      preferences.setLoggingEnabled(true);
      await backend.entered!.future;
      preferences.setLoggingEnabled(false);
      expect(logs.enabled, isFalse);
      backend.release!.complete();
      await preferences.flush();
      expect(backend.values['cw2.settings.loggingEnabled'], isFalse);
      expect(logs.events, isEmpty);
      preferences.dispose();
      logs.dispose();
    },
  );

  test(
    'invalid or unreadable opt-in stays OFF without rewriting old metadata',
    () async {
      final backend = FakeMetadataBackend();
      backend.values['cw2.settings.loggingEnabled'] = 'invalid';
      final logs = DiagnosticsController();
      final preferences = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
        diagnostics: logs,
      );
      await preferences.initialize();
      expect(preferences.loggingEnabled, isFalse);
      expect(backend.values['cw2.settings.loggingEnabled'], 'invalid');
      expect(backend.writes, isNot(contains('cw2.settings.loggingEnabled')));
      preferences.dispose();
      logs.dispose();
    },
  );
}
