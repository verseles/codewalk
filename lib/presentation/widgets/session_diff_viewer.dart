import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show highlight;
import 'package:material_symbols_icons/symbols.dart';

import '../../core/i18n/l10n_context.dart';
import '../../domain/entities/chat_session.dart';
import '../theme/opencode_highlight_theme.dart';
import '../theme/opencode_theme_presets.dart';
import '../utils/diff_parser.dart';

/// View mode for the diff review surface.
enum DiffViewMode {
  /// Compact summary with file list and stats only.
  summary,

  /// Unified (inline) diff — single column with +/- lines.
  unified,

  /// Split (stacked) diff — old and new side-by-side on wide viewports,
  /// falls back to stacked on mobile.
  split,
}

class SessionDiffViewer extends StatefulWidget {
  const SessionDiffViewer({
    super.key,
    required this.diffs,
    this.compact = false,
    this.initiallyExpanded = true,
    this.title,
    this.onFileTap,
    this.initialMode,
  });

  final List<SessionDiff> diffs;
  final bool compact;
  final bool initiallyExpanded;
  final String? title;

  /// Called when the user taps a file path to navigate to the file viewer.
  /// Receives the file path (e.g. 'lib/main.dart') and optional line number.
  final void Function(String filePath, int? lineNumber)? onFileTap;

  /// Initial view mode; defaults to [DiffViewMode.unified].
  final DiffViewMode? initialMode;

  @override
  State<SessionDiffViewer> createState() => _SessionDiffViewerState();
}

class _SessionDiffViewerState extends State<SessionDiffViewer> {
  late bool _expanded;
  int _selectedIndex = 0;
  String? _selectedFile;
  late DiffViewMode _viewMode;

  /// Per-hunk collapse state keyed by file and hunk identity.
  final Map<String, bool> _hunkExpandedByKey = <String, bool>{};

