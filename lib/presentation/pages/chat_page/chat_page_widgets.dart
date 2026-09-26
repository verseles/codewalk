part of '../chat_page.dart';

class _ComposerStatusLanternText extends StatefulWidget {
  const _ComposerStatusLanternText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.repeat = true,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool repeat;

  @override
  State<_ComposerStatusLanternText> createState() =>
      _ComposerStatusLanternTextState();
}

class _ComposerStatusLanternTextState extends State<_ComposerStatusLanternText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Rest between sweep cycles: the ticker stays stopped while the status
  /// text is static, cutting GPU duty cycle during long busy waits.
  static const _sweepRest = Duration(milliseconds: 2500);
  Timer? _restTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    _controller.addStatusListener(_handleAnimationStatus);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    // One-shot path (repeat: false) must not loop; the completed frame stays.
    if (!widget.repeat || !mounted) {
      return;
    }
    _cancelRest();
    _restTimer = Timer(_sweepRest, () {
      _restTimer = null;
      if (mounted) {
        _syncAnimationState();
      }
    });
  }

  void _cancelRest() {
    _restTimer?.cancel();
    _restTimer = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant _ComposerStatusLanternText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repeat != widget.repeat || oldWidget.text != widget.text) {
      _syncAnimationState(restart: true);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    _cancelRest();
    _controller.dispose();
    super.dispose();
  }

  bool _animationsEnabled(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery?.disableAnimations ?? false) {
      return false;
    }
    return !WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
  }

  void _syncAnimationState({bool restart = false}) {
    if (!_animationsEnabled(context)) {
      _cancelRest();
      if (_controller.isAnimating) {
        _controller.stop();
      }
      if (_controller.value != 0) {
        _controller.value = 0;
      }
      return;
    }
    if (widget.repeat) {
      if (restart) {
        _cancelRest();
        _controller.forward(from: 0);
        return;
      }
      if (!_controller.isAnimating && _restTimer?.isActive != true) {
        _controller.forward(
          from: _controller.value >= 1.0 ? 0.0 : _controller.value,
        );
      }
      return;
    }
    _cancelRest();
    if (restart || _controller.status == AnimationStatus.completed) {
      _controller.stop();
      _controller.forward(from: 0);
      return;
    }
    if (!_controller.isAnimating &&
        _controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style;
    final textWidget = Text(
      widget.text,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      style: textStyle,
    );

    if (!_animationsEnabled(context)) {
      return textWidget;
    }

    if (!widget.repeat &&
        !_controller.isAnimating &&
        _controller.status == AnimationStatus.completed) {
      return textWidget;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = textStyle?.color ?? colorScheme.onSurfaceVariant;
    final dimColor = baseColor.withValues(alpha: 0.72);
    final highlightColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.35),
      baseColor,
    );

    // Isolate the per-frame shader repaints to this text's own layer so the
    // sweep never dirties the parent composer/sidebar on animation ticks.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: textWidget,
        builder: (context, child) {
          final rawCenter = (_controller.value * 1.8) - 0.4;
          final left = (rawCenter - 0.16).clamp(0.0, 1.0);
          final innerLeft = (rawCenter - 0.06).clamp(0.0, 1.0);
          final center = rawCenter.clamp(0.0, 1.0);
          final innerRight = (rawCenter + 0.06).clamp(0.0, 1.0);
          final right = (rawCenter + 0.16).clamp(0.0, 1.0);

          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  dimColor,
                  dimColor,
                  baseColor,
                  highlightColor,
                  baseColor,
                  dimColor,
                  dimColor,
                ],
                stops: [0.0, left, innerLeft, center, innerRight, right, 1.0],
              ).createShader(bounds);
            },
            child: child,
          );
        },
      ),
    );
  }
}

class _DirectoryPickerSheet extends StatefulWidget {
  const _DirectoryPickerSheet({required this.initialDirectory});

  final String initialDirectory;

  @override
  State<_DirectoryPickerSheet> createState() => _DirectoryPickerSheetState();
}

class _DirectoryPickerSheetState extends State<_DirectoryPickerSheet> {
  late String _currentDirectory;
  final TextEditingController _filterController = TextEditingController();
  List<String> _directories = const <String>[];
  bool _loading = false;
  String? _error;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _currentDirectory = _normalizeDirectory(widget.initialDirectory);
    _loadDirectory(_currentDirectory);
    _filterController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory(String directory) async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });

    final provider = context.read<ProjectProvider>();
    final listed = await provider.listDirectories(directory);

    if (!mounted || generation != _requestGeneration) {
      return;
    }

    if (listed == null) {
      setState(() {
        _loading = false;
        _error = provider.error ?? context.l10n.chatFailedToLoadDirectories;
      });
      return;
    }

    setState(() {
      _currentDirectory = _normalizeDirectory(directory);
      _directories = listed;
      _loading = false;
      _error = null;
    });
  }

  String _normalizeDirectory(String input) {
    return normalizeOptionalFilePath(input) ?? '/';
  }

  String _basename(String path) {
    return fileBasename(_normalizeDirectory(path));
  }

  String? _parentDirectory(String path) {
    final normalized = _normalizeDirectory(path).replaceAll('\\', '/');
    if (normalized == '/' || RegExp(r'^[A-Za-z]:/$').hasMatch(normalized)) {
      return null;
    }
    return parentFilePath(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final query = _filterController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _directories
        : _directories
              .where((item) {
                final base = _basename(item).toLowerCase();
                return projectDirectoryMatchScore(base, query) != null ||
                    projectDirectoryMatchScore(item, query) != null;
              })
              .toList(growable: false);
    final parent = _parentDirectory(_currentDirectory);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        key: const ValueKey<String>('directory_picker_sheet'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.chatSelectDirectory,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  key: const ValueKey<String>('directory_picker_use_current'),
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pop(_currentDirectory),
                  child: Text(context.l10n.chatCurrent),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _currentDirectory,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Symbols.info,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.chatChooseFolderOpen,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              key: const ValueKey<String>('directory_picker_filter'),
              controller: _filterController,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Symbols.search),
                hintText: context.l10n.chatFilterDirectories,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: AppIndeterminateRing())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: () => _loadDirectory(_currentDirectory),
                            child: Text(context.l10n.chatRetry2),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      if (parent != null)
                        ListTile(
                          key: const ValueKey<String>(
                            'directory_picker_parent',
                          ),
                          leading: const Icon(Symbols.arrow_upward_rounded),
                          title: const Text('..'),
                          subtitle: Text(parent),
                          onTap: () => _loadDirectory(parent),
                        ),
                      for (final directory in filtered)
                        ListTile(
                          key: ValueKey<String>(
                            'directory_picker_item_$directory',
                          ),
                          leading: const Icon(Symbols.folder),
                          title: Text(_basename(directory)),
                          subtitle: Text(
                            directory,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _loadDirectory(directory),
                          onLongPress: () => Navigator.of(
                            context,
                          ).pop(_normalizeDirectory(directory)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
