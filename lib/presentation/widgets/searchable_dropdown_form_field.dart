import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_shapes.dart';

typedef SearchableDropdownSearchTermsBuilder<T> =
    Iterable<String> Function(T value);

class SearchableDropdownFormField<T> extends FormField<T> {
  SearchableDropdownFormField({
    super.key,
    required this.items,
    this.value,
    T? initialValue,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.hint,
    this.isExpanded = false,
    this.searchHintText,
    this.emptyText,
    this.searchTermsBuilder,
  }) : fieldInitialValue = initialValue,
       super(
         initialValue: value ?? initialValue,
         enabled: onChanged != null,
         builder: (field) {
           final state = field as _SearchableDropdownFormFieldState<T>;
           return state.buildField(field.context);
         },
       );

  final List<DropdownMenuItem<T>> items;
  final T? value;
  final T? fieldInitialValue;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final Widget? hint;
  final bool isExpanded;
  final String? searchHintText;
  final String? emptyText;
  final SearchableDropdownSearchTermsBuilder<T>? searchTermsBuilder;

  T? get _effectiveInitialValue => value ?? fieldInitialValue;

  @override
  FormFieldState<T> createState() => _SearchableDropdownFormFieldState<T>();
}

class _SearchableDropdownFormFieldState<T> extends FormFieldState<T> {
  SearchableDropdownFormField<T> get _widget =>
      widget as SearchableDropdownFormField<T>;

  @override
  void didUpdateWidget(covariant SearchableDropdownFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = _widget._effectiveInitialValue;
    final previousValue = oldWidget._effectiveInitialValue;
    if (nextValue != previousValue && nextValue != value) {
      setValue(nextValue);
    }
  }

