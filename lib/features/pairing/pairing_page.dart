// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/app_navigation_controller.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/layout/window_size_class.dart';
import '../hosts/add_server_panel.dart';
import 'pairing_controller.dart';

/// The `/pair` route (#506): a full page on compact windows and, from 600 dp,
/// a dialog over the page beneath it (owner decision Q5). It stays one route
/// on every width, so links, Back and saving never hand off between screens.
class PairingRoutePage extends Page<void> {
  const PairingRoutePage({super.key});

  @override
  Route<void> createRoute(BuildContext context) => _AddServerRoute(this);
}

class _AddServerRoute extends PageRoute<void> {
  _AddServerRoute(PairingRoutePage page) : super(settings: page);

  // Keeps the form's state when a resize switches page and dialog.
  final _content = GlobalKey();

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel {
    final context = navigator?.context;
    return context == null
        ? null
        : Localizations.of<MaterialLocalizations>(
            context,
            MaterialLocalizations,
          )?.modalBarrierDismissLabel;
  }

  @override
  bool get maintainState => true;

  // A tap beside the dialog leaves like Back, still held by the page's pop
  // guard; opened directly by a link, with nothing beneath, it goes to the
  // server list as a save does.
  @override
  Widget buildModalBarrier() => ModalBarrier(
    dismissible: true,
    semanticsLabel: barrierLabel,
    onDismiss: () {
      switch (popDisposition) {
        case RoutePopDisposition.pop:
          navigator?.maybePop();
        case RoutePopDisposition.bubble:
          if (subtreeContext case final context?) context.go('/hosts');
        case RoutePopDisposition.doNotPop:
          break;
      }
    },
  );

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final content = KeyedSubtree(key: _content, child: const PairingPage());
    final scheme = Theme.of(context).colorScheme;
    if (context.windowSizeClass.isCompact) {
      return Material(color: scheme.surface, child: content);
    }
    // Taps beside the dialog reach this route's barrier, which closes it
    // through the page's own pop guard.
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: scheme.scrim.withValues(alpha: 0.32)),
          ),
        ),
        Center(
          child: Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: content,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.windowSizeClass.isCompact) {
      return Theme.of(context).pageTransitionsTheme.buildTransitions(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
      child: child,
    );
  }
}

/// The add-server screen's content, also opened by pairing links. Saving
/// returns to where it opened, or to the server list when a link opened it
/// directly.
class PairingPage extends StatefulWidget {
  const PairingPage({super.key});
  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  PairingController? _controller;
  int _linkRevision = -1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<PairingController>();
  }

  void _done() {
    if (!mounted) return;
    // This page's own navigator: a dialog over the whole app stays open.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/hosts');
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<AppNavigationController>();
    if (_linkRevision != navigation.pairingRevision) {
      _linkRevision = navigation.pairingRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final link = navigation.consumePairingLink();
        if (link != null && link.hasQuery) _controller?.input(link.toString());
      });
    }
    final l = context.v2L10n;
    final profile = context.watch<PairingController>().target;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                profile == null ? l.serversAddServer : l.pairingAgain,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (profile != null) Text(profile.label),
              const SizedBox(height: 16),
              AddServerPanel(
                onDone: _done,
                linkRevision: navigation.pairingRevision,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
