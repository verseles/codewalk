part of '../chat_page.dart';

extension _ChatPageFileViewer on _ChatPageState {
  static const int _maxHighlightedFileLength = 160000;
  static const int _maxEditableFileLength = 64 * 1024;

  String get _draftTooLargeSaveMessage => context.l10n.filesDraftTooLargeToSave;

  String get _dirtyCloseBlockedMessage =>
      context.l10n.filesSaveChangesBeforeClose;

  String get _dirtyPathMutationBlockedMessage =>
      context.l10n.filesSaveChangesBeforePathChange;

  String get _savingPathMutationBlockedMessage =>
      context.l10n.filesWaitForSaveBeforePathChange;

  String get _pathMutationInProgressMessage =>
      context.l10n.filesWaitForFileOperation;

  Widget _buildFileViewerPanel({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    double height = 250,
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(8, 0, 8, 8),
    VoidCallback? onStateChanged,
    VoidCallback? onContextAdded,
  }) {
    if (!fileState.tabSelection.hasOpenTabs) {
      return const SizedBox.shrink();
    }

    final activePath =
        fileState.tabSelection.activePath ??
        fileState.tabSelection.openPaths.first;
    final active =
        fileState.tabsByPath[activePath] ??
        const _FileTabViewState(
          status: _FileTabLoadStatus.loading,
          content: '',
        );
    final normalizedActivePath = _normalizeFilePath(activePath);
    final selectedLines =
        fileState.selectedLinesByPath[normalizedActivePath] ?? const <int>{};

    return Container(
      key: const ValueKey<String>('file_viewer_panel'),
      height: height,
      margin: margin,
      child: Card(
        child: Column(
          children: [
            _buildFileTabStrip(
              fileState: fileState,
              projectProvider: projectProvider,
              activePath: activePath,
              onStateChanged: onStateChanged,
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(
                builder: (_) {
                  switch (active.status) {
                    case _FileTabLoadStatus.loading:
                      return const Center(child: CircularProgressIndicator());
                    case _FileTabLoadStatus.error:
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                active.errorMessage ??
                                    context.l10n.chatFailedToLoadFile,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    case _FileTabLoadStatus.binary:
                      return Center(
                        child: Text(context.l10n.filesBinaryFilePreview),
                      );
                    case _FileTabLoadStatus.ready:
                      return _buildFileViewerContent(
                        path: activePath,
                        content: active.content,
                        mimeType: active.mimeType,
                        fileState: fileState,
                        projectProvider: projectProvider,
                        onStateChanged: onStateChanged,
                      );
                  }
                },
              ),
            ),
            // Selection actions and editor commands live below the editor so
            // the tab strip keeps the full header width (issue #167).
            if (selectedLines.isNotEmpty &&
                active.status == _FileTabLoadStatus.ready)
              _buildSelectionActionBar(
                fileState: fileState,
                path: activePath,
                content: _currentFileEditorText(
                  fileState: fileState,
                  path: activePath,
                  fallback: active.content,
                ),
                selectedCount: selectedLines.length,
                onStateChanged: onStateChanged,
                onContextAdded: onContextAdded,
              ),
            _buildFileViewerBottomBar(
              fileState: fileState,
              projectProvider: projectProvider,
              activePath: activePath,
              active: active,
              onStateChanged: onStateChanged,
            ),
          ],
        ),
      ),
    );
  }

