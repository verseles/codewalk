import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n_context.dart';

/// A new serial replays navigation even when the same option is selected twice.
class SettingsSearchRequest {
  const SettingsSearchRequest(this.targetKey, this.label, this.serial);
  final String targetKey;
  final String label;
  final int serial;
}

/// Reveals explicitly keyed controls; never inspects text or setting values.
class SettingsSearchDestination extends StatefulWidget {
  const SettingsSearchDestination({
    super.key,
    required this.child,
    this.request,
    this.active = true,
  });
  final Widget child;
  final SettingsSearchRequest? request;
  final bool active;

  static SettingsSearchRequest? requestOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SearchScope>()?.request;

  static void contentReady(BuildContext context) {
    context
        .dependOnInheritedWidgetOfExactType<_SearchScope>()
        ?.state
        ._schedule();
  }

  @override
  State<SettingsSearchDestination> createState() =>
      _SettingsSearchDestinationState();
}

class _SettingsSearchDestinationState extends State<SettingsSearchDestination> {
  final _contentKey = GlobalKey();
  final _surfaceKey = GlobalKey();
  Timer? _deadline;
  Timer? _highlightTimer;
  int? _handled;
  bool _scheduled = false;
  Rect? _highlight;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A resized viewport can invalidate the paint-only highlight geometry.
    MediaQuery.sizeOf(context);
    _highlight = null;
  }

  @override
  void didUpdateWidget(SettingsSearchDestination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request ||
        oldWidget.active != widget.active) {
      _begin();
    }
  }

  void _begin() {
    _deadline?.cancel();
    _highlightTimer?.cancel();
    _highlight = null;
    if (!widget.active || widget.request == null) return;
    _handled = null;
    final request = widget.request!;
    _deadline = Timer(const Duration(seconds: 5), () {
      if (!mounted || !widget.active || _handled == request.serial) return;
      _handled = request.serial;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            '${request.label}: ${context.l10n.onboardingNotAvailable}',
          ),
        ),
      );
    });
    _schedule();
  }

  void _schedule() {
    if (_scheduled ||
        !widget.active ||
        widget.request == null ||
        _handled == widget.request!.serial) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _reveal();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _reveal() {
    final request = widget.request;
    if (!widget.active ||
        request == null ||
        _handled == request.serial ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    Element? target;
    void visit(Element element) {
      if (element.widget.key == ValueKey<String>(request.targetKey)) {
        target = element;
        return;
      }
      if (target == null) element.visitChildElements(visit);
    }

    final root = _contentKey.currentContext as Element?;
    root?.visitChildElements(visit);
    final found = target;
    final render = found?.findRenderObject();
    if (found == null || render is! RenderBox || !render.hasSize) return;
    _handled = request.serial;
    _deadline?.cancel();
    // Bounded forms mount every control, so exact reveal needs no offset guess.
    unawaited(Scrollable.ensureVisible(found, alignment: 0.15));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.active ||
          widget.request != request ||
          !found.mounted) {
        return;
      }
      final surface = _surfaceKey.currentContext?.findRenderObject();
      final box = found.findRenderObject();
      if (surface is! RenderBox || box is! RenderBox || !box.attached) return;
      setState(
        () => _highlight =
            box.localToGlobal(Offset.zero, ancestor: surface) & box.size,
      );
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlight = null);
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SearchScope(
      state: this,
      request: widget.request,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _deadline?.cancel();
            _handled = widget.request?.serial;
          }
          if (_highlight != null &&
              (notification is ScrollUpdateNotification ||
                  notification is ScrollStartNotification)) {
            // Notifications arrive after layout; clear on the next frame.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _highlight != null) {
                setState(() => _highlight = null);
              }
            });
            WidgetsBinding.instance.ensureVisualUpdate();
          }
          return false;
        },
        child: Stack(
          key: _surfaceKey,
          fit: StackFit.expand,
          children: [
            KeyedSubtree(key: _contentKey, child: widget.child),
            if (_highlight case final rect?)
              Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: Semantics(
                    liveRegion: true,
                    label: widget.request!.label,
                    child: DecoratedBox(
                      key: ValueKey(
                        'settings_highlight_${widget.request!.targetKey}',
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchScope extends InheritedWidget {
  const _SearchScope({
    required this.state,
    required this.request,
    required super.child,
  });
  final _SettingsSearchDestinationState state;
  final SettingsSearchRequest? request;
  @override
  bool updateShouldNotify(_SearchScope oldWidget) =>
      oldWidget.request != request;
}

/// Finite forms mount offscreen controls. Remote profiles/logs stay lazy.
class SettingsSectionBody extends StatelessWidget {
  const SettingsSectionBody({super.key, required this.children, this.padding});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    SettingsSearchDestination.contentReady(context);
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
