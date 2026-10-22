import 'package:codewalk/features/sessions/session_error_card.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ErrorInfo _error(
  OpenValue<ErrorKind> kind, {
  String message = 'Error from provider: the free tier is limited.',
  ErrorAction? action = ErrorAction.changeModel,
  CanonicalValue? details,
}) => ErrorInfo(
  kind: kind,
  rawType: 'provider.auth',
  rawMessage: message,
  action: action == null ? null : OpenValue.known(action),
  details: details,
);

TurnOutcome _outcome(
  ErrorInfo? error, {
  OutcomeKind kind = OutcomeKind.failed,
}) => TurnOutcome(
  meta: ItemMeta(
    id: const ItemId('outcome'),
    generation: 'g',
    status: const OpenValue.known(ItemStatus.completed),
    source: SourceProvenance(
      harness: const HarnessRef(
        HostId('host-a'),
        HarnessInstanceId('native-a'),
      ),
      version: '2.0.22',
      nativeType: 'session.execution.failed',
    ),
  ),
  kind: OpenValue.known(kind),
  error: error,
);

// Any Material button, subclasses included.
final _buttons = find.byWidgetPredicate((w) => w is ButtonStyleButton);

void main() {
  late V2Localizations en;

  setUpAll(() async {
    en = await V2Localizations.delegate.load(const Locale('en'));
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(800, 900),
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: ListView(children: [child])),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every category has its own title and explanation', (
    tester,
  ) async {
    final cases = {
      ErrorKind.auth: (en.liveErrorAuth, en.liveErrorAuthDetail),
      ErrorKind.rateLimit: (en.liveErrorRateLimit, en.liveErrorRateLimitDetail),
      ErrorKind.quota: (en.liveErrorQuota, en.liveErrorQuotaDetail),
      ErrorKind.contextOverflow: (
        en.liveErrorContext,
        en.liveErrorContextDetail,
      ),
      ErrorKind.provider: (en.liveErrorProvider, en.liveErrorProviderDetail),
      ErrorKind.network: (en.liveErrorNetwork, en.liveErrorNetworkDetail),
      ErrorKind.contentFilter: (
        en.liveErrorContentFilter,
        en.liveErrorContentFilterDetail,
      ),
      ErrorKind.versionUnsupported: (
        en.liveErrorVersion,
        en.liveErrorVersionDetail,
      ),
      // Kinds without a card of their own use the unknown card.
      ErrorKind.permissionRejected: (
        en.liveErrorUnknown,
        en.liveErrorUnknownDetail,
      ),
      ErrorKind.toolFailure: (en.liveErrorUnknown, en.liveErrorUnknownDetail),
      ErrorKind.protocol: (en.liveErrorUnknown, en.liveErrorUnknownDetail),
      ErrorKind.unknown: (en.liveErrorUnknown, en.liveErrorUnknownDetail),
    };
    expect(cases.keys, unorderedEquals(ErrorKind.values));
    for (final MapEntry(key: kind, value: (title, detail)) in cases.entries) {
      await pump(
        tester,
        SessionErrorCard(error: _error(OpenValue.known(kind))),
      );
      expect(find.text(title), findsOneWidget, reason: kind.name);
      expect(find.text(detail), findsOneWidget, reason: kind.name);
      expect(
        find.text('Error from provider: the free tier is limited.'),
        findsOneWidget,
      );
    }
    final titles = {for (final (title, _) in cases.values) title};
    expect(titles, hasLength(9));
  });

  testWidgets('an unknown value never reads as nothing, zero or success', (
    tester,
  ) async {
    await pump(
      tester,
      SessionErrorCard(
        error: _error(OpenValue.unknown('futureKind'), message: ''),
      ),
    );
    expect(find.text(en.liveErrorUnknown), findsOneWidget);
    expect(find.text(en.liveErrorNoDetails), findsOneWidget);
    expect(find.text(en.liveOutcomeSucceeded), findsNothing);
    expect(find.textContaining('0'), findsNothing);
    expect(find.byKey(const ValueKey('live-error-message')), findsNothing);
  });

  testWidgets('offers exactly the one recovery it is given', (tester) async {
    var pressed = 0;
    final error = _error(const OpenValue.known(ErrorKind.quota));
    await pump(
      tester,
      SessionErrorCard(
        error: error,
        recovery: sessionErrorRecovery(en, error, chooseModel: () => pressed++),
      ),
    );
    expect(_buttons, findsOneWidget);
    expect(find.text(en.liveErrorChooseModel), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('live-error-action')));
    expect(pressed, 1);
    await pump(tester, SessionErrorCard(error: error));
    expect(_buttons, findsNothing);
  });

  test('recoveries map only to surfaces that exist', () {
    void none() {}
    for (final action in ErrorAction.values) {
      final error = _error(
        const OpenValue.known(ErrorKind.unknown),
        action: action,
      );
      final both = sessionErrorRecovery(
        en,
        error,
        chooseModel: none,
        openServers: none,
      );
      switch (action) {
        case ErrorAction.changeModel:
          expect(both!.label, en.liveErrorChooseModel);
          expect(sessionErrorRecovery(en, error, openServers: none), isNull);
        case ErrorAction.upgrade:
          expect(both!.label, en.liveErrorOpenServers);
          expect(sessionErrorRecovery(en, error, chooseModel: none), isNull);
        // No surface exists for these, and none of them replays a turn.
        case ErrorAction.authenticate ||
            ErrorAction.retryRecovery ||
            ErrorAction.refresh ||
            ErrorAction.contactHost:
          expect(both, isNull, reason: action.name);
      }
    }
    expect(
      sessionErrorRecovery(
        en,
        _error(const OpenValue.known(ErrorKind.auth), action: null),
        chooseModel: none,
      ),
      isNull,
    );
  });

  testWidgets('a shortened message says so', (tester) async {
    await pump(
      tester,
      SessionErrorCard(
        error: _error(
          const OpenValue.known(ErrorKind.provider),
          details: CanonicalValue({'messageTruncated': true}),
        ),
      ),
    );
    expect(find.text(en.liveErrorShortened), findsOneWidget);
  });

  for (final (name, size, locale, scale) in [
    ('compact', const Size(320, 640), const Locale('en'), 1.0),
    ('wide', const Size(1024, 768), const Locale('en'), 1.0),
    ('rtl', const Size(360, 740), const Locale('ar'), 1.0),
    ('2x', const Size(360, 740), const Locale('en'), 2.0),
    ('rtl 2x', const Size(360, 740), const Locale('ur'), 2.0),
  ]) {
    testWidgets('a long message stays bounded and the action reachable '
        '($name)', (tester) async {
      final error = _error(
        const OpenValue.known(ErrorKind.contextOverflow),
        message: List.filled(400, 'unbroken-provider-text').join(' '),
        details: CanonicalValue({'messageTruncated': true}),
      );
      late V2Localizations l10n;
      await pump(
        tester,
        Builder(
          builder: (context) {
            l10n = V2Localizations.of(context);
            return SessionErrorCard(
              error: error,
              recovery: sessionErrorRecovery(l10n, error, chooseModel: () {}),
            );
          },
        ),
        size: size,
        locale: locale,
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      final message = tester.getSize(
        find.byKey(const ValueKey('live-error-message')),
      );
      expect(message.height, lessThanOrEqualTo(240));
      final action = find.byKey(const ValueKey('live-error-action'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      expect(find.text(l10n.liveErrorChooseModel), findsOneWidget);
      if (locale.languageCode != 'en') {
        expect(Directionality.of(tester.element(action)), TextDirection.rtl);
      }
    });
  }

  testWidgets('the timeline row shows the card only for a failed turn with '
      'its error', (tester) async {
    final error = _error(const OpenValue.known(ErrorKind.auth));
    await pump(
      tester,
      SessionTimelineTile(
        item: _outcome(error),
        errorRecovery: (e) => sessionErrorRecovery(en, e, chooseModel: () {}),
      ),
    );
    expect(find.text(en.liveErrorAuth), findsOneWidget);
    expect(find.byKey(const ValueKey('live-error-action')), findsOneWidget);
    expect(find.text(en.liveOutcomeFailed), findsNothing);
    // Read-only history passes no recovery: the card stays, without a button.
    await pump(tester, SessionTimelineTile(item: _outcome(error)));
    expect(find.text(en.liveErrorAuth), findsOneWidget);
    expect(find.byKey(const ValueKey('live-error-action')), findsNothing);
    // Without an error the plain marker stays.
    await pump(tester, SessionTimelineTile(item: _outcome(null)));
    expect(find.text(en.liveOutcomeFailed), findsOneWidget);
    expect(find.byKey(const ValueKey('live-error-card')), findsNothing);
    await pump(
      tester,
      SessionTimelineTile(item: _outcome(error, kind: OutcomeKind.succeeded)),
    );
    expect(find.text(en.liveOutcomeSucceeded), findsOneWidget);
    expect(find.byKey(const ValueKey('live-error-card')), findsNothing);
  });
}