  /// File tabs rendered with the shared [AppTabStrip] chrome used by session
  /// tabs (issue #167). Selection state stays owned by [FileTabSelectionState];
  /// this only maps open paths to [AppTab] view models.
  Widget _buildFileTabStrip({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String activePath,
    VoidCallback? onStateChanged,
  }) {
    final tabs = <AppTab<String>>[
      for (final path in fileState.tabSelection.openPaths)
        AppTab<String>(
          id: _normalizeFilePath(path),
          value: path,
          title: _fileBasename(path),
          tooltip: _normalizeFilePath(path),
          titleSuffix: _fileDraftIsDirty(fileState, path) ? '*' : null,
          titleSuffixKey: ValueKey<String>(
            'file_viewer_tab_dirty_${_normalizeFilePath(path)}',
          ),
          isSelected: path == activePath,
          canClose: true,
          canOpenContextMenu: false,
        ),
    ];
    return AppTabStrip<String>(
      tabs: tabs,
      isCompact: context.windowSizeClass.isCompact,
      keyPrefix: 'file_viewer_tab_',
      showTrailingOnUnselected: true,
      trailingExtentBuilder: (context, tab) => 28.0,
      leadingBuilder: (context, tab) => Center(
        child: Icon(_fileIconForPath(tab.value), size: 14),
      ),
      trailingBuilder: (context, tab) => Semantics(
        // Spoken label without a Tooltip: the dialog already exposes a
        // 'Close' tooltip and the two finders must stay unambiguous.
        label: context.l10n.chatClose,
        button: true,
        excludeSemantics: true,
        child: IconButton(
          key: ValueKey<String>('file_viewer_tab_close_${tab.id}'),
          visualDensity: Theme.of(context).visualDensity,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: const Icon(Symbols.close, size: 14),
          onPressed: () {
            _closeFileTab(
              fileState: fileState,
              path: tab.value,
              projectProvider: projectProvider,
              onUpdated: onStateChanged,
            );
          },
        ),
      ),
      onActivate: (tab) {
        _activateFileTab(
          fileState: fileState,
          path: tab.value,
          onUpdated: onStateChanged,
        );
      },
      onClose: (tab) {
        _closeFileTab(
          fileState: fileState,
          path: tab.value,
          projectProvider: projectProvider,
          onUpdated: onStateChanged,
        );
      },
    );
  }