  Widget buildField(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveDecoration = _widget.decoration
        .applyDefaults(theme.inputDecorationTheme)
        .copyWith(errorText: errorText, enabled: _widget.onChanged != null);
    final selectedItem = _selectedItem;
    final hasSelection = selectedItem != null;

    return Semantics(
      button: true,
      enabled: _widget.onChanged != null,
      child: InkWell(
        borderRadius: AppShapes.borderLarge,
        onTap: _widget.onChanged == null ? null : () => _openPicker(context),
        child: InputDecorator(
          decoration: effectiveDecoration,
          isEmpty: !hasSelection,
          isFocused: false,
          child: Row(
            children: [
              _widget.isExpanded
                  ? Expanded(
                      child: hasSelection
                          ? DefaultTextStyle.merge(
                              overflow: TextOverflow.ellipsis,
                              child: selectedItem.child,
                            )
                          : (_widget.hint ?? const SizedBox.shrink()),
                    )
                  : Flexible(
                      fit: FlexFit.loose,
                      child: hasSelection
                          ? DefaultTextStyle.merge(
                              overflow: TextOverflow.ellipsis,
                              child: selectedItem.child,
                            )
                          : (_widget.hint ?? const SizedBox.shrink()),
                    ),
              const SizedBox(width: 12),
              Icon(
                Symbols.search_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Icon(
                Symbols.arrow_drop_down_rounded,
                size: 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  DropdownMenuItem<T>? get _selectedItem {
    final currentValue = value;
    for (final item in _widget.items) {
      if (item.value == currentValue) {
        return item;
      }
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final searchHintText =
        _widget.searchHintText ??
        l10n?.searchableDropdownSearchHint ??
        'Search';
    final emptyText =
        _widget.emptyText ??
        l10n?.searchableDropdownEmptyText ??
        'No matches found';
    final selectedValue = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return _SearchableDropdownSheet<T>(
          items: _widget.items,
          selectedValue: value,
          searchHintText: searchHintText,
          emptyText: emptyText,
          searchTermsBuilder: _widget.searchTermsBuilder,
        );
      },
    );
    if (!mounted || selectedValue == null || selectedValue == value) {
      return;
    }
    didChange(selectedValue);
    _widget.onChanged?.call(selectedValue);
  }
}

class _SearchableDropdownSheet<T> extends StatefulWidget {
  const _SearchableDropdownSheet({
    required this.items,
    required this.selectedValue,
    required this.searchHintText,
    required this.emptyText,
    required this.searchTermsBuilder,
  });

  final List<DropdownMenuItem<T>> items;
  final T? selectedValue;
  final String searchHintText;
  final String emptyText;
  final SearchableDropdownSearchTermsBuilder<T>? searchTermsBuilder;

  @override
  State<_SearchableDropdownSheet<T>> createState() =>
      _SearchableDropdownSheetState<T>();
}

class _SearchableDropdownSheetState<T>
    extends State<_SearchableDropdownSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final entries = widget.items
        .map(
          (item) => _SearchableDropdownEntry<T>(
            item: item,
            searchTerms: _searchTermsForItem(item),
          ),
        )
        .toList(growable: false);
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleEntries = normalizedQuery.isEmpty
        ? entries
        : entries
              .where(
                (entry) => entry.searchTerms.any(
                  (term) => term.toLowerCase().contains(normalizedQuery),
                ),
              )
              .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: widget.searchHintText,
                    prefixIcon: const Icon(Symbols.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: AppShapes.borderMedium,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: visibleEntries.isEmpty
                    ? Center(child: Text(widget.emptyText))
                    : ListView.builder(
                        itemCount: visibleEntries.length,
                        itemBuilder: (context, index) {
                          final entry = visibleEntries[index];
                          final isSelected =
                              entry.item.value == widget.selectedValue;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  Navigator.of(context).pop(entry.item.value),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      child: isSelected
                                          ? Icon(
                                              Symbols.check_rounded,
                                              size: 20,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DefaultTextStyle.merge(
                                        overflow: TextOverflow.ellipsis,
                                        child: entry.item.child,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _searchTermsForItem(DropdownMenuItem<T> item) {
    final value = item.value;
    if (value != null && widget.searchTermsBuilder != null) {
      return widget.searchTermsBuilder!(value)
          .where((term) => term.trim().isNotEmpty)
          .toList(growable: false);
    }
    final extracted = _extractText(item.child);
    if (extracted.isEmpty) {
      return const <String>[];
    }
    return <String>[extracted];
  }

  String _extractText(Widget? widget) {
    if (widget == null) {
      return '';
    }
    if (widget is Text) {
      return widget.data ?? widget.textSpan?.toPlainText() ?? '';
    }
    if (widget is RichText) {
      return widget.text.toPlainText();
    }
    if (widget is DefaultTextStyle) {
      return _extractText(widget.child);
    }
    if (widget is Tooltip) {
      return _extractText(widget.child);
    }
    if (widget is Padding) {
      return _extractText(widget.child);
    }
    if (widget is Align) {
      return _extractText(widget.child);
    }
    if (widget is Center) {
      return _extractText(widget.child);
    }
    if (widget is SizedBox) {
      return _extractText(widget.child);
    }
    if (widget is Flexible) {
      return _extractText(widget.child);
    }
    if (widget is Expanded) {
      return _extractText(widget.child);
    }
    if (widget is DecoratedBox) {
      return _extractText(widget.child);
    }
    if (widget is ColoredBox) {
      return _extractText(widget.child);
    }
    if (widget is Row) {
      return widget.children
          .map(_extractText)
          .where((text) => text.isNotEmpty)
          .join(' ');
    }
    if (widget is Column) {
      return widget.children
          .map(_extractText)
          .where((text) => text.isNotEmpty)
          .join(' ');
    }
    if (widget is Wrap) {
      return widget.children
          .map(_extractText)
          .where((text) => text.isNotEmpty)
          .join(' ');
    }
    return '';
  }
}

class _SearchableDropdownEntry<T> {
  const _SearchableDropdownEntry({
    required this.item,
    required this.searchTerms,
  });

  final DropdownMenuItem<T> item;
  final List<String> searchTerms;
}