  /// Cached highlight theme to avoid rebuilding on every line.
  Map<String, TextStyle>? _cachedHighlightTheme;
  String? _cachedThemeKey;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _viewMode = widget.initialMode ?? DiffViewMode.unified;
    _selectedFile = widget.diffs.isEmpty ? null : widget.diffs.first.file;
  }

  @override
  void didUpdateWidget(covariant SessionDiffViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.diffs.isEmpty) {
      _selectedIndex = 0;
      _selectedFile = null;
      return;
    }
    final selectedFile = _selectedFile;
    final matchingIndex = selectedFile == null
        ? -1
        : widget.diffs.indexWhere((diff) => diff.file == selectedFile);
    if (matchingIndex >= 0) {
      _selectedIndex = matchingIndex;
    } else if (_selectedIndex >= widget.diffs.length) {
      _selectedIndex = widget.diffs.length - 1;
    }
    _selectedFile = widget.diffs[_selectedIndex].file;
    _pruneHunkStateForCurrentFiles();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.diffs.isEmpty) {
      return const SizedBox.shrink();
    }

    return widget.compact
        ? _buildCompactViewer(context)
        : _buildExpandedViewer(context);
  }

  // ── Compact viewer (unchanged layout, upgraded preview) ──────────────

  Widget _buildCompactViewer(BuildContext context) {
    final diff = widget.diffs[_selectedIndex];
    return ExpansionTile(
      key: const ValueKey<String>('session_diff_viewer_compact_tile'),
      initiallyExpanded: _expanded,
      onExpansionChanged: (value) => setState(() => _expanded = value),
      leading: const Icon(Symbols.preview),
      title: Text(widget.title ?? context.l10n.sessionDiffReview),
      subtitle: Text(context.l10n.sessionDiffFilesChanged(widget.diffs.length)),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        _buildDiffFileDropdown(context),
        const SizedBox(height: 12),
        _buildDiffSummary(context, diff),
        const SizedBox(height: 12),
        SizedBox(height: 220, child: _buildDiffPreview(context, diff)),
      ],
    );
  }

  // ── Expanded viewer with mode toggle ─────────────────────────────────

  Widget _buildExpandedViewer(BuildContext context) {
    final diff = widget.diffs[_selectedIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplitLayout = constraints.maxWidth >= 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: title + file count + view mode toggle
            Row(
              children: [
                const Icon(Symbols.preview, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title ?? context.l10n.sessionDiffReview,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _buildViewModeToggle(context),
                const SizedBox(width: 8),
                Text(
                  context.l10n.sessionDiffFilesChanged(widget.diffs.length),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (useSplitLayout)
              SizedBox(
                height: 320,
                child: Row(
                  children: [
                    SizedBox(width: 200, child: _buildDiffFileTree(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDiffSummary(context, diff),
                          const SizedBox(height: 12),
                          Expanded(child: _buildDiffPreview(context, diff)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              _buildDiffFileDropdown(context),
              const SizedBox(height: 12),
              _buildDiffSummary(context, diff),
              const SizedBox(height: 12),
              SizedBox(height: 280, child: _buildDiffPreview(context, diff)),
            ],
          ],
        );
      },
    );
  }

  // ── View mode toggle ─────────────────────────────────────────────────

  Widget _buildViewModeToggle(BuildContext context) {
    final segments = <Widget>[
      _buildModeChip(
        context: context,
        mode: DiffViewMode.summary,
        icon: Symbols.list,
        tooltip: context.l10n.sessionDiffSummary,
      ),
      _buildModeChip(
        context: context,
        mode: DiffViewMode.unified,
        icon: Symbols.vertical_align_center,
        tooltip: context.l10n.sessionDiffUnified,
      ),
      _buildModeChip(
        context: context,
        mode: DiffViewMode.split,
        icon: Symbols.vertical_split,
        tooltip: context.l10n.sessionDiffSplit,
      ),
    ];

    return Row(mainAxisSize: MainAxisSize.min, children: segments);
  }

  Widget _buildModeChip({
    required BuildContext context,
    required DiffViewMode mode,
    required IconData icon,
    required String tooltip,
  }) {
    final selected = _viewMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 36,
        height: 36,
        child: IconButton(
          onPressed: () => setState(() {
            _viewMode = mode;
          }),
          icon: Icon(icon, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: selected
                ? colorScheme.primaryContainer
                : Colors.transparent,
            foregroundColor: selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  // ── File-tree navigation (unchanged) ─────────────────────────────────

  Widget _buildDiffFileTree(BuildContext context) {
    try {
      final root = _buildDiffTreeNode(widget.diffs);
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          child: _buildTreeNodeWidget(context, root, depth: 0),
        ),
      );
    } catch (_) {
      return _buildDiffFileList(context);
    }
  }

  _DiffTreeNode _buildDiffTreeNode(List<SessionDiff> diffs) {
    final root = _DiffTreeNode(name: '', isDirectory: true);
    for (var i = 0; i < diffs.length; i += 1) {
      final segments = diffs[i].file.split('/');
      var node = root;
      for (var s = 0; s < segments.length; s += 1) {
        final segment = segments[s];
        final isFile = s == segments.length - 1;
        if (isFile) {
          node.children.add(
            _DiffTreeNode(name: segment, isDirectory: false, diffIndex: i),
          );
        } else {
          var child = node.children.where((c) => c.name == segment).firstOrNull;
          if (child == null) {
            child = _DiffTreeNode(name: segment, isDirectory: true);
            node.children.add(child);
          }
          node = child;
        }
      }
    }
    return _collapseSingleChildDirs(root);
  }

  _DiffTreeNode _collapseSingleChildDirs(_DiffTreeNode node) {
    final collapsedChildren = <_DiffTreeNode>[];
    for (final child in node.children) {
      final processed = _collapseSingleChildDirs(child);
      if (processed.isDirectory &&
          processed.children.length == 1 &&
          processed.children.first.isDirectory) {
        final merged = processed.children.first;
        collapsedChildren.add(
          _DiffTreeNode(
            name: '${processed.name}/${merged.name}',
            isDirectory: true,
            children: merged.children,
          ),
        );
      } else {
        collapsedChildren.add(processed);
      }
    }
    return _DiffTreeNode(
      name: node.name,
      isDirectory: node.isDirectory,
      diffIndex: node.diffIndex,
      children: collapsedChildren,
    );
  }

  Widget _buildTreeNodeWidget(
    BuildContext context,
    _DiffTreeNode node, {
    required int depth,
  }) {
    if (!node.isDirectory) {
      final selected = node.diffIndex == _selectedIndex;
      return ListTile(
        key: ValueKey<String>('session_diff_tree_file_${node.diffIndex}'),
        dense: true,
        contentPadding: EdgeInsets.only(left: 12.0 + depth * 16.0),
        selected: selected,
        leading: const Icon(Symbols.description, size: 18),
        title: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () {
          if (node.diffIndex != null) {
            setState(() {
              _selectDiffIndex(node.diffIndex!);
            });
          }
        },
      );
    }

    final hasOnlyFiles = node.children.every((c) => !c.isDirectory);
    return ExpansionTile(
      key: ValueKey<String>('session_diff_tree_dir_${node.name}_$depth'),
      initiallyExpanded: depth == 0 || hasOnlyFiles,
      tilePadding: EdgeInsets.only(left: 4.0 + depth * 16.0),
      childrenPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Symbols.folder, size: 18),
      title: Text(
        node.name.isEmpty ? '/' : '${node.name}/',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: [
        for (final child in node.children)
          _buildTreeNodeWidget(context, child, depth: depth + 1),
      ],
    );
  }

  Widget _buildDiffFileDropdown(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: const ValueKey<String>('session_diff_viewer_dropdown'),
      value: _selectedIndex,
      items: [
        for (var index = 0; index < widget.diffs.length; index += 1)
          DropdownMenuItem<int>(
            value: index,
            child: Text(
              widget.diffs[index].file,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _selectDiffIndex(value);
        });
      },
      decoration: InputDecoration(
        labelText: context.l10n.sessionDiffChangedFile,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildDiffFileList(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        itemCount: widget.diffs.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final diff = widget.diffs[index];
          final selected = index == _selectedIndex;
          return ListTile(
            key: ValueKey<String>('session_diff_file_$index'),
            dense: true,
            selected: selected,
            leading: const Icon(Symbols.description, size: 18),
            title: Text(
              diff.file,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('+${diff.additions} -${diff.deletions}'),
            onTap: () => setState(() => _selectDiffIndex(index)),
          );
        },
      ),
    );
  }

  // ── Summary chips ────────────────────────────────────────────────────

  Widget _buildDiffSummary(BuildContext context, SessionDiff diff) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSummaryChip(
          context,
          Symbols.description,
          diff.file,
          onTap: () => widget.onFileTap?.call(diff.file, null),
        ),
        _buildSummaryChip(context, Symbols.add, '+${diff.additions}'),
        _buildSummaryChip(context, Symbols.remove, '-${diff.deletions}'),
        if ((diff.status ?? '').trim().isNotEmpty)
          _buildSummaryChip(context, Symbols.info, diff.status!.trim()),
      ],
    );
  }

  Widget _buildSummaryChip(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );

    if (onTap == null) return chip;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: chip,
    );
  }

  // ── Diff preview (mode-aware) ────────────────────────────────────────

  Widget _buildDiffPreview(BuildContext context, SessionDiff diff) {
    // Prefer server-provided unified patch text (ADR-023: FileDiff.patch)
    final List<DiffLine> rawLines;
    final hasPatch = diff.patch != null && diff.patch!.trim().isNotEmpty;
    if (hasPatch) {
      rawLines = parseDiffLines(diff.patch!);
    } else {
      rawLines = computeDiffLines(diff.before, diff.after, diff.file);
    }

    // No meaningful diff content — show fallback
    if (rawLines.isEmpty ||
        (rawLines.length <= 3 &&
            rawLines.every(
              (l) =>
                  l.type == DiffLineType.metadata ||
                  l.type == DiffLineType.hunk,
            ))) {
      return _buildEmptyContentFallback(context, diff);
    }

    // Summary mode: show file list with stats only
    if (_viewMode == DiffViewMode.summary) {
      return _buildSummaryPreview(context, diff);
    }

    // Annotate line numbers for unified/split rendering
    final lines = annotateLineNumbers(rawLines);
    final hunks = groupIntoHunks(lines);

    // Decorated container shared by both unified and split
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _viewMode == DiffViewMode.split
            ? _buildSplitDiffView(context, diff, hunks)
            : _buildUnifiedDiffView(context, diff, hunks),
      ),
    );
  }

  // ── Summary preview (file stats only, no line-by-line) ───────────────

  Widget _buildSummaryPreview(BuildContext context, SessionDiff diff) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => widget.onFileTap?.call(diff.file, null),
              child: Row(
                children: [
                  Icon(
                    Symbols.description,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      diff.file,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: widget.onFileTap != null
                            ? theme.colorScheme.primary
                            : null,
                        decoration: widget.onFileTap != null
                            ? TextDecoration.underline
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatBadge(context, Colors.green, '+${diff.additions}'),
                const SizedBox(width: 8),
                _buildStatBadge(context, Colors.red, '-${diff.deletions}'),
                if ((diff.status ?? '').trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildStatBadge(context, Colors.orange, diff.status!.trim()),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, Color color, String text) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? color.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: brightness == Brightness.dark
              ? color.withValues(alpha: 0.9)
              : color.withValues(alpha: 0.8),
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // ── Unified (inline) diff view with line numbers and syntax ──────────

  Widget _buildUnifiedDiffView(
    BuildContext context,
    SessionDiff diff,
    List<DiffHunk> hunks,
  ) {
    final language = resolveDiffHighlightLanguage(diff.file);
    final highlightTheme = _getHighlightTheme(context);
    final monospaceStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.45);

    return ListView.builder(
      key: ValueKey<String>(
        'session_diff_preview_list_${_selectedIndex}_${diff.file}',
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: hunks.length,
      itemBuilder: (context, hunkIndex) {
        final hunk = hunks[hunkIndex];
        return _buildHunkSection(
          context: context,
          hunk: hunk,
          language: language,
          highlightTheme: highlightTheme,
          monospaceStyle: monospaceStyle,
          diff: diff,
        );
      },
    );
  }

  // ── Split (stacked) diff view ────────────────────────────────────────

  Widget _buildSplitDiffView(
    BuildContext context,
    SessionDiff diff,
    List<DiffHunk> hunks,
  ) {
    final language = resolveDiffHighlightLanguage(diff.file);
    final highlightTheme = _getHighlightTheme(context);
    final monospaceStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.45);

    return ListView.builder(
      key: ValueKey<String>(
        'session_diff_split_list_${_selectedIndex}_${diff.file}',
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: hunks.length,
      itemBuilder: (context, hunkIndex) {
        final hunk = hunks[hunkIndex];
        return _buildSplitHunkSection(
          context: context,
          hunk: hunk,
          language: language,
          highlightTheme: highlightTheme,
          monospaceStyle: monospaceStyle,
          diff: diff,
        );
      },
    );
  }

  // ── Hunk section (unified) with collapse/expand ──────────────────────

  Widget _buildHunkSection({
    required BuildContext context,
    required DiffHunk hunk,
    required String language,
    required Map<String, TextStyle> highlightTheme,
    required TextStyle? monospaceStyle,
    required SessionDiff diff,
  }) {
    final hunkKey = _hunkStateKey(diff, hunk);
    final isExpanded =
        _hunkExpandedByKey[hunkKey] ??
        (hunk.lineCount <= kDefaultCollapseThreshold);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hunk header — tappable to toggle collapse
        _buildHunkHeader(context, hunk, hunkKey, isExpanded, diff),
        if (isExpanded)
          for (var i = 0; i < hunk.lines.length; i++)
            _buildUnifiedDiffLine(
              context: context,
              line: hunk.lines[i],
              language: language,
              highlightTheme: highlightTheme,
              monospaceStyle: monospaceStyle,
            ),
        if (!isExpanded) _buildCollapsedHunkIndicator(context, hunk.lineCount),
      ],
    );
  }

  // ── Hunk section (split) with collapse/expand ────────────────────────

  Widget _buildSplitHunkSection({
    required BuildContext context,
    required DiffHunk hunk,
    required String language,
    required Map<String, TextStyle> highlightTheme,
    required TextStyle? monospaceStyle,
    required SessionDiff diff,
  }) {
    final hunkKey = _hunkStateKey(diff, hunk);
    final isExpanded =
        _hunkExpandedByKey[hunkKey] ??
        (hunk.lineCount <= kDefaultCollapseThreshold);

    // Split lines: pair removals with additions
    final pairs = _buildSplitPairs(hunk.lines);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHunkHeader(context, hunk, hunkKey, isExpanded, diff),
        if (isExpanded)
          for (final pair in pairs)
            _buildSplitDiffRow(
              context: context,
              pair: pair,
              language: language,
              highlightTheme: highlightTheme,
              monospaceStyle: monospaceStyle,
            ),
        if (!isExpanded) _buildCollapsedHunkIndicator(context, hunk.lineCount),
      ],
    );
  }

  /// Pair removals and additions for split view. Context lines appear in
  /// both columns. Unpaired removals show an empty right cell; unpaired
  /// additions show an empty left cell.
  List<_SplitPair> _buildSplitPairs(List<DiffLine> lines) {
    final pairs = <_SplitPair>[];
    final removes = <DiffLine>[];
    var removeIdx = 0;
    for (final line in lines) {
      if (line.type == DiffLineType.remove) {
        removes.add(line);
      } else if (line.type == DiffLineType.add) {
        if (removeIdx < removes.length) {
          pairs.add(_SplitPair(oldLine: removes[removeIdx++], newLine: line));
        } else {
          pairs.add(_SplitPair(oldLine: null, newLine: line));
        }
      } else {
        // Flush remaining unpaired removes
        while (removeIdx < removes.length) {
          pairs.add(_SplitPair(oldLine: removes[removeIdx++], newLine: null));
        }
        removes.clear();
        removeIdx = 0;
        pairs.add(_SplitPair(oldLine: line, newLine: line));
      }
    }
    // Flush trailing removes
    while (removeIdx < removes.length) {
      pairs.add(_SplitPair(oldLine: removes[removeIdx++], newLine: null));
    }
    return pairs;
  }

  // ── Hunk header ──────────────────────────────────────────────────────

  Widget _buildHunkHeader(
    BuildContext context,
    DiffHunk hunk,
    String hunkKey,
    bool isExpanded,
    SessionDiff diff,
  ) {
    final style = _lineStyle(context, DiffLineType.hunk);
    return GestureDetector(
      onTap: () => setState(() {
        _hunkExpandedByKey[hunkKey] = !isExpanded;
      }),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        color: style.backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Icon(
              isExpanded ? Symbols.expand_less : Symbols.expand_more,
              size: 14,
              color: style.textColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hunk.header.content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: style.textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.onFileTap != null && hunk.newStart > 0)
              InkWell(
                onTap: () => widget.onFileTap?.call(diff.file, hunk.newStart),
                child: Icon(
                  Symbols.arrow_outward,
                  size: 14,
                  color: style.textColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Collapsed hunk indicator ─────────────────────────────────────────

  Widget _buildCollapsedHunkIndicator(BuildContext context, int lineCount) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Text(
        context.l10n.sessionDiffLinesCollapsed(lineCount),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  // ── Single unified diff line with line numbers ───────────────────────

  Widget _buildUnifiedDiffLine({
    required BuildContext context,
    required DiffLine line,
    required String language,
    required Map<String, TextStyle> highlightTheme,
    required TextStyle? monospaceStyle,
  }) {
    final style = _lineStyle(context, line.type);
    const gutterWidth = 48.0;

    // Line number strings
    final oldNo = line.oldLineNo?.toString() ?? '';
    final newNo = line.newLineNo?.toString() ?? '';

    // Strip diff prefix for syntax highlighting
    final codeContent = _stripDiffPrefix(line);

    return Container(
      width: double.infinity,
      color: style.backgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Old line number gutter
          SizedBox(
            width: gutterWidth / 2,
            child: Text(
              oldNo,
              textAlign: TextAlign.right,
              style: monospaceStyle?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ),
          // New line number gutter
          SizedBox(
            width: gutterWidth / 2,
            child: Text(
              newNo,
              textAlign: TextAlign.right,
              style: monospaceStyle?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ),
          // Vertical separator
          Container(
            width: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
          // Diff prefix marker
          SizedBox(
            width: 16,
            child: Text(
              _diffPrefix(line.type),
              style: monospaceStyle?.copyWith(
                color: style.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Code content with optional syntax highlighting
          Expanded(
            child: _buildSyntaxLine(
              codeContent: codeContent,
              language: language,
              highlightTheme: highlightTheme,
              baseStyle:
                  monospaceStyle?.copyWith(color: style.textColor) ??
                  TextStyle(color: style.textColor, fontFamily: 'monospace'),
              lineType: line.type,
            ),
          ),
        ],
      ),
    );
  }

  // ── Split diff row ───────────────────────────────────────────────────

  Widget _buildSplitDiffRow({
    required BuildContext context,
    required _SplitPair pair,
    required String language,
    required Map<String, TextStyle> highlightTheme,
    required TextStyle? monospaceStyle,
  }) {
    const gutterWidth = 40.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left (old) side
          Expanded(
            child: _buildSplitCell(
              context: context,
              line: pair.oldLine,
              gutterWidth: gutterWidth,
              language: language,
              highlightTheme: highlightTheme,
              monospaceStyle: monospaceStyle,
              isOld: true,
            ),
          ),
          // Center divider
          Container(width: 1, color: Theme.of(context).dividerColor),
          // Right (new) side
          Expanded(
            child: _buildSplitCell(
              context: context,
              line: pair.newLine,
              gutterWidth: gutterWidth,
              language: language,
              highlightTheme: highlightTheme,
              monospaceStyle: monospaceStyle,
              isOld: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitCell({
    required BuildContext context,
    required DiffLine? line,
    required double gutterWidth,
    required String language,
    required Map<String, TextStyle> highlightTheme,
    required TextStyle? monospaceStyle,
    required bool isOld,
  }) {
    if (line == null) {
      // Empty cell for unpaired line
      final emptyBg = Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
      return Container(color: emptyBg);
    }

    final style = _lineStyle(context, line.type);
    final lineNo = isOld
        ? (line.oldLineNo?.toString() ?? '')
        : (line.newLineNo?.toString() ?? '');
    final codeContent = _stripDiffPrefix(line);

    return Container(
      color: style.backgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line number gutter
          SizedBox(
            width: gutterWidth,
            child: Text(
              lineNo,
              textAlign: TextAlign.right,
              style: monospaceStyle?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ),
          Container(
            width: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 4),
          // Diff prefix
          SizedBox(
            width: 14,
            child: Text(
              _diffPrefix(line.type),
              style: monospaceStyle?.copyWith(
                color: style.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Code content
          Expanded(
            child: _buildSyntaxLine(
              codeContent: codeContent,
              language: language,
              highlightTheme: highlightTheme,
              baseStyle:
                  monospaceStyle?.copyWith(color: style.textColor) ??
                  TextStyle(color: style.textColor, fontFamily: 'monospace'),
              lineType: line.type,
            ),
          ),
        ],
      ),
    );
  }

  // ── Syntax-highlighted line ──────────────────────────────────────────

  /// Renders a single line with syntax highlighting when possible.
  /// Falls back to plain monospace text for plaintext or on parse failure.
  Widget _buildSyntaxLine({
    required String codeContent,
    required String language,
    required Map<String, TextStyle> highlightTheme,
    required TextStyle baseStyle,
    required DiffLineType lineType,
  }) {
    if (language == 'plaintext' || codeContent.isEmpty) {
      return Text(codeContent, style: baseStyle);
    }

    try {
      final result = highlight.parse(codeContent, language: language);
      if (result.nodes == null || result.nodes!.isEmpty) {
        return Text(codeContent, style: baseStyle);
      }
      final spans = _convertNodes(result.nodes!, highlightTheme);
      return RichText(
        text: TextSpan(style: baseStyle, children: spans),
        softWrap: false,
        overflow: TextOverflow.clip,
      );
    } catch (_) {
      // Syntax highlight failed — fall back to plain text
      return Text(codeContent, style: baseStyle);
    }
  }

  /// Convert highlight.js AST nodes to TextSpan list (same logic as
  /// HighlightView._convert but returns a flat list for our RichText).
  List<TextSpan> _convertNodes(
    List<dynamic> nodes,
    Map<String, TextStyle> theme,
  ) {
    final spans = <TextSpan>[];
    var currentSpans = spans;
    final stack = <List<TextSpan>>[];

    void traverse(dynamic n) {
      // Node from highlight package
      final node = n as dynamic;
      final value = node.value as String?;
      final className = node.className as String?;
      final children = node.children as List<dynamic>?;

      if (value != null) {
        currentSpans.add(
          className != null
              ? TextSpan(text: value, style: theme[className])
              : TextSpan(text: value),
        );
      } else if (children != null) {
        final tmp = <TextSpan>[];
        currentSpans.add(TextSpan(children: tmp, style: theme[className]));
        stack.add(currentSpans);
        currentSpans = tmp;
        for (final child in children) {
          traverse(child);
        }
        currentSpans = stack.isNotEmpty ? stack.removeLast() : spans;
      }
    }

    for (final node in nodes) {
      traverse(node);
    }
    return spans;
  }

  // ── Highlight theme cache ────────────────────────────────────────────

  Map<String, TextStyle> _getHighlightTheme(BuildContext context) {
    final themeTokens =
        Theme.of(context).extension<OpenCodeThemeTokens>() ??
        classicThemeTokensFrom(Theme.of(context).colorScheme);
    if (_cachedHighlightTheme != null &&
        _cachedThemeKey == themeTokens.themeId) {
      return _cachedHighlightTheme!;
    }
    final style = TextStyle(
      fontFamily: 'monospace',
      color: themeTokens.textBase,
      backgroundColor: Colors.transparent,
      height: 1.45,
    );
    _cachedHighlightTheme = openCodeHighlightTheme(
      tokens: themeTokens,
      brightness: Theme.of(context).brightness,
      baseStyle: style,
    );
    _cachedThemeKey = themeTokens.themeId;
    return _cachedHighlightTheme!;
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Strip the diff prefix (+/-/space) from a line's content for syntax
  /// highlighting. The prefix is rendered separately.
  String _stripDiffPrefix(DiffLine line) {
    final content = line.content;
    return switch (line.type) {
      DiffLineType.add =>
        content.startsWith('+') ? content.substring(1) : content,
      DiffLineType.remove =>
        content.startsWith('-') ? content.substring(1) : content,
      DiffLineType.context =>
        content.startsWith(' ') ? content.substring(1) : content,
      _ => content,
    };
  }

  /// Returns the diff prefix character for display.
  String _diffPrefix(DiffLineType type) {
    return switch (type) {
      DiffLineType.add => '+',
      DiffLineType.remove => '-',
      _ => ' ',
    };
  }

  void _selectDiffIndex(int index) {
    _selectedIndex = index;
    _selectedFile = widget.diffs[index].file;
  }

  String _hunkStateKey(SessionDiff diff, DiffHunk hunk) {
    return '${diff.file}\n${hunk.header.content}\n'
        '${hunk.oldStart}:${hunk.oldCount}:${hunk.newStart}:${hunk.newCount}';
  }

  void _pruneHunkStateForCurrentFiles() {
    final filePrefixes = widget.diffs.map((diff) => '${diff.file}\n').toSet();
    _hunkExpandedByKey.removeWhere(
      (key, _) => !filePrefixes.any(key.startsWith),
    );
  }

  // ── Empty content fallback ───────────────────────────────────────────

  Widget _buildEmptyContentFallback(BuildContext context, SessionDiff diff) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.preview_off,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => widget.onFileTap?.call(diff.file, null),
              child: Text(
                diff.file,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.onFileTap != null
                      ? theme.colorScheme.primary
                      : null,
                  decoration: widget.onFileTap != null
                      ? TextDecoration.underline
                      : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.sessionDiffLinesAddedRemoved(
                diff.additions,
                diff.deletions,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.sessionDiffContentNotCaptured,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Line style colors ────────────────────────────────────────────────

  _DiffLineStyle _lineStyle(BuildContext context, DiffLineType type) {
    final brightness = Theme.of(context).brightness;
    return switch (type) {
      DiffLineType.add => _DiffLineStyle(
        textColor: brightness == Brightness.dark
            ? Colors.green.shade300
            : Colors.green.shade700,
        backgroundColor: brightness == Brightness.dark
            ? Colors.green.shade900.withValues(alpha: 0.28)
            : Colors.green.shade50,
      ),
      DiffLineType.remove => _DiffLineStyle(
        textColor: brightness == Brightness.dark
            ? Colors.red.shade300
            : Colors.red.shade700,
        backgroundColor: brightness == Brightness.dark
            ? Colors.red.shade900.withValues(alpha: 0.28)
            : Colors.red.shade50,
      ),
      DiffLineType.hunk => _DiffLineStyle(
        textColor: brightness == Brightness.dark
            ? Colors.amber.shade300
            : Colors.orange.shade800,
        backgroundColor: brightness == Brightness.dark
            ? Colors.amber.shade900.withValues(alpha: 0.22)
            : Colors.orange.shade50,
      ),
      DiffLineType.metadata => _DiffLineStyle(
        textColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      DiffLineType.context => _DiffLineStyle(
        textColor: Theme.of(context).colorScheme.onSurface,
      ),
    };
  }
}

class _DiffLineStyle {
  const _DiffLineStyle({required this.textColor, this.backgroundColor});

  final Color textColor;
  final Color? backgroundColor;
}

/// Tree node for the file-tree diff viewer navigation.
class _DiffTreeNode {
  _DiffTreeNode({
    required this.name,
    required this.isDirectory,
    this.diffIndex,
    List<_DiffTreeNode>? children,
  }) : children = children ?? [];

  final String name;
  final bool isDirectory;
  final int? diffIndex;
  final List<_DiffTreeNode> children;
}

/// Paired old/new lines for split diff view.
class _SplitPair {
  const _SplitPair({this.oldLine, this.newLine});

  /// Line from the old file (remove or context), or null for pure additions.
  final DiffLine? oldLine;

  /// Line from the new file (add or context), or null for pure removals.
  /// For context lines, both [oldLine] and [newLine] reference the same
  /// [DiffLine] object.
  final DiffLine? newLine;
}
