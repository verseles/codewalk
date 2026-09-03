import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Direct-subscription counterparts to [Consumer]/`Selector`.
///
/// The provider package's InheritedWidget propagation does not rebuild
/// dependents in Android release builds on some devices (notifications fire
/// and frames run, but `Consumer`/`Selector` builders never re-run), while
/// direct [Listenable.addListener] subscriptions keep working. These widgets
/// subscribe directly and therefore stay live in release.
///
/// Prefer the standard provider widgets; use these only where live updates
/// are required in Android release builds.
class DirectConsumer<T extends Listenable> extends StatefulWidget {
  const DirectConsumer({super.key, required this.builder, this.child});

  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;

  @override
  State<DirectConsumer<T>> createState() => _DirectConsumerState<T>();
}

class _DirectConsumerState<T extends Listenable>
    extends State<DirectConsumer<T>> {
  late final T _value = context.read<T>();

  @override
  void initState() {
    super.initState();
    _value.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _value.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _value, widget.child);
  }
}

/// Direct-subscription counterpart to `Selector` with equality filtering.
///
/// Rebuilds only when [select] returns a value different (`!=`) from the
/// previous one, mirroring `Selector` semantics without InheritedWidget
/// dependency propagation.
class DirectSelector<T extends Listenable, S> extends StatefulWidget {
  const DirectSelector({
    super.key,
    required this.select,
    required this.builder,
    this.child,
  });

  final S Function(T value) select;
  final Widget Function(BuildContext context, S selected, Widget? child)
  builder;
  final Widget? child;

  @override
  State<DirectSelector<T, S>> createState() => _DirectSelectorState<T, S>();
}

class _DirectSelectorState<T extends Listenable, S>
    extends State<DirectSelector<T, S>> {
  late final T _value = context.read<T>();
  late S _selected = widget.select(_value);

  @override
  void initState() {
    super.initState();
    _value.addListener(_onChanged);
  }

  void _onChanged() {
    final next = widget.select(_value);
    if (next != _selected && mounted) {
      setState(() {
        _selected = next;
      });
    }
  }

  @override
  void dispose() {
    _value.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _selected, widget.child);
  }
}
