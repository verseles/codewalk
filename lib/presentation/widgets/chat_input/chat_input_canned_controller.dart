part of '../chat_input_widget.dart';

const String _cannedAgentInheritValue = '__cw_inherit_agent__';
const String _cannedModelInheritValue = '__cw_inherit_model__';
const String _cannedModelSelectionSeparator = '\t';
const String _cannedThinkingInheritValue = '__cw_inherit_thinking__';
const String _cannedThinkingAutoValue = '__cw_auto_thinking__';

enum _CannedAnswerEditorOutcome { saved, deleted }

class _CannedAnswerEditorResult {
  const _CannedAnswerEditorResult.saved(this.answer)
    : outcome = _CannedAnswerEditorOutcome.saved;
  const _CannedAnswerEditorResult.deleted()
    : outcome = _CannedAnswerEditorOutcome.deleted,
      answer = null;
  final _CannedAnswerEditorOutcome outcome;
  final CannedAnswer? answer;
}

extension _ChatInputCannedController on _ChatInputWidgetState {
  List<CannedAnswer> get _visibleCannedAnswers {
    final merged = <CannedAnswer>[
      ..._projectCannedAnswers,
      ..._globalCannedAnswers,
    ];
    merged.sort((a, b) => b.updatedAtEpochMs.compareTo(a.updatedAtEpochMs));
    return merged;
  }

  String get _normalizedCannedServerId {
    final value = widget.cannedAnswersServerId?.trim() ?? '';
    return value;
  }

  String get _normalizedCannedScopeId {
    final value = widget.cannedAnswersScopeId?.trim() ?? '';
    return value;
  }

  Future<void> _loadCannedAnswers() async {
    final localDataSource = widget.cannedAnswersDataSource;
    if (localDataSource == null) {
      if (!mounted) {
        return;
      }
      _setState(() {
        _globalCannedAnswers = <CannedAnswer>[];
        _projectCannedAnswers = <CannedAnswer>[];
      });
      return;
    }
    final globalRaw = await localDataSource.getCannedAnswersJson();
    final hasScopedContext =
        _normalizedCannedServerId.isNotEmpty &&
        _normalizedCannedScopeId.isNotEmpty;
    final scopedRaw = hasScopedContext
        ? await localDataSource.getCannedAnswersJson(
            serverId: _normalizedCannedServerId,
            scopeId: _normalizedCannedScopeId,
          )
        : null;
    if (!mounted) {
      return;
    }
    _setState(() {
      _globalCannedAnswers = _decodeCannedAnswers(globalRaw);
      _projectCannedAnswers = _decodeCannedAnswers(scopedRaw);
      if (_popoverType == ChatComposerPopoverType.canned &&
          _activeSuggestionIndex >= _visibleCannedAnswers.length) {
        _activeSuggestionIndex = _visibleCannedAnswers.isEmpty
            ? 0
            : _visibleCannedAnswers.length - 1;
      }
    });
  }

