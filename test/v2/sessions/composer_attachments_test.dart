import 'dart:async';
import 'dart:typed_data';

import 'package:codewalk/features/sessions/composer_attach_button.dart';
import 'package:codewalk/features/sessions/composer_attachment_strip.dart';
import 'package:codewalk/features/sessions/composer_attachments_controller.dart';
import 'package:codewalk/features/sessions/location_picker_dialog.dart';
import 'package:codewalk/features/sessions/session_composer_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/platform/sessions/attachment_staging_store.dart';
import 'package:codewalk/platform/storage/attachment_blob_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/media/attachment_picker.dart';
import 'package:codewalk/shared/media/location_fix_source.dart';
import 'package:codewalk/shared/sessions/prompt_outbox.dart';
import 'package:codewalk/shared/sessions/session_attachments.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'outbox_fakes.dart';

final _png1x1 = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
  0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
  0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

final _pdfBytes = Uint8List.fromList('%PDF-1.7\nbody'.codeUnits);

final class _FakePicker implements AttachmentPickerPort {
  _FakePicker(this.result);
  List<PickedAttachmentFile> result;
  AttachmentPickCategory? lastCategory;

  @override
  Future<List<PickedAttachmentFile>> pick(
    AttachmentPickCategory category, {
    required int maxBytes,
  }) async {
    lastCategory = category;
    return result;
  }
}

final class _FakeLocationSource implements LocationFixSource {
  _FakeLocationSource({required this.result});
  @override
  bool get supported => true;
  LocationFixResult result;

  @override
  Future<LocationFixResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 5),
  }) async => result;
}

