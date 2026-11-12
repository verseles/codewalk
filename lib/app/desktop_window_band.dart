import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../features/sessions/session_tab_strip.dart';
import '../shared/l10n/l10n_context.dart';
import 'desktop_window_controller.dart';

/// The top of the Linux window when it replaces the system title bar: the
/// session tabs when the workspace shows them, a free area that drags the
/// window and maximizes or restores it on a double click, and the window's
/// minimize, maximize and close.
///
/// The free area lies behind the tabs rather than around them, so the tabs'
/// own taps, menus and double tap keep working and never wait for a double
/// click.
class DesktopWindowBand extends StatelessWidget {
  const DesktopWindowBand({super.key, required this.window, this.strip});

  final DesktopWindowController window;
  final Widget? strip;

  /// The free band a full strip still leaves, so the window can always be
  /// dragged and maximized.
  static const dragReserve = 48.0;

  /// [page] under the band while [window] shows it, else [page] alone.
  static Widget over(DesktopWindowController? window, Widget page) =>
      window == null || !window.active
      ? page
      : Column(
          children: [
            DesktopWindowBand(window: window),
            Expanded(child: page),
          ],
        );

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final strip = this.strip;
    return Material(
      key: const ValueKey('desktop-window-band'),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SizedBox(
        height: sessionTabStripHeight(context),
        // The controls keep the right edge, as the system title bar does,
        // in every language.
        child: Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      key: const ValueKey('desktop-window-drag'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => window.startDragging(),
                      onDoubleTap: window.toggleMaximize,
                    ),
                  ),
                  if (strip != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: dragReserve,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: strip,
                      ),
                    ),
                ],
              ),
            ),
            _WindowButton(
              key: const ValueKey('desktop-window-minimize'),
              icon: Symbols.remove,
              tooltip: l10n.desktopWindowMinimize,
              onPressed: window.minimize,
            ),
            ValueListenableBuilder(
              valueListenable: window.maximized,
              builder: (context, maximized, _) => _WindowButton(
                key: const ValueKey('desktop-window-maximize'),
                icon: maximized ? Symbols.filter_none : Symbols.crop_square,
                tooltip: maximized
                    ? l10n.desktopWindowRestore
                    : l10n.desktopWindowMaximize,
                onPressed: window.toggleMaximize,
              ),
            ),
            _WindowButton(
              key: const ValueKey('desktop-window-close'),
              icon: Symbols.close,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => unawaited(window.requestClose()),
              close: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.close = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool close;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    child: IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        shape: const RoundedRectangleBorder(),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        hoverColor: close
            ? Theme.of(context).colorScheme.error.withValues(alpha: .16)
            : null,
      ),
      onPressed: onPressed,
    ),
  );
}
