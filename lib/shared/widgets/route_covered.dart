import 'package:flutter/widgets.dart';

/// Whether something sits over [context]'s page: a route above its own, or,
/// since every app route lives in one shell, anything the root navigator
/// can pop (a picker, a dialog, a page pushed over the shell).
bool routeCovered(BuildContext context) {
  if (ModalRoute.isCurrentOf(context) == false) return true;
  final own = Navigator.maybeOf(context);
  final root = Navigator.maybeOf(context, rootNavigator: true);
  return own != null && root != null && !identical(own, root) && root.canPop();
}
