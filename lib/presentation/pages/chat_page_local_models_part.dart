part of 'chat_page.dart';

class _FileExplorerContextState {
  _FileExplorerContextState({
    required this.contextKey,
    required this.serverId,
    required this.rootDirectory,
  });

  final String contextKey;
  final String serverId;
  String rootDirectory;
  DateTime? lastLoadedAt;
  final Map<String, List<FileNode>> directoryChildren =
      <String, List<FileNode>>{};
  final Set<String> expandedDirectories = <String>{};
  final Set<String> loadingDirectories = <String>{};
  final Map<String, String> directoryErrors = <String, String>{};
  final Map<String, _FileTabViewState> tabsByPath =
      <String, _FileTabViewState>{};
  final Map<String, int> fileReloadGenerations = <String, int>{};
  int nextFileReloadGeneration = 0;
  final Map<String, _FileEditorDraftState> editorDraftsByPath =
      <String, _FileEditorDraftState>{};
  final Set<String> pendingMutationPaths = <String>{};
  FileTabSelectionState tabSelection = const FileTabSelectionState();
  WorkspaceFileOperationsCapabilities? fileOperationCapabilities;
  bool fileOperationCapabilitiesLoading = false;
  Future<void>? fileOperationCapabilitiesLoad;
  // Line selection state for "add to chat" feature (1-based line numbers).
  final Map<String, Set<int>> selectedLinesByPath = <String, Set<int>>{};
  final Map<String, int> lastSelectedLineByPath = <String, int>{};

  /// Pending scroll-to-line request (1-based). Set when a file is opened
  /// via a file path tap; consumed by the file viewer after initial render.
  /// Cleared after scrolling to avoid re-scrolling on rebuilds.
  int? pendingScrollToLine;
  bool rootLoadScheduled = false;
  String? treeError;

  bool get hasUnsavedDrafts => editorDraftsByPath.values.any(
    (draft) => draft.isDirty || draft.activeSave != null,
  );

  void resetForRoot(String nextRootDirectory) {
    rootDirectory = nextRootDirectory;
    lastLoadedAt = null;
    directoryChildren.clear();
    expandedDirectories.clear();
    loadingDirectories.clear();
    directoryErrors.clear();
    tabsByPath.clear();
    nextFileReloadGeneration += 1;
    fileReloadGenerations.clear();
    _disposeEditorDrafts();
    pendingMutationPaths.clear();
    fileOperationCapabilities = null;
    fileOperationCapabilitiesLoading = false;
    fileOperationCapabilitiesLoad = null;
    selectedLinesByPath.clear();
    lastSelectedLineByPath.clear();
    pendingScrollToLine = null;
    rootLoadScheduled = false;
    treeError = null;
  }

  void removeEditorDraft(String path) {
    editorDraftsByPath.remove(path)?.dispose();
  }

  void dispose() {
    _disposeEditorDrafts();
  }

  void _disposeEditorDrafts() {
    for (final draft in editorDraftsByPath.values) {
      draft.dispose();
    }
    editorDraftsByPath.clear();
  }
}

enum _FileTabLoadStatus { loading, ready, binary, error }

class _FileTabViewState {
  const _FileTabViewState({
    required this.status,
    required this.content,
    this.errorMessage,
    this.mimeType,
  });

  final _FileTabLoadStatus status;
  final String content;
  final String? errorMessage;
  final String? mimeType;
}

class _FileEditorDraftState {
  factory _FileEditorDraftState({required String content}) {
    final lineBreak = _detectTextLineBreak(content);
    return _FileEditorDraftState._(content: content, lineBreak: lineBreak);
  }

  _FileEditorDraftState._({required String content, required this.lineBreak})
    : controller = CodeLineEditingController.fromText(
        content,
        CodeLineOptions(lineBreak: lineBreak),
      ),
      scrollController = CodeScrollController(),
      savedContent = content;

  final CodeLineEditingController controller;
  final CodeScrollController scrollController;
  final TextLineBreak lineBreak;
  String savedContent;
  bool isSaving = false;
  String? saveErrorMessage;
  Future<void>? activeSave;
  String? pendingLifecycleFlushContent;
  bool pendingLifecycleFlushAllowsInactiveContext = false;

  /// Pending autosave, debounced after the last edit so typing does not
  /// produce a write per keystroke.
  Timer? autosaveTimer;

  void cancelAutosave() {
    autosaveTimer?.cancel();
    autosaveTimer = null;
  }

  bool get isDirty => controller.text != savedContent;

  void markSavedContent(String content) {
    savedContent = content;
    saveErrorMessage = null;
  }

  void replaceSavedContent(String content) {
    controller.text = content;
    savedContent = controller.text;
    saveErrorMessage = null;
  }