  /// Editor commands below the content so the tab strip keeps the full header
  /// width on small screens (issue #167). Reuses [_buildFileViewerSaveAction]
  /// unchanged: same keys, same save/autosave/undo/redo gates.
  Widget _buildFileViewerBottomBar({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String activePath,
    required _FileTabViewState active,
    VoidCallback? onStateChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey<String>('file_viewer_bottom_bar'),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (active.status == _FileTabLoadStatus.error)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: OutlinedButton(
                    key: const ValueKey<String>('file_viewer_retry_button'),
                    onPressed: () {
                      unawaited(
                        _reloadFileTab(
                          fileState: fileState,
                          projectProvider: projectProvider,
                          path: activePath,
                          onUpdated: onStateChanged,
                        ),
                      );
                    },
                    child: Text(context.l10n.chatRetry2),
                  ),
                ),
              _buildFileViewerSaveAction(
                fileState: fileState,
                projectProvider: projectProvider,
                activePath: activePath,
                active: active,
                onStateChanged: onStateChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionActionBar({
    required _FileExplorerContextState fileState,
    required String path,
    required String content,
    required int selectedCount,
    VoidCallback? onStateChanged,
    VoidCallback? onContextAdded,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('file_viewer_selection_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          Icon(Symbols.check_box, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            context.l10n.filesLinesSelectedCount(selectedCount),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              _addSelectionToContext(
                fileState: fileState,
                path: path,
                content: content,
              );
              onStateChanged?.call();
              // Close dialog and focus composer after adding context.
              onContextAdded?.call();
            },
            icon: const Icon(Symbols.chat_bubble_outline, size: 16),
            label: Text(context.l10n.filesAddChat),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          TextButton(
            onPressed: () {
              final normalizedPath = _normalizeFilePath(path);
              _setState(() {
                fileState.selectedLinesByPath.remove(normalizedPath);
                fileState.lastSelectedLineByPath.remove(normalizedPath);
              });
              onStateChanged?.call();
            },
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(context.l10n.filesClear),
          ),
        ],
      ),
    );
  }

  Widget _buildFileViewerContent({
    required String path,
    required String content,
    String? mimeType,
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    VoidCallback? onStateChanged,
  }) {
    final normalizedPath = _normalizeFilePath(path);
    final draft = _editorDraftForContent(
      fileState: fileState,
      path: normalizedPath,
      content: content,
    );
    final readOnlyReason = _editorReadOnlyReason(
      path: normalizedPath,
      content: content,
      fileState: fileState,
    );
    final editor = _buildFocusedFileEditor(
      path: normalizedPath,
      content: content,
      draft: draft,
      language: _resolveHighlightLanguage(path: path, mimeType: mimeType),
      fileState: fileState,
      readOnly: readOnlyReason != null,
      readOnlyReason: readOnlyReason,
      canSave: _canSaveFileDraft(
        fileState: fileState,
        path: normalizedPath,
        draft: draft,
      ),
      onSave: () => unawaited(
        _saveFileEditorDraft(
          fileState: fileState,
          projectProvider: projectProvider,
          path: normalizedPath,
          onUpdated: onStateChanged,
        ),
      ),
      onChanged: () => onStateChanged?.call(),
      onLineSelectionChanged: onStateChanged,
    );

    // Schedule scroll-to-line after the first frame renders the content.
    final pendingLine = fileState.pendingScrollToLine;
    if (pendingLine != null) {
      fileState.pendingScrollToLine = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (fileState.editorDraftsByPath[normalizedPath] != draft) {
          return;
        }
        final lineIndex = max(0, pendingLine - 1);
        draft.scrollController.makeCenterIfInvisible(
          CodeLinePosition(index: lineIndex, offset: 0),
        );
      });
    }

    return KeyedSubtree(
      key: ValueKey<String>('file_viewer_scroll_$normalizedPath'),
      child: editor,
    );
  }

  _FileEditorDraftState _editorDraftForContent({
    required _FileExplorerContextState fileState,
    required String path,
    required String content,
  }) {
    final normalizedPath = _normalizeFilePath(path);
    final draft = fileState.editorDraftsByPath.putIfAbsent(
      normalizedPath,
      () => _FileEditorDraftState(content: content),
    );
    if (!draft.isDirty && draft.savedContent != content) {
      final nextLineBreak = _FileEditorDraftState._detectTextLineBreak(content);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final currentDraft = fileState.editorDraftsByPath[normalizedPath];
        if (currentDraft != draft ||
            draft.isDirty ||
            draft.savedContent == content) {
          return;
        }
        _setState(() {
          if (draft.lineBreak != nextLineBreak) {
            fileState.editorDraftsByPath[normalizedPath] =
                _FileEditorDraftState(content: content);
            draft.dispose();
          } else {
            draft.replaceSavedContent(content);
          }
        });
      });
    }
    return draft;
  }

  bool _fileDraftIsDirty(_FileExplorerContextState fileState, String path) {
    return fileState.editorDraftsByPath[_normalizeFilePath(path)]?.isDirty ==
        true;
  }

  Widget _buildFileViewerSaveAction({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required String activePath,
    required _FileTabViewState active,
    VoidCallback? onStateChanged,
  }) {
    final normalizedPath = _normalizeFilePath(activePath);
    final draft = fileState.editorDraftsByPath[normalizedPath];
    final canSave =
        active.status == _FileTabLoadStatus.ready &&
        draft != null &&
        _canSaveFileDraft(
          fileState: fileState,
          path: normalizedPath,
          draft: draft,
        );
    final isSaving = draft?.isSaving == true;
    final autosaveEnabled = context
        .watch<SettingsProvider>()
        .editorAutosaveEnabled;
    final controller = draft?.controller;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller != null) ...[
          IconButton(
            key: const ValueKey<String>('file_viewer_undo_button'),
            tooltip: context.l10n.filesUndo,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: controller.canUndo ? controller.undo : null,
            icon: const Icon(Symbols.undo),
          ),
          IconButton(
            key: const ValueKey<String>('file_viewer_redo_button'),
            tooltip: context.l10n.filesRedo,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: controller.canRedo ? controller.redo : null,
            icon: const Icon(Symbols.redo),
          ),
        ],
        // Autosave is global: flipping it here applies to every open tab and
        // is persisted with the rest of the experience settings.
        IconButton(
          key: const ValueKey<String>('file_viewer_autosave_toggle'),
          tooltip: autosaveEnabled
              ? context.l10n.filesAutosaveOn
              : context.l10n.filesAutosaveOff,
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          isSelected: autosaveEnabled,
          onPressed: () => unawaited(
            context.read<SettingsProvider>().setEditorAutosaveEnabled(
              !autosaveEnabled,
            ),
          ),
          icon: const Icon(Symbols.autorenew),
          selectedIcon: const Icon(Symbols.autorenew, fill: 1),
        ),
        _buildFileViewerSaveButton(
          canSave: canSave,
          isSaving: isSaving,
          onSave: () => unawaited(
            _saveFileEditorDraft(
              fileState: fileState,
              projectProvider: projectProvider,
              path: normalizedPath,
              onUpdated: onStateChanged,
            ),
          ),
        ),
      ],
    );
  }

  /// Debounce before an idle autosave fires.
  ///
  /// Deliberately long: autosave here exists to avoid losing work, not to
  /// mirror every keystroke to disk, so it waits for a real pause.
  static const Duration _autosaveIdleDelay = Duration(seconds: 30);

  /// Restarts the idle autosave countdown after an edit.
  void _scheduleEditorAutosave({
    required _FileEditorDraftState draft,
    required VoidCallback onSave,
  }) {
    draft.cancelAutosave();
    if (!context.read<SettingsProvider>().editorAutosaveEnabled) {
      return;
    }
    draft.autosaveTimer = Timer(_autosaveIdleDelay, () {
      draft.autosaveTimer = null;
      if (mounted &&
          context.read<SettingsProvider>().editorAutosaveEnabled &&
          draft.isDirty &&
          draft.activeSave == null) {
        onSave();
      }
    });
  }

  void _syncEditorAutosaveForActiveContext({required bool enabled}) {
    for (final fileState in _fileContextStates.values) {
      for (final draft in fileState.editorDraftsByPath.values) {
        draft.cancelAutosave();
        if (!enabled) {
          draft.pendingLifecycleFlushContent = null;
          draft.pendingLifecycleFlushAllowsInactiveContext = false;
        }
      }
    }
    if (!enabled) {
      return;
    }
    final projectProvider = _projectProvider;
    if (projectProvider == null) {
      return;
    }
    final fileState = _fileContextStates[projectProvider.contextKey];
    if (fileState == null) {
      return;
    }
    for (final entry in fileState.editorDraftsByPath.entries) {
      final draft = entry.value;
      if (!draft.isDirty || draft.activeSave != null) {
        continue;
      }
      _scheduleEditorAutosave(
        draft: draft,
        onSave: () => unawaited(
          _saveFileEditorDraft(
            fileState: fileState,
            projectProvider: projectProvider,
            path: entry.key,
            onUpdated: () {
              if (mounted) {
                _setState(() {});
              }
            },
          ),
        ),
      );
    }
  }

  void _flushActiveFileEditorDrafts() {
    if (_settingsProvider?.editorAutosaveEnabled != true) {
      return;
    }
    final projectProvider = _projectProvider;
    final activeServerId = _appProvider?.activeServerId;
    if (projectProvider == null || activeServerId == null) {
      return;
    }
    for (final fileState in _fileContextStates.values) {
      if (fileState.serverId != activeServerId) {
        continue;
      }
      _flushFileEditorContextState(
        fileState: fileState,
        projectProvider: projectProvider,
        allowInactiveContext: true,
      );
    }
  }

  void _flushFileEditorContext({
    required String contextKey,
    required bool allowInactiveContext,
  }) {
    final projectProvider = _projectProvider;
    final activeServerId = _appProvider?.activeServerId;
    final fileState = _fileContextStates[contextKey];
    if (projectProvider == null ||
        activeServerId == null ||
        fileState == null ||
        fileState.serverId != activeServerId) {
      return;
    }
    _flushFileEditorContextState(
      fileState: fileState,
      projectProvider: projectProvider,
      allowInactiveContext: allowInactiveContext,
    );
  }

  void _flushFileEditorContextState({
    required _FileExplorerContextState fileState,
    required ProjectProvider projectProvider,
    required bool allowInactiveContext,
  }) {
    for (final entry in fileState.editorDraftsByPath.entries) {
      final draft = entry.value;
      draft.cancelAutosave();
      if (!draft.isDirty) {
        continue;
      }
      if (draft.activeSave != null) {
        draft.pendingLifecycleFlushContent = draft.controller.text;
        draft.pendingLifecycleFlushAllowsInactiveContext = allowInactiveContext;
        continue;
      }
      unawaited(
        _saveFileEditorDraft(
          fileState: fileState,
          projectProvider: projectProvider,
          path: entry.key,
          allowInactiveContext: allowInactiveContext,
          silent: true,
        ),
      );
    }
  }

  /// Saves immediately instead of waiting for the countdown.
  ///
  /// Used when the editor loses focus and when a tab is closed, so pending
  /// work is never discarded with a timer still pending.
  void _flushEditorAutosave({
    required _FileEditorDraftState draft,
    required VoidCallback onSave,
  }) {
    draft.cancelAutosave();
    if (!mounted || !draft.isDirty || draft.activeSave != null) {
      return;
    }
    if (!context.read<SettingsProvider>().editorAutosaveEnabled) {
      return;
    }
    onSave();
  }

  Widget _buildFileViewerSaveButton({
    required bool canSave,
    required bool isSaving,
    required VoidCallback onSave,
  }) {
    return TextButton.icon(
      key: const ValueKey<String>('file_viewer_save_button'),
      onPressed: canSave ? onSave : null,
      icon: isSaving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Symbols.save, size: 18),
      label: Text(context.l10n.commonSave),
    );
  }

  bool _canSaveFileDraft({
    required _FileExplorerContextState fileState,
    required String path,
    required _FileEditorDraftState draft,
  }) {
    if (!draft.isDirty || draft.isSaving) {
      return false;
    }
    if (_isEditorContentTooLarge(draft.controller.text)) {
      return false;
    }
    return _editorReadOnlyReason(
          path: path,
          content: draft.savedContent,
          fileState: fileState,
        ) ==
        null;
  }

  String? _editorReadOnlyReason({
    required String path,
    required String content,
    required _FileExplorerContextState fileState,
  }) {
    if (_hasPendingFileTreeMutation(
      fileState,
      _fileTreePathAliases(fileState, path),
    )) {
      return _pathMutationInProgressMessage;
    }
    if (_isEditorContentTooLarge(content)) {
      return context.l10n.filesLargeFileReadOnly;
    }
    if (fileState.fileOperationCapabilitiesLoading) {
      return context.l10n.filesCheckingWriteSupport;
    }
    final capabilities = fileState.fileOperationCapabilities;
    if (capabilities?.shellFileOpsSupported != true) {
      final message = capabilities?.message.trim();
      return message == null || message.isEmpty
          ? context.l10n.filesOperationUnavailable
          : message;
    }
    return null;
  }

  bool _isEditorContentTooLarge(String content) {
    return utf8.encode(content).length > _maxEditableFileLength;
  }

  String _currentFileEditorText({
    required _FileExplorerContextState fileState,
    required String path,
    required String fallback,
  }) {
    return fileState
            .editorDraftsByPath[_normalizeFilePath(path)]
            ?.controller
            .text ??
        fallback;
  }

  Widget _buildFocusedFileEditor({
    required String path,
    required String content,
    required _FileEditorDraftState draft,
    required String language,
    required _FileExplorerContextState fileState,
    required bool readOnly,
    required String? readOnlyReason,
    required bool canSave,
    required VoidCallback onSave,
    VoidCallback? onChanged,
    VoidCallback? onLineSelectionChanged,
  }) {
    final normalizedPath = _normalizeFilePath(path);
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.4);
    final editor = CodeEditor(
      key: ValueKey<String>('file_editor_$path'),
      controller: draft.controller,
      scrollController: draft.scrollController,
      readOnly: readOnly,
      showCursorWhenReadOnly: false,
      toolbarController: fileEditorSelectionToolbarController(
        readOnly: readOnly,
      ),
      wordWrap: false,
      chunkAnalyzer: const NonCodeChunkAnalyzer(),
      onChanged: (_) {
        if (_isEditorContentTooLarge(draft.controller.text)) {
          draft.saveErrorMessage = _draftTooLargeSaveMessage;
        } else if (draft.saveErrorMessage != null) {
          draft.saveErrorMessage = null;
        }
        _scheduleEditorAutosave(draft: draft, onSave: onSave);
        onChanged?.call();
      },
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      indicatorBuilder:
          (context, editingController, chunkController, notifier) {
            final selectedLines =
                fileState.selectedLinesByPath[normalizedPath] ?? const <int>{};
            return DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                border: Border(
                  right: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Listener(
                key: ValueKey<String>('file_editor_gutter_$normalizedPath'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  final lineNumber = _lineNumberForEditorGutterTap(
                    controller: editingController,
                    notifier: notifier,
                    localPosition: event.localPosition,
                  );
                  if (lineNumber == null) {
                    return;
                  }
                  _handleGutterLineTap(
                    fileState: fileState,
                    path: normalizedPath,
                    lineNumber: lineNumber,
                    lineCount: editingController.lineCount,
                    isShiftHeld: HardwareKeyboard.instance.isShiftPressed,
                  );
                  onLineSelectionChanged?.call();
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _EditorLineSelectionPainter(
                          controller: editingController,
                          notifier: notifier,
                          selectedLines: selectedLines,
                          color: colorScheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: DefaultCodeLineNumber(
                        controller: editingController,
                        notifier: notifier,
                        textStyle: textStyle?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.55,
                          ),
                        ),
                        focusedTextStyle: textStyle?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
      style: CodeEditorStyle(
        fontSize: textStyle?.fontSize,
        fontFamily: 'monospace',
        fontHeight: 1.4,
        textColor: colorScheme.onSurface,
        backgroundColor: colorScheme.surface,
        selectionColor: colorScheme.primary.withValues(alpha: 0.20),
        highlightColor: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        cursorColor: colorScheme.primary,
        cursorLineColor: colorScheme.primary.withValues(alpha: 0.08),
        codeTheme: CodeHighlightTheme(
          languages: <String, CodeHighlightThemeMode>{
            language: CodeHighlightThemeMode(
              mode: _resolveEditorLanguageMode(language),
              maxSize: _maxHighlightedFileLength,
              maxLineLength: 20000,
            ),
          },
          theme: _resolveHighlightTheme(context),
        ),
      ),
    );
    final stack = Stack(
      children: [
        Positioned.fill(child: editor),
        if (readOnlyReason != null)
          Positioned(
            top: 8,
            right: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  readOnlyReason,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        if (draft.saveErrorMessage != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.error),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  draft.saveErrorMessage!,
                  key: ValueKey<String>('file_editor_save_error_$path'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ),
        if (content.length <= 10000)
          Positioned(
            width: 0,
            height: 0,
            child: Opacity(
              opacity: 0,
              child: ExcludeSemantics(child: Text(content)),
            ),
          ),
      ],
    );
    return Focus(
      key: ValueKey<String>('file_editor_focus_$normalizedPath'),
      onFocusChange: (hasFocus) {
        // Leaving the editor is an explicit pause, so any pending autosave is
        // written now instead of waiting out the countdown.
        if (!hasFocus) {
          _flushEditorAutosave(draft: draft, onSave: onSave);
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            if (canSave) {
              onSave();
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
            if (canSave) {
              onSave();
            }
          },
          // Keyboards with dedicated clipboard keys emit these instead of
          // Ctrl+V and friends, and re_editor only binds the Ctrl/Cmd
          // combinations, so the keyboard's own paste button did nothing
          // inside the editor while working everywhere else (#121).
          const SingleActivator(LogicalKeyboardKey.copy): () {
            unawaited(draft.controller.copy());
          },
          if (!readOnly) ...<ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.paste): () {
              draft.controller.paste();
            },
            const SingleActivator(LogicalKeyboardKey.cut): () {
              draft.controller.cut();
            },
          },
        },
        child: stack,
      ),
    );
  }

  /// Resolves the highlight mode for [language].
  ///
  /// Backed by the package's full language map rather than a hand-curated
  /// switch, so every language it ships with is available (#107). Unknown
  /// names fall back to plaintext, which stays readable instead of erroring.
  Mode _resolveEditorLanguageMode(String language) {
    return builtinAllLanguages[language] ?? builtinAllLanguages['plaintext']!;
  }

  int? _lineNumberForEditorGutterTap({
    required CodeLineEditingController controller,
    required CodeIndicatorValueNotifier notifier,
    required Offset localPosition,
  }) {
    final paragraphs = notifier.value?.paragraphs;
    if (paragraphs == null || paragraphs.isEmpty) {
      return null;
    }
    for (final paragraph in paragraphs) {
      if (localPosition.dy >= paragraph.top &&
          localPosition.dy < paragraph.bottom) {
        final lineNumber = controller.index2lineIndex(paragraph.index) + 1;
        if (lineNumber < 1 || lineNumber > controller.lineCount) {
          return null;
        }
        return lineNumber;
      }
    }
    return null;
  }

  // Toggle or range-select a line in the gutter.
  void _handleGutterLineTap({
    required _FileExplorerContextState fileState,
    required String path,
    required int lineNumber,
    required int lineCount,
    required bool isShiftHeld,
  }) {
    _setState(() {
      final selected = fileState.selectedLinesByPath.putIfAbsent(
        path,
        () => <int>{},
      );

      if (isShiftHeld) {
        final anchor = fileState.lastSelectedLineByPath[path] ?? lineNumber;
        final start = min(anchor, lineNumber);
        final end = max(anchor, lineNumber);
        for (var i = start; i <= end; i++) {
          if (i >= 1 && i <= lineCount) {
            selected.add(i);
          }
        }
      } else if (selected.contains(lineNumber)) {
        selected.remove(lineNumber);
      } else {
        selected.add(lineNumber);
      }

      fileState.lastSelectedLineByPath[path] = lineNumber;
    });
  }

  // Build FileInputParts from the selected lines and add to chat context.
  void _addSelectionToContext({
    required _FileExplorerContextState fileState,
    required String path,
    required String content,
  }) {
    final normalizedPath = _normalizeFilePath(path);
    final selected = fileState.selectedLinesByPath[normalizedPath];
    if (selected == null || selected.isEmpty) {
      return;
    }

    final lines = _splitFileEditorLines(content);
    final ranges = _groupContiguousRanges(selected);
    final basename = _fileBasename(path);

    _setState(() {
      for (final range in ranges) {
        final startLine = range.$1;
        final endLine = range.$2;
        final safeStart = (startLine - 1).clamp(0, lines.length);
        final safeEnd = endLine.clamp(0, lines.length);
        final selectedContent = lines.sublist(safeStart, safeEnd).join('\n');

        _fileContextItems.add(
          FileInputPart(
            mime: 'text/plain',
            url: 'file://$normalizedPath?start=$startLine&end=$endLine',
            filename: basename,
            source: FileInputSource(
              path: normalizedPath,
              text: FileInputSourceText(
                value: selectedContent,
                start: startLine,
                end: endLine,
              ),
              type: 'file',
            ),
          ),
        );
      }

      // Clear selection after adding to context.
      fileState.selectedLinesByPath.remove(normalizedPath);
      fileState.lastSelectedLineByPath.remove(normalizedPath);
    });
  }

  List<String> _splitFileEditorLines(String content) {
    return content.split(RegExp(r'\r\n|\r|\n'));
  }

  // Group a set of line numbers into contiguous (start, end) ranges.
  List<(int, int)> _groupContiguousRanges(Set<int> lineNumbers) {
    if (lineNumbers.isEmpty) {
      return const <(int, int)>[];
    }
    final sorted = lineNumbers.toList()..sort();
    final ranges = <(int, int)>[];
    var start = sorted.first;
    var end = start;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        ranges.add((start, end));
        start = sorted[i];
        end = start;
      }
    }
    ranges.add((start, end));
    return ranges;
  }

  Map<String, TextStyle> _resolveHighlightTheme(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final themeTokens =
        Theme.of(context).extension<OpenCodeThemeTokens>() ??
        classicThemeTokensFrom(Theme.of(context).colorScheme);
    if (_cachedHighlightTheme != null &&
        _cachedHighlightBrightness == brightness &&
        _cachedHighlightThemeKey == themeTokens.themeId) {
      return _cachedHighlightTheme!;
    }
    final rootStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      height: 1.4,
      color: themeTokens.textBase,
      backgroundColor: Colors.transparent,
    );
    final theme = openCodeHighlightTheme(
      tokens: themeTokens,
      brightness: brightness,
      baseStyle:
          rootStyle ?? const TextStyle(fontFamily: 'monospace', height: 1.4),
    );
    _cachedHighlightBrightness = brightness;
    _cachedHighlightThemeKey = themeTokens.themeId;
    _cachedHighlightTheme = theme;
    return theme;
  }

  String _resolveHighlightLanguage({required String path, String? mimeType}) {
    final normalizedPath = _normalizeFilePath(path).toLowerCase();
    final fileName = fileBasename(normalizedPath);
    final extension = _fileExtension(fileName);
    final normalizedMimeType = (mimeType ?? '').toLowerCase();

    if (normalizedMimeType.contains('json')) {
      return 'json';
    }
    if (normalizedMimeType.contains('yaml')) {
      return 'yaml';
    }
    if (normalizedMimeType.contains('xml')) {
      return 'xml';
    }
    if (normalizedMimeType.contains('markdown')) {
      return 'markdown';
    }
    if (normalizedMimeType.contains('sql')) {
      return 'sql';
    }

    switch (fileName) {
      case 'dockerfile':
        return 'dockerfile';
      case 'makefile':
        return 'makefile';
      case '.bashrc':
      case '.bash_profile':
      case '.bash_aliases':
      case '.zshrc':
      case '.zprofile':
      case '.zshenv':
      case '.profile':
        return 'bash';
    }

    switch (extension) {
      case 'dart':
        return 'dart';
      case 'js':
      case 'mjs':
      case 'cjs':
      case 'jsx':
        return 'javascript';
      case 'ts':
      case 'mts':
      case 'cts':
      case 'tsx':
        return 'typescript';
      case 'json':
        return 'json';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'md':
      case 'mdx':
        return 'markdown';
      case 'sh':
      case 'ash':
      case 'bash':
      case 'zsh':
        return 'bash';
      case 'py':
        return 'python';
      case 'go':
        return 'go';
      case 'rs':
        return 'rust';
      case 'java':
        return 'java';
      case 'kt':
      case 'kts':
        return 'kotlin';
      case 'swift':
        return 'swift';
      case 'php':
        return 'php';
      case 'rb':
        return 'ruby';
      case 'sql':
        return 'sql';
      case 'html':
      case 'htm':
      case 'xml':
      case 'svg':
        return 'xml';
      case 'css':
        return 'css';
      case 'scss':
        return 'scss';
      case 'less':
        return 'less';
      case 'toml':
      case 'ini':
      case 'cfg':
      case 'conf':
      case 'properties':
        return 'ini';
      case 'vue':
        return 'vue';
    }

    // Canonical names and package-declared aliases stay available without a
    // hand-maintained case for every shipped language.
    return resolveBuiltinFileHighlightLanguage(extension) ?? 'plaintext';
  }
}

