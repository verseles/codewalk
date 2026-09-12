import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../domain/entities/quota.dart';
import 'quota_entry_row.dart';

class QuotaProviderGroupRow extends StatefulWidget {
  const QuotaProviderGroupRow({super.key, required this.group});

  final QuotaProviderGroup group;

  @override
  State<QuotaProviderGroupRow> createState() => _QuotaProviderGroupRowState();
}

class _QuotaProviderGroupRowState extends State<QuotaProviderGroupRow> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.group.providerId == 'codex';
  }

  @override
  void didUpdateWidget(covariant QuotaProviderGroupRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.providerId != widget.group.providerId) {
      _expanded = widget.group.providerId == 'codex';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.group.canExpand) {
      if (widget.group.providerId == 'codex') {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.group.providerName,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              for (final entry in widget.group.entries)
                QuotaEntryRow(entry: entry, dense: true),
            ],
          ),
        );
      }
      return QuotaEntryRow(entry: widget.group.entries.first);
    }

    final summaryEntry = widget.group.leadingEntry;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: widget.group.providerName,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Symbols.expand_more : Symbols.chevron_right,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          widget.group.providerName,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: QuotaEntryRow(entry: summaryEntry, dense: true),
            ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.group.entries
                    .map((entry) => QuotaEntryRow(entry: entry, dense: true))
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}