  void dispose() {
    cancelAutosave();
    controller.dispose();
    scrollController.verticalScroller.dispose();
    scrollController.horizontalScroller.dispose();
    scrollController.dispose();
  }

  static TextLineBreak _detectTextLineBreak(String content) {
    final firstCarriageReturn = content.indexOf('\r');
    if (firstCarriageReturn < 0) {
      return TextLineBreak.lf;
    }
    final nextIndex = firstCarriageReturn + 1;
    if (nextIndex < content.length && content.codeUnitAt(nextIndex) == 0x0A) {
      return TextLineBreak.crlf;
    }
    return TextLineBreak.cr;
  }
}

abstract class _TimelineEntry {
  const _TimelineEntry();

  String get key;
}

class _TimelineMessageEntry extends _TimelineEntry {
  const _TimelineMessageEntry(this.message);

  final ChatMessage message;

  @override
  String get key => 'timeline_msg_${message.id}';
}

class _TimelinePermissionPromptEntry extends _TimelineEntry {
  const _TimelinePermissionPromptEntry({required this.request});

  final ChatPermissionRequest request;

  @override
  String get key => 'timeline_permission_prompt_${request.id}';
}

class _TimelinePendingAssistantEntry extends _TimelineEntry {
  const _TimelinePendingAssistantEntry({required this.anchorMessageId});

  final String anchorMessageId;

  @override
  String get key => 'timeline_pending_assistant_$anchorMessageId';
}

class _TimelineCollapsedHistoryEntry extends _TimelineEntry {
  const _TimelineCollapsedHistoryEntry({
    required this.group,
    required this.expanded,
  });

  final _CollapsedHistoryGroup group;
  final bool expanded;

  @override
  String get key => 'timeline_collapsed_history_${group.id}';
}

class _CollapsedHistoryGroup {
  const _CollapsedHistoryGroup({
    required this.startMessageId,
    required this.endMessageId,
    required this.messageCount,
    required this.createdAt,
    required this.compactionId,
    required this.compactionLabel,
  });

  final String startMessageId;
  final String endMessageId;
  final int messageCount;
  final DateTime createdAt;
  final String compactionId;
  final String compactionLabel;

  String get id => '${compactionId}_${startMessageId}_$endMessageId';
}

class _TimelineCollapsedAssistantWorkEntry extends _TimelineEntry {
  const _TimelineCollapsedAssistantWorkEntry({
    required this.group,
    required this.expanded,
  });

  final _CollapsedAssistantWorkGroup group;
  final bool expanded;

  @override
  String get key => 'timeline_collapsed_assistant_work_${group.id}';
}

class _CollapsedAssistantWorkGroup {
  const _CollapsedAssistantWorkGroup({
    required this.startMessageId,
    required this.endMessageId,
    required this.finalMessageId,
    required this.messageCount,
    required this.createdAt,
  });

  final String startMessageId;
  final String endMessageId;
  final String finalMessageId;
  final int messageCount;
  final DateTime createdAt;

  String get id => 'assistant_work_$finalMessageId';
}

class _TimelineRetryIndicatorEntry extends _TimelineEntry {
  const _TimelineRetryIndicatorEntry();

  @override
  String get key => 'timeline_retry_indicator';
}

enum _AssistantProgressStage { thinking, receiving, retrying }

enum _ComposerStatusType {
  activeProgress,
  dynamicReasoning,
  receiving,
  retrying,
  stopHint,
  tip,
}

class _ComposerStatusPresentation {
  const _ComposerStatusPresentation._({
    required this.type,
    required this.label,
    this.icon,
  });

  const _ComposerStatusPresentation.activeProgress({
    required String label,
    required IconData icon,
  }) : this._(
         type: _ComposerStatusType.activeProgress,
         label: label,
         icon: icon,
       );

  const _ComposerStatusPresentation.dynamicReasoning(String label)
    : this._(type: _ComposerStatusType.dynamicReasoning, label: label);

  _ComposerStatusPresentation.receiving({required String label})
    : this._(type: _ComposerStatusType.receiving, label: label);

  _ComposerStatusPresentation.retrying({required String label})
    : this._(type: _ComposerStatusType.retrying, label: label);

  _ComposerStatusPresentation.stopHint({required String label})
    : this._(type: _ComposerStatusType.stopHint, label: label);

  _ComposerStatusPresentation.tip(String label)
    : this._(type: _ComposerStatusType.tip, label: label);

  final _ComposerStatusType type;
  final String label;
  final IconData? icon;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _ComposerStatusPresentation &&
        other.type == type &&
        other.label == label &&
        other.icon == icon;
  }

  @override
  int get hashCode => Object.hash(type, label, icon);
}