/// Selection toolbars for the file editor, one per edit mode.
///
/// `CodeEditor` only shows a selection menu when a toolbar controller is
/// supplied; without one it calls `toolbarController?.show(...)` and nothing
/// happens, which is why copying and pasting were unavailable on Android
/// (#121). Button labels come from `ContextMenuButtonType`, so Flutter
/// localises them and no new strings are needed.
final Map<bool, SelectionToolbarController> _fileEditorToolbarControllers =
    <bool, SelectionToolbarController>{};

SelectionToolbarController fileEditorSelectionToolbarController({
  required bool readOnly,
}) {
  return _fileEditorToolbarControllers.putIfAbsent(
    readOnly,
    () => MobileSelectionToolbarController(
      builder:
          ({
            required BuildContext context,
            required TextSelectionToolbarAnchors anchors,
            required CodeLineEditingController controller,
            required VoidCallback onDismiss,
            required VoidCallback onRefresh,
          }) {
            final hasSelection = controller.selectedText.isNotEmpty;
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: anchors,
              buttonItems: <ContextMenuButtonItem>[
                if (hasSelection)
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.copy,
                    onPressed: () {
                      unawaited(controller.copy());
                      onDismiss();
                    },
                  ),
                if (hasSelection && !readOnly)
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.cut,
                    onPressed: () {
                      controller.cut();
                      onDismiss();
                    },
                  ),
                // Pasting needs a writable buffer, so it is offered only when
                // the file is actually editable.
                if (!readOnly)
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.paste,
                    onPressed: () {
                      controller.paste();
                      onDismiss();
                    },
                  ),
                ContextMenuButtonItem(
                  type: ContextMenuButtonType.selectAll,
                  onPressed: () {
                    controller.selectAll();
                    onRefresh();
                  },
                ),
              ],
            );
          },
    ),
  );
}

class _EditorLineSelectionPainter extends CustomPainter {
  _EditorLineSelectionPainter({
    required this.controller,
    required this.notifier,
    required Set<int> selectedLines,
    required this.color,
  }) : selectedLines = Set<int>.unmodifiable(selectedLines),
       super(repaint: notifier);

  final CodeLineEditingController controller;
  final CodeIndicatorValueNotifier notifier;
  final Set<int> selectedLines;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedLines.isEmpty) {
      return;
    }
    final value = notifier.value;
    if (value == null || value.paragraphs.isEmpty) {
      return;
    }
    final paint = Paint()..color = color;
    for (final paragraph in value.paragraphs) {
      final lineNumber = controller.index2lineIndex(paragraph.index) + 1;
      if (!selectedLines.contains(lineNumber)) {
        continue;
      }
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          paragraph.top,
          size.width,
          paragraph.preferredLineHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EditorLineSelectionPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.notifier != notifier ||
        oldDelegate.color != color ||
        !setEquals(oldDelegate.selectedLines, selectedLines);
  }
}