Widget _wrap({
  required Widget child,
  AttachmentBlobRepository? blobs,
  AttachmentPickerPort? picker,
  LocationFixSource? locationSource,
}) => MultiProvider(
  providers: [
    Provider<AttachmentBlobRepository?>.value(value: blobs),
    Provider<AttachmentPickerPort?>.value(value: picker),
    Provider<LocationFixSource?>.value(value: locationSource),
  ],
  child: MaterialApp(
    localizationsDelegates: V2Localizations.localizationsDelegates,
    supportedLocales: V2Localizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('attach menu stages image, file, audio, and location and removes chips', (
    tester,
  ) async {
    final blobs = MemoryAttachmentBlobStore();
    final picker = _FakePicker([
      PickedAttachmentFile(
        name: 'photo.png',
        byteSize: _png1x1.length,
        openRead: () => Stream.value(_png1x1),
      ),
    ]);
    final locSource = _FakeLocationSource(
      result: LocationFixResult.ok(
        GeoPoint(latitude: -23.55052, longitude: -46.633308, accuracyMeters: 12),
      ),
    );
    final controller = ComposerAttachmentsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        blobs: blobs,
        picker: picker,
        locationSource: locSource,
        child: Column(
          children: [
            ComposerAttachmentStrip(
              attachments: controller,
              modelInputModalities: const {'image': true, 'pdf': false},
              supportsStageUpload: true,
            ),
            ComposerAttachButton(attachments: controller),
          ],
        ),
      ),
    );

    // 1. Pick image via + button menu.
    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('composer-attach-image')));
    await tester.pumpAndSettle();
    expect(picker.lastCategory, AttachmentPickCategory.image);
    expect(controller.items, hasLength(1));
    expect(controller.items.single.kind, AttachmentKind.image);
    expect(find.text('photo.png'), findsOneWidget);

    // 2. Pick PDF when model lacks PDF modality -> shows "Uploaded as file" badge.
    picker.result = [
      PickedAttachmentFile(
        name: 'spec.pdf',
        byteSize: _pdfBytes.length,
        openRead: () => Stream.value(_pdfBytes),
      ),
    ];
    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('composer-attach-file')));
    await tester.pumpAndSettle();
    expect(controller.items, hasLength(2));
    expect(find.text('spec.pdf'), findsOneWidget);
    expect(find.textContaining('Uploaded as file'), findsOneWidget);

    // 3. Pick location via GPS button in LocationPickerDialog.
    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('composer-attach-location')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location-picker-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('location-use-current')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('location-label')), 'HQ');
    await tester.tap(find.byKey(const ValueKey('location-confirm')));
    await tester.pumpAndSettle();
    expect(controller.items, hasLength(3));
    expect(controller.items.last.kind, AttachmentKind.location);
    expect(controller.items.last.location?.label, 'HQ');

    // 4. Remove chip.
    final firstId = controller.items.first.id;
    await tester.tap(find.byKey(ValueKey('composer-attachment-remove-$firstId')));
    await tester.pumpAndSettle();
    expect(controller.items, hasLength(2));
  });

  testWidgets('location picker validates coordinates and handles denied GPS gracefully', (
    tester,
  ) async {
    final locSource = _FakeLocationSource(
      result: const LocationFixResult.failure(LocationFixOutcome.denied),
    );
    GeoPoint? picked;

    await tester.pumpWidget(
      _wrap(
        locationSource: locSource,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showLocationPickerDialog(
                context,
                locationSource: locSource,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('location-use-current')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location-status')), findsOneWidget);

    // Invalid coordinates stay blocked.
    await tester.enterText(find.byKey(const ValueKey('location-latitude')), '999');
    await tester.enterText(find.byKey(const ValueKey('location-longitude')), '0');
    await tester.tap(find.byKey(const ValueKey('location-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location-error')), findsOneWidget);
    expect(picked, isNull);

    // Valid manual coordinates succeed.
    await tester.enterText(find.byKey(const ValueKey('location-latitude')), '40.7128');
    await tester.enterText(find.byKey(const ValueKey('location-longitude')), '-74.0060');
    await tester.tap(find.byKey(const ValueKey('location-confirm')));
    await tester.pumpAndSettle();
    expect(picked?.latitude, closeTo(40.7128, 0.0001));
    expect(picked?.longitude, closeTo(-74.0060, 0.0001));
  });

  test('SessionComposerController sends attachment-only prompts, maps attachment refusals, and restores attachments on take-back', () async {
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    await rig.save('a');
    await rig.sessions.initialize();
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    addTearDown(live.dispose);
    final composer = SessionComposerController(
      live: live,
      commandIds: () => const CommandId('cmd_att_1'),
    );
    addTearDown(composer.dispose);

    final outbox = FakeOutbox();
    final opening = live.start();
    final handle = directory.grant(ref, outbox: outbox);
    await opening;
    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        lastSyncedAt: DateTime.utc(2026, 11, 19),
        state: liveState(ref),
      ),
    );
    await pumpEventQueue();

    final locRef = StagedAttachment.location(
      id: 'loc_1',
      location: GeoPoint(latitude: -23.5, longitude: -46.6, label: 'Pin'),
    ).toAttachmentRef();

    // Attachment-only send succeeds with empty text.
    final ok = await composer.send('', attachments: [locRef]);
    expect(ok, isTrue);
    expect(outbox.list.single.attachments, [locRef]);

    // Refusal mapping for attachment errors.
    expect(submitRefusal('attachmentTooLarge'), ComposerNotice.attachmentTooLarge);
    expect(submitRefusal('attachmentMissing'), ComposerNotice.attachmentMissing);
    expect(submitRefusal('uploadFailed'), ComposerNotice.uploadFailed);
    expect(submitRefusal('uploadUnavailable'), ComposerNotice.uploadUnavailable);
    expect(submitRefusal('rateLimited'), ComposerNotice.rateLimited);
    expect(submitRefusal('UnauthorizedError'), ComposerNotice.authRequired);

    // Take-back restores staged attachments into live.attachments.
    outbox.onCancel = (entry) => OutboxEntry(
      session: entry.session,
      commandId: entry.commandId,
      messageId: entry.messageId,
      text: entry.text,
      attachments: entry.attachments,
      delivery: entry.delivery,
      state: SubmissionKind.cancelled,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      fence: CancellationFence.cancelled,
      source: entry.source,
      takenBack: true,
    );
    final cancelled = await composer.takeBack(const CommandId('cmd_att_1'));
    expect(cancelled, isTrue);
    await pumpEventQueue();
    expect(live.attachments.items, hasLength(1));
    expect(live.attachments.items.single.location?.label, 'Pin');
  });

  test('ComposerAttachmentsController discards stale in-flight staging when scope switches', () async {
    final blobs = MemoryAttachmentBlobStore();
    final staging = AttachmentStagingStore(payloads: OutboxStore(), blobs: blobs);
    final controller = ComposerAttachmentsController(store: staging);
    addTearDown(controller.dispose);

    await controller.bindScope('draft-project-a');
    final streamController = StreamController<List<int>>();
    final stagingFuture = controller.stagePickedFiles([
      PickedAttachmentFile(
        name: 'secret-a.png',
        byteSize: _png1x1.length,
        openRead: () => streamController.stream,
      ),
    ], blobs);
    await pumpEventQueue();
    expect(controller.picking, isTrue);

    // User switches to project B while project A's file read is still in flight.
    await controller.bindScope('draft-project-b');
    expect(controller.picking, isFalse);
    expect(controller.items, isEmpty);

    // Project A's stream completes late; it must NOT leak into project B!
    streamController.add(_png1x1);
    await streamController.close();
    await stagingFuture;

    expect(controller.items, isEmpty);
    expect(await staging.load('draft-project-b'), isEmpty);
  });

  testWidgets('ComposerAttachButton omits audio choice when supportsAudio is false', (
    tester,
  ) async {
    final blobs = MemoryAttachmentBlobStore();
    final picker = _FakePicker([]);
    final controller = ComposerAttachmentsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        blobs: blobs,
        picker: picker,
        locationSource: _FakeLocationSource(
          result: const LocationFixResult.failure(
            LocationFixOutcome.unavailable,
          ),
        ),
        child: ComposerAttachButton(
          attachments: controller,
          supportsAudio: false,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('composer-attach-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('composer-attach-file')), findsOneWidget);
    expect(find.byKey(const ValueKey('composer-attach-audio')), findsNothing);
    expect(
      find.byKey(const ValueKey('composer-attach-location')),
      findsOneWidget,
    );
  });

  test('clearScope clears only the target scope and takeBack waits for attachment pin before dismissing outbox', () async {
    final blobs = MemoryAttachmentBlobStore();
    final payloads = OutboxStore();
    final staging = AttachmentStagingStore(payloads: payloads, blobs: blobs);
    final controller = ComposerAttachmentsController(store: staging);
    addTearDown(controller.dispose);

    // 1. Stage under ws:a, switch to ws:b and stage there, then clearScope(ws:a).
    await controller.bindScope('ws:a');
    await controller.addLocation(GeoPoint(latitude: 1, longitude: 2, label: 'A'));
    await controller.bindScope('ws:b');
    await controller.addLocation(GeoPoint(latitude: 3, longitude: 4, label: 'B'));

    await controller.clearScope('ws:a');
    // Active scope ws:b stays intact in memory and storage; ws:a is cleared.
    expect(controller.items.single.location?.label, 'B');
    expect(await staging.load('ws:a'), isEmpty);
    expect((await staging.load('ws:b')).single.location?.label, 'B');
  });
}
