import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';

/// A select field's options in a dialog with a local search box.
///
/// Returns the chosen value, or null when dismissed.
Future<T?> showSearchablePicker<T extends Object>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  T? selected,
}) => showDialog<T>(
  context: context,
  builder: (context) =>
      _SearchablePicker<T>(title: title, options: options, selected: selected),
);

/// A select field that opens [showSearchablePicker] instead of a dropdown.
class SearchablePickerField<T extends Object> extends StatelessWidget {
  const SearchablePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return InkWell(
      onTap: onChanged == null
          ? null
          : () async {
              final next = await showSearchablePicker<T>(
                context,
                title: label,
                options: options,
                selected: value,
              );
              if (next != null && next != value) onChanged(next);
            },
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          enabled: onChanged != null,
        ),
        child: Text(
          options[value] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SearchablePicker<T extends Object> extends StatefulWidget {
  const _SearchablePicker({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final Map<T, String> options;
  final T? selected;

  @override
  State<_SearchablePicker<T>> createState() => _SearchablePickerState<T>();
}

class _SearchablePickerState<T extends Object>
    extends State<_SearchablePicker<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    final query = _query.trim().toLowerCase();
    final matches = [
      for (final option in widget.options.entries)
        if (option.value.toLowerCase().contains(query)) option,
    ];
    final media = MediaQuery.of(context);
    // Title, search and Cancel take about 220 px; the list gets what the
    // keyboard leaves, and the dialog scrolls when even that is too little.
    final listHeight = (media.size.height - media.viewInsets.bottom - 220)
        .clamp(48.0, 320.0);
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('searchable_picker_search'),
              autofocus: true,
              decoration: InputDecoration(
                labelText: l.searchableDropdownSearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            SizedBox(
              height: listHeight,
              child: matches.isEmpty
                  ? Center(child: Text(l.searchableDropdownEmptyText))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final option = matches[index];
                        return ListTile(
                          key: ValueKey((
                            'searchable_picker_option',
                            option.key,
                          )),
                          title: Text(option.value),
                          selected: option.key == widget.selected,
                          trailing: option.key == widget.selected
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(context, option.key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
      ],
    );
  }
}