  List<CannedAnswer> _decodeCannedAnswers(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <CannedAnswer>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <CannedAnswer>[];
      }
      final parsed = <CannedAnswer>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final answer = CannedAnswer.fromJson(item);
        if (answer != null) {
          parsed.add(answer);
        }
      }
      return parsed;
    } catch (_) {
      return <CannedAnswer>[];
    }
  }

  Future<void> _persistCannedAnswers({
    required CannedAnswerScopeMode scope,
  }) async {
    final localDataSource = widget.cannedAnswersDataSource;
    if (localDataSource == null) {
      return;
    }
    final answers = scope == CannedAnswerScopeMode.global
        ? _globalCannedAnswers
        : _projectCannedAnswers;
    final payload = jsonEncode(
      answers.map((answer) => answer.toJson()).toList(growable: false),
    );
    if (scope == CannedAnswerScopeMode.global) {
      await localDataSource.saveCannedAnswersJson(payload);
      return;
    }
    if (_normalizedCannedServerId.isEmpty || _normalizedCannedScopeId.isEmpty) {
      return;
    }
    await localDataSource.saveCannedAnswersJson(
      payload,
      serverId: _normalizedCannedServerId,
      scopeId: _normalizedCannedScopeId,
    );
  }

  void _toggleExtrasPopover() {
    _setState(() {
      if (_popoverType == ChatComposerPopoverType.canned) {
        _popoverType = ChatComposerPopoverType.none;
        _activeSuggestionIndex = 0;
        return;
      }
      _popoverType = ChatComposerPopoverType.canned;
      _activeSuggestionIndex = 0;
      // Review r1: stale in-flight mention/slash loads must not clobber the
      // overlay. Their post-await guards compare against these queries.
      _suggestionDebounce?.cancel();
      _activeMentionQuery = '';
      _activeSlashQuery = '';
    });
  }

  Future<void> _openQuickReplyCreatorFromExtras() async {
    _closePopover();
    await _promptCreateCannedAnswer();
  }

  void _openAttachmentOptionsFromExtras() {
    if (!_canOpenAttachmentOptions) {
      return;
    }
    _closePopover();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showAttachmentOptions();
    });
  }

  Future<void> _applyCannedAnswer(CannedAnswer answer) async {
    final trimmedText = answer.text.trimRight();
    if (trimmedText.isEmpty) {
      return;
    }
    if (answer.insertMode == CannedAnswerInsertMode.replace) {
      _controller.value = TextEditingValue(
        text: trimmedText,
        selection: TextSelection.collapsed(offset: trimmedText.length),
      );
    } else {
      final parts = splitComposerTextAtSelection(_controller.value);
      _controller.value = composeComposerValueWithSuffix(
        leadingText: '${parts.leadingText}$trimmedText',
        trailingText: parts.trailingText,
      );
    }
    _setState(() {
      _isComposing = _controller.text.trim().isNotEmpty;
      _popoverType = ChatComposerPopoverType.none;
      _activeSuggestionIndex = 0;
    });
    final selectionOverride = ChatQuickReplySelectionOverride(
      agentName: answer.normalizedAgentName.isEmpty
          ? null
          : answer.normalizedAgentName,
      providerId: answer.normalizedProviderId.isEmpty
          ? null
          : answer.normalizedProviderId,
      modelId: answer.normalizedModelId.isEmpty
          ? null
          : answer.normalizedModelId,
      thinkingMode: answer.thinkingMode,
      thinkingVariantId: answer.normalizedThinkingVariantId.isEmpty
          ? null
          : answer.normalizedThinkingVariantId,
    );
    if (selectionOverride.hasExplicitOverride) {
      final applyOverride = widget.onApplyQuickReplySelectionOverride;
      if (applyOverride == null) {
        _showCannedAnswerOverrideWarning(_cannedOverrideApplyFailedMessage);
        _ensureInputFocus();
        return;
      }
      final result = await applyOverride(selectionOverride);
      if (!mounted) {
        return;
      }
      if (!result.applied) {
        _showCannedAnswerOverrideWarning(
          result.message ?? _cannedOverrideApplyFailedMessage,
        );
        _ensureInputFocus();
        return;
      }
    }
    if (answer.sendAutomatically) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_handleSendMessage());
      });
      return;
    }
    _ensureInputFocus();
  }

  String get _cannedOverrideApplyFailedMessage =>
      context.l10n.errorProviderUnavailable;

  void _showCannedAnswerOverrideWarning(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _promptCreateCannedAnswer() async {
    final result = await _showCannedAnswerDialog();
    final created = result?.answer;
    if (created == null ||
        result?.outcome != _CannedAnswerEditorOutcome.saved) {
      return;
    }
    if (!mounted) {
      return;
    }
    _setState(() {
      if (created.scopeMode == CannedAnswerScopeMode.global) {
        _globalCannedAnswers = <CannedAnswer>[created, ..._globalCannedAnswers];
      } else {
        _projectCannedAnswers = <CannedAnswer>[
          created,
          ..._projectCannedAnswers,
        ];
      }
    });
    await _persistCannedAnswers(scope: created.scopeMode);
    _ensureInputFocus();
  }

  Future<void> _promptEditCannedAnswer(CannedAnswer answer) async {
    if (!mounted) {
      return;
    }
    final result = await _showCannedAnswerDialog(initial: answer);
    if (!mounted || result == null) {
      _ensureInputFocus();
      return;
    }
    if (result.outcome == _CannedAnswerEditorOutcome.deleted) {
      _setState(() {
        if (answer.scopeMode == CannedAnswerScopeMode.global) {
          _globalCannedAnswers = _globalCannedAnswers
              .where((item) => item.id != answer.id)
              .toList(growable: false);
        } else {
          _projectCannedAnswers = _projectCannedAnswers
              .where((item) => item.id != answer.id)
              .toList(growable: false);
        }
      });
      await _persistCannedAnswers(scope: answer.scopeMode);
      _ensureInputFocus();
      return;
    }
    final edited = result.answer;
    if (edited == null) {
      _ensureInputFocus();
      return;
    }
    _setState(() {
      _globalCannedAnswers = _globalCannedAnswers
          .where((item) => item.id != answer.id)
          .toList(growable: false);
      _projectCannedAnswers = _projectCannedAnswers
          .where((item) => item.id != answer.id)
          .toList(growable: false);
      if (edited.scopeMode == CannedAnswerScopeMode.global) {
        _globalCannedAnswers = <CannedAnswer>[edited, ..._globalCannedAnswers];
      } else {
        _projectCannedAnswers = <CannedAnswer>[
          edited,
          ..._projectCannedAnswers,
        ];
      }
    });
    await _persistCannedAnswers(scope: CannedAnswerScopeMode.global);
    await _persistCannedAnswers(scope: CannedAnswerScopeMode.projectOnly);
    _ensureInputFocus();
  }

  Future<_CannedAnswerEditorResult?> _showCannedAnswerDialog({
    CannedAnswer? initial,
  }) async {
    final labelController = TextEditingController(
      text: initial?.normalizedLabel,
    );
    final textController = TextEditingController(text: initial?.text ?? '');
    var insertMode = initial?.insertMode ?? CannedAnswerInsertMode.append;
    var sendAutomatically = initial?.sendAutomatically ?? false;
    var scopeMode = initial?.scopeMode ?? CannedAnswerScopeMode.global;
    var agentSelection = _initialCannedAgentSelection(initial);
    var modelSelection = _initialCannedModelSelection(initial);
    var thinkingSelection = _initialCannedThinkingSelection(
      initial,
      modelSelection,
    );
    final isProjectScopeAvailable =
        _normalizedCannedServerId.isNotEmpty &&
        _normalizedCannedScopeId.isNotEmpty;
    if (!isProjectScopeAvailable &&
        scopeMode == CannedAnswerScopeMode.projectOnly) {
      scopeMode = CannedAnswerScopeMode.global;
    }
    final result = await showDialog<_CannedAnswerEditorResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final mediaQuery = MediaQuery.of(dialogContext);
            final colorScheme = Theme.of(dialogContext).colorScheme;
            final isCompact = mediaQuery.size.width < 600;
            final title = initial == null
                ? context.l10n.cannedAddTitle
                : context.l10n.cannedEditTitle;

            void save() {
              final text = textController.text.trim();
              if (text.isEmpty) {
                return;
              }
              final thinkingOverride = _thinkingOverrideFromSelection(
                thinkingSelection,
              );
              final modelOverride = _modelOverrideFromSelection(modelSelection);
              Navigator.of(dialogContext).pop(
                _CannedAnswerEditorResult.saved(
                  CannedAnswer(
                    id: initial?.id ?? _nextCannedAnswerId(),
                    label: labelController.text.trim().isEmpty
                        ? null
                        : labelController.text.trim(),
                    text: text,
                    insertMode: insertMode,
                    sendAutomatically: sendAutomatically,
                    scopeMode: scopeMode,
                    agentName: _agentNameFromSelection(agentSelection),
                    providerId: modelOverride.providerId,
                    modelId: modelOverride.modelId,
                    thinkingMode: thinkingOverride.mode,
                    thinkingVariantId: thinkingOverride.variantId,
                    updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
                  ),
                ),
              );
            }

            void delete() {
              if (initial == null) {
                return;
              }
              Navigator.of(
                dialogContext,
              ).pop(const _CannedAnswerEditorResult.deleted());
            }

            final body = _buildCannedEditorBody(
              dialogContext: dialogContext,
              isCompact: isCompact,
              initial: initial,
              labelController: labelController,
              textController: textController,
              insertMode: insertMode,
              sendAutomatically: sendAutomatically,
              scopeMode: scopeMode,
              agentSelection: agentSelection,
              modelSelection: modelSelection,
              thinkingSelection: thinkingSelection,
              isProjectScopeAvailable: isProjectScopeAvailable,
              onInsertModeChanged: (value) {
                setDialogState(() {
                  insertMode = value;
                });
              },
              onSendAutomaticallyChanged: (value) {
                setDialogState(() {
                  sendAutomatically = value;
                });
              },
              onScopeModeChanged: (value) {
                setDialogState(() {
                  scopeMode = value;
                });
              },
              onAgentSelectionChanged: (value) {
                setDialogState(() {
                  agentSelection = value;
                });
              },
              onModelSelectionChanged: (value) {
                setDialogState(() {
                  modelSelection = value;
                  if (!_thinkingSelectionAvailableForModel(
                    thinkingSelection,
                    modelSelection,
                  )) {
                    thinkingSelection = _cannedThinkingInheritValue;
                  }
                });
              },
              onThinkingSelectionChanged: (value) {
                setDialogState(() {
                  thinkingSelection = value;
                });
              },
            );

            if (isCompact) {
              return Dialog.fullscreen(
                key: const ValueKey<String>('canned_answer_editor_fullscreen'),
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(title),
                    leading: IconButton(
                      icon: const Icon(Symbols.close_rounded),
                      tooltip: context.l10n.commonCancel,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                    actions: [
                      if (initial != null)
                        IconButton(
                          key: const ValueKey<String>(
                            'canned_answer_delete_action',
                          ),
                          icon: const Icon(Symbols.delete_rounded),
                          tooltip: context.l10n.commonDelete,
                          color: colorScheme.error,
                          onPressed: delete,
                        ),
                      TextButton(
                        key: const ValueKey<String>(
                          'canned_answer_save_button',
                        ),
                        onPressed: save,
                        child: Text(context.l10n.commonSave),
                      ),
                    ],
                  ),
                  body: SafeArea(child: body),
                ),
              );
            }

            final dialogHeight = math.min(mediaQuery.size.height * 0.86, 820.0);
            return Dialog(
              key: const ValueKey<String>('canned_answer_editor_dialog'),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 720,
                height: dialogHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(
                                dialogContext,
                              ).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Symbols.close_rounded),
                            tooltip: context.l10n.commonCancel,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: body),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                      child: Row(
                        children: [
                          if (initial != null)
                            TextButton(
                              key: const ValueKey<String>(
                                'canned_answer_delete_button',
                              ),
                              onPressed: delete,
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.error,
                              ),
                              child: Text(context.l10n.commonDelete),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(context.l10n.commonCancel),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            key: const ValueKey<String>(
                              'canned_answer_save_button',
                            ),
                            onPressed: save,
                            child: Text(context.l10n.commonSave),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    labelController.dispose();
    textController.dispose();
    return result;
  }

  String _initialCannedAgentSelection(CannedAnswer? initial) {
    final agentName = initial?.normalizedAgentName ?? '';
    if (agentName.isNotEmpty &&
        widget.quickReplyAgentOptions.any(
          (option) => option.name == agentName,
        )) {
      return agentName;
    }
    return _cannedAgentInheritValue;
  }

  String _initialCannedModelSelection(CannedAnswer? initial) {
    final providerId = initial?.normalizedProviderId ?? '';
    final modelId = initial?.normalizedModelId ?? '';
    if (providerId.isNotEmpty &&
        modelId.isNotEmpty &&
        widget.quickReplyModelOptions.any(
          (option) =>
              option.providerId == providerId && option.modelId == modelId,
        )) {
      return _modelSelectionValue(providerId: providerId, modelId: modelId);
    }
    return _cannedModelInheritValue;
  }

  String _initialCannedThinkingSelection(
    CannedAnswer? initial,
    String modelSelection,
  ) {
    if (initial == null) {
      return _cannedThinkingInheritValue;
    }
    return switch (initial.thinkingMode) {
      CannedAnswerThinkingMode.inherit => _cannedThinkingInheritValue,
      CannedAnswerThinkingMode.auto => _cannedThinkingAutoValue,
      CannedAnswerThinkingMode.variant =>
        _variantOptionsForModelSelection(
              modelSelection,
            ).any((option) => option.id == initial.normalizedThinkingVariantId)
            ? initial.normalizedThinkingVariantId
            : _cannedThinkingInheritValue,
    };
  }

  String? _agentNameFromSelection(String value) {
    return value == _cannedAgentInheritValue ? null : value;
  }

  String _modelSelectionValue({
    required String providerId,
    required String modelId,
  }) {
    return '$providerId$_cannedModelSelectionSeparator$modelId';
  }

  ({String? providerId, String? modelId}) _modelOverrideFromSelection(
    String value,
  ) {
    if (value == _cannedModelInheritValue) {
      return (providerId: null, modelId: null);
    }
    final separatorIndex = value.indexOf(_cannedModelSelectionSeparator);
    if (separatorIndex <= 0 || separatorIndex == value.length - 1) {
      return (providerId: null, modelId: null);
    }
    return (
      providerId: value.substring(0, separatorIndex),
      modelId: value.substring(separatorIndex + 1),
    );
  }

  ({CannedAnswerThinkingMode mode, String? variantId})
  _thinkingOverrideFromSelection(String value) {
    if (value == _cannedThinkingInheritValue) {
      return (mode: CannedAnswerThinkingMode.inherit, variantId: null);
    }
    if (value == _cannedThinkingAutoValue) {
      return (mode: CannedAnswerThinkingMode.auto, variantId: null);
    }
    return (mode: CannedAnswerThinkingMode.variant, variantId: value);
  }

  Widget _buildCannedEditorBody({
    required BuildContext dialogContext,
    required bool isCompact,
    required CannedAnswer? initial,
    required TextEditingController labelController,
    required TextEditingController textController,
    required CannedAnswerInsertMode insertMode,
    required bool sendAutomatically,
    required CannedAnswerScopeMode scopeMode,
    required String agentSelection,
    required String modelSelection,
    required String thinkingSelection,
    required bool isProjectScopeAvailable,
    required ValueChanged<CannedAnswerInsertMode> onInsertModeChanged,
    required ValueChanged<bool> onSendAutomaticallyChanged,
    required ValueChanged<CannedAnswerScopeMode> onScopeModeChanged,
    required ValueChanged<String> onAgentSelectionChanged,
    required ValueChanged<String> onModelSelectionChanged,
    required ValueChanged<String> onThinkingSelectionChanged,
  }) {
    final initialAgentUnavailable =
        (initial?.normalizedAgentName.isNotEmpty ?? false) &&
        !widget.quickReplyAgentOptions.any(
          (option) => option.name == initial!.normalizedAgentName,
        );
    final initialModelUnavailable =
        (initial?.normalizedProviderId.isNotEmpty ?? false) &&
        (initial?.normalizedModelId.isNotEmpty ?? false) &&
        !widget.quickReplyModelOptions.any(
          (option) =>
              option.providerId == initial!.normalizedProviderId &&
              option.modelId == initial.normalizedModelId,
        );
    final variantOptions = _variantOptionsForModelSelection(modelSelection);
    final initialThinkingUnavailable =
        initial?.thinkingMode == CannedAnswerThinkingMode.variant &&
        !variantOptions.any(
          (option) => option.id == initial!.normalizedThinkingVariantId,
        );
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, isCompact ? 16 : 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCannedEditorSection(
              dialogContext: dialogContext,
              title: context.l10n.composerCannedText,
              children: [
                TextField(
                  key: const ValueKey<String>('canned_answer_label_field'),
                  controller: labelController,
                  decoration: InputDecoration(
                    labelText: context.l10n.composerCannedLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey<String>('canned_answer_text_field'),
                  controller: textController,
                  minLines: 3,
                  maxLines: isCompact ? 8 : 6,
                  decoration: InputDecoration(
                    labelText: context.l10n.cannedTextLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCannedEditorSection(
              dialogContext: dialogContext,
              title: context.l10n.settingsBehaviorTitle,
              children: [
                SwitchListTile(
                  title: Text(context.l10n.composerCannedAppendAtCursor),
                  subtitle: Text(context.l10n.cannedAppendAtCursorSubtitle),
                  value: insertMode == CannedAnswerInsertMode.append,
                  onChanged: (enabled) {
                    onInsertModeChanged(
                      enabled
                          ? CannedAnswerInsertMode.append
                          : CannedAnswerInsertMode.replace,
                    );
                  },
                ),
                SwitchListTile(
                  title: Text(context.l10n.composerCannedSendAutomatically),
                  subtitle: Text(context.l10n.cannedSendAutomaticallySubtitle),
                  value: sendAutomatically,
                  onChanged: onSendAutomaticallyChanged,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCannedEditorSection(
              dialogContext: dialogContext,
              title: context.l10n.composerCannedScopeGlobal,
              children: [
                SwitchListTile(
                  title: Text(context.l10n.composerCannedScopeGlobal),
                  subtitle: Text(
                    isProjectScopeAvailable
                        ? context.l10n.cannedScopeGlobalSubtitle
                        : context.l10n.cannedScopeGlobalUnavailableSubtitle,
                  ),
                  value: scopeMode == CannedAnswerScopeMode.global,
                  onChanged: isProjectScopeAvailable
                      ? (enabled) {
                          onScopeModeChanged(
                            enabled
                                ? CannedAnswerScopeMode.global
                                : CannedAnswerScopeMode.projectOnly,
                          );
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCannedEditorSection(
              dialogContext: dialogContext,
              title: context.l10n.chatChooseAgent,
              children: [
                SearchableDropdownFormField<String>(
                  key: const ValueKey<String>('canned_answer_agent_dropdown'),
                  value: agentSelection,
                  isExpanded: true,
                  onChanged: widget.quickReplySelectionOverridesEnabled
                      ? (value) => onAgentSelectionChanged(
                          value ?? _cannedAgentInheritValue,
                        )
                      : null,
                  decoration: InputDecoration(
                    labelText: context.l10n.chatChooseAgent,
                  ),
                  searchHintText: context.l10n.chatChooseAgent,
                  emptyText: context.l10n.cannedNoSuggestions,
                  searchTermsBuilder: _agentSearchTerms,
                  items: _cannedAgentDropdownItems(),
                ),
                if (initialAgentUnavailable)
                  _buildCannedEditorWarning(
                    dialogContext,
                    context.l10n.settingsBehaviorNoAgents,
                  ),
                const SizedBox(height: 12),
                SearchableDropdownFormField<String>(
                  key: const ValueKey<String>('canned_answer_model_dropdown'),
                  value: modelSelection,
                  isExpanded: true,
                  onChanged: widget.quickReplySelectionOverridesEnabled
                      ? (value) => onModelSelectionChanged(
                          value ?? _cannedModelInheritValue,
                        )
                      : null,
                  decoration: InputDecoration(
                    labelText: context.l10n.chatChooseModel,
                  ),
                  searchHintText: context.l10n.modelSearchHint,
                  emptyText: context.l10n.modelModelsFound,
                  searchTermsBuilder: _modelSearchTerms,
                  items: _cannedModelDropdownItems(),
                ),
                if (initialModelUnavailable)
                  _buildCannedEditorWarning(
                    dialogContext,
                    context.l10n.settingsBehaviorNoModels,
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey<String>(
                    'canned_answer_thinking_dropdown',
                  ),
                  initialValue: thinkingSelection,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.shortcutNextVariant,
                  ),
                  items: _cannedThinkingDropdownItems(variantOptions),
                  onChanged: widget.quickReplySelectionOverridesEnabled
                      ? (value) => onThinkingSelectionChanged(
                          value ?? _cannedThinkingInheritValue,
                        )
                      : null,
                ),
                if (initialThinkingUnavailable)
                  _buildCannedEditorWarning(
                    dialogContext,
                    context.l10n.shortcutNextVariant,
                  ),
                if (!widget.quickReplySelectionOverridesEnabled)
                  _buildCannedEditorWarning(
                    dialogContext,
                    context.l10n.chatReturnToMainConversation,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCannedEditorSection({
    required BuildContext dialogContext,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(dialogContext);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppShapes.borderLarge,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildCannedEditorWarning(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
      ),
    );
  }

  List<DropdownMenuItem<String>> _cannedAgentDropdownItems() {
    return <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(
        value: _cannedAgentInheritValue,
        child: Text(context.l10n.chatUseCurrent),
      ),
      for (final option in widget.quickReplyAgentOptions)
        DropdownMenuItem<String>(
          value: option.name,
          child: Text(option.label, overflow: TextOverflow.ellipsis),
        ),
    ];
  }

  Iterable<String> _agentSearchTerms(String value) {
    if (value == _cannedAgentInheritValue) {
      return <String>[
        context.l10n.chatUseCurrent,
        context.l10n.chatChooseAgent,
        'inherit',
      ];
    }
    final option = widget.quickReplyAgentOptions
        .where((item) => item.name == value)
        .firstOrNull;
    return <String>[value, if (option != null) option.label];
  }

  List<DropdownMenuItem<String>> _cannedModelDropdownItems() {
    return <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(
        value: _cannedModelInheritValue,
        child: Text(context.l10n.chatUseCurrent),
      ),
      for (final option in widget.quickReplyModelOptions)
        DropdownMenuItem<String>(
          value: _modelSelectionValue(
            providerId: option.providerId,
            modelId: option.modelId,
          ),
          child: Text(
            option.modelLabel == option.modelId
                ? '${option.providerLabel} / ${option.modelId}'
                : '${option.modelLabel} (${option.providerLabel})',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
  }

  Iterable<String> _modelSearchTerms(String value) {
    if (value == _cannedModelInheritValue) {
      return <String>[
        context.l10n.chatUseCurrent,
        context.l10n.chatChooseModel,
        'inherit',
      ];
    }
    final override = _modelOverrideFromSelection(value);
    final option = widget.quickReplyModelOptions
        .where(
          (item) =>
              item.providerId == override.providerId &&
              item.modelId == override.modelId,
        )
        .firstOrNull;
    return <String>[
      value,
      if (override.providerId != null) override.providerId!,
      if (override.modelId != null) override.modelId!,
      if (option != null) option.providerLabel,
      if (option != null) option.modelLabel,
    ];
  }

  List<ChatQuickReplyThinkingOption> _variantOptionsForModelSelection(
    String modelSelection,
  ) {
    if (modelSelection == _cannedModelInheritValue) {
      return widget.quickReplyThinkingOptions;
    }
    final override = _modelOverrideFromSelection(modelSelection);
    final option = widget.quickReplyModelOptions
        .where(
          (item) =>
              item.providerId == override.providerId &&
              item.modelId == override.modelId,
        )
        .firstOrNull;
    return option?.variantOptions ?? const <ChatQuickReplyThinkingOption>[];
  }

  bool _thinkingSelectionAvailableForModel(
    String thinkingSelection,
    String modelSelection,
  ) {
    if (thinkingSelection == _cannedThinkingInheritValue ||
        thinkingSelection == _cannedThinkingAutoValue) {
      return true;
    }
    return _variantOptionsForModelSelection(
      modelSelection,
    ).any((option) => option.id == thinkingSelection);
  }

  List<DropdownMenuItem<String>> _cannedThinkingDropdownItems(
    List<ChatQuickReplyThinkingOption> variantOptions,
  ) {
    return <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(
        value: _cannedThinkingInheritValue,
        child: Text(context.l10n.chatUseCurrent),
      ),
      DropdownMenuItem<String>(
        value: _cannedThinkingAutoValue,
        child: Text(context.l10n.modelAuto),
      ),
      for (final option in variantOptions)
        DropdownMenuItem<String>(
          value: option.id,
          child: Text(option.label, overflow: TextOverflow.ellipsis),
        ),
    ];
  }

  String _nextCannedAnswerId() {
    return 'canned_${DateTime.now().microsecondsSinceEpoch}';
  }

  Widget _buildExtrasActionChip({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _cannedAnswerDisplayText(CannedAnswer item) {
    // Keep each quick reply row to one visible text source.
    return item.normalizedLabel.isEmpty ? item.text : item.normalizedLabel;
  }

  Widget? _buildCannedAnswerRoutingIndicators(CannedAnswer item) {
    final hasAgentOverride = item.normalizedAgentName.isNotEmpty;
    final hasModelOverride =
        item.normalizedProviderId.isNotEmpty &&
        item.normalizedModelId.isNotEmpty;
    final hasThinkingOverride =
        item.thinkingMode != CannedAnswerThinkingMode.inherit;
    if (!hasAgentOverride && !hasModelOverride && !hasThinkingOverride) {
      return null;
    }
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final indicators = <Widget>[
      if (hasAgentOverride)
        Tooltip(
          message: context.l10n.chatChooseAgent,
          child: Icon(Symbols.support_agent_rounded, size: 18, color: color),
        ),
      if (hasModelOverride)
        Tooltip(
          message: context.l10n.chatChooseModel,
          child: Icon(Symbols.code_rounded, size: 18, color: color),
        ),
      if (hasThinkingOverride)
        Tooltip(
          message: context.l10n.shortcutNextVariant,
          child: Icon(Symbols.tune_rounded, size: 18, color: color),
        ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < indicators.length; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          indicators[index],
        ],
      ],
    );
  }

  Widget _buildExtrasPopover({
    required ColorScheme colorScheme,
    required double maxHeight,
  }) {
    final items = _visibleCannedAnswers;
    return Material(
      key: const ValueKey<String>('composer_popover_panel_extras'),
      color: colorScheme.surfaceContainerHighest,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          key: const ValueKey<String>('composer_popover_extras_replies'),
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildExtrasActionChip(
                    icon: Symbols.edit_note_rounded,
                    label: context.l10n.cannedNewQuickReply,
                    onPressed: () =>
                        unawaited(_openQuickReplyCreatorFromExtras()),
                  ),
                  _buildExtrasActionChip(
                    icon: Symbols.attach_file_rounded,
                    label: context.l10n.composerAttachFiles,
                    onPressed: _canOpenAttachmentOptions
                        ? _openAttachmentOptionsFromExtras
                        : null,
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Text(context.l10n.composerCannedNoReplies),
              )
            else
              for (var index = 0; index < items.length; index++)
                Builder(
                  builder: (context) {
                    final item = items[index];
                    final selected = index == _activeSuggestionIndex;
                    return ListTile(
                      selected: selected,
                      leading: item.scopeMode == CannedAnswerScopeMode.global
                          ? const Icon(Symbols.public_rounded, size: 18)
                          : null,
                      title: Text(
                        _cannedAnswerDisplayText(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _buildCannedAnswerRoutingIndicators(item),
                      onTap: () {
                        _setState(() {
                          _activeSuggestionIndex = index;
                        });
                        unawaited(_applyCannedAnswer(item));
                      },
                      onLongPress: () =>
                          unawaited(_promptEditCannedAnswer(item)),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}
