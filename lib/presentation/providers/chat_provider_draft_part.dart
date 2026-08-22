part of 'chat_provider.dart';

extension _ChatProviderDraftState on ChatProvider {
  Future<ChatComposerDraft?> _loadPersistedComposerDraft(
    String sessionId, {
    required String serverId,
  }) async {
    final raw = await localDataSource.getSessionComposerDraftJson(
      sessionId: sessionId,
      serverId: serverId,
    );
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final text = decoded['text']?.toString() ?? '';
      final shellMode = decoded['shellMode'] == true;
      final attachmentsRaw = decoded['attachments'];
      final attachments = <FileInputPart>[];
      if (attachmentsRaw is List) {
        for (final item in attachmentsRaw) {
          if (item is! Map) {
            continue;
          }
          final mime = item['mime']?.toString().trim() ?? '';
          final url = item['url']?.toString().trim() ?? '';
          if (mime.isEmpty || url.isEmpty) {
            continue;
          }
          final filename = item['filename']?.toString();
          final sourceRaw = item['source'];
          FileInputSource? source;
          if (sourceRaw is Map) {
            final path = sourceRaw['path']?.toString().trim() ?? '';
            final type = sourceRaw['type']?.toString().trim() ?? '';
            final textRaw = sourceRaw['text'];
            if (path.isNotEmpty && type.isNotEmpty && textRaw is Map) {
              source = FileInputSource(
                path: path,
                type: type,
                text: FileInputSourceText(
                  value: textRaw['value']?.toString() ?? '',
                  start: textRaw['start'] is num
                      ? (textRaw['start'] as num).toInt()
                      : 0,
                  end: textRaw['end'] is num
                      ? (textRaw['end'] as num).toInt()
                      : 0,
                ),
              );
            }
          }
          attachments.add(
            FileInputPart(
              mime: mime,
              url: url,
              filename: filename == null || filename.isEmpty ? null : filename,
              source: source,
            ),
          );
        }
      }
      final draft = ChatComposerDraft(
        text: text,
        attachments: List<FileInputPart>.unmodifiable(attachments),
        shellMode: shellMode,
      );
      return draft.hasContent ? draft : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistComposerDraftForSessionInternal({
    required String sessionId,
    required ChatComposerDraft? draft,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }
    final serverId = await _resolveServerScopeId();
    String? payload;
    if (draft != null && draft.hasContent) {
      payload = json.encode(<String, dynamic>{
        'text': draft.text,
        'shellMode': draft.shellMode,
        'attachments': draft.attachments
            .map(
              (attachment) => <String, dynamic>{
                'mime': attachment.mime,
                'url': attachment.url,
                'filename': attachment.filename,
                'source': attachment.source == null
                    ? null
                    : <String, dynamic>{
                        'path': attachment.source!.path,
                        'type': attachment.source!.type,
                        'text': <String, dynamic>{
                          'value': attachment.source!.text.value,
                          'start': attachment.source!.text.start,
                          'end': attachment.source!.text.end,
                        },
                      },
              },
            )
            .toList(growable: false),
      });
    }
    await localDataSource.saveSessionComposerDraftJson(
      payload,
      sessionId: normalizedSessionId,
      serverId: serverId,
    );
  }

  void _setActiveSendDraft(
    String draftText, {
    required List<FileInputPart> attachments,
    required bool shellMode,
  }) {
    _clearRejectedDraft();
    final normalizedDraft = draftText.trim();
    final effectiveAttachments = shellMode
        ? const <FileInputPart>[]
        : List<FileInputPart>.unmodifiable(attachments);
    if (normalizedDraft.isEmpty && effectiveAttachments.isEmpty) {
      _activeSendDraft = null;
      return;
    }
    final composerText = shellMode
        ? normalizedDraft.isEmpty
              ? ''
              : '!$normalizedDraft'
        : normalizedDraft;
    _activeSendDraft = ChatComposerDraft(
      text: composerText,
      attachments: effectiveAttachments,
      shellMode: shellMode,
    );
  }

  void _clearActiveSendDraft() {
    _activeSendDraft = null;
  }

  void _clearRejectedDraft() {
    _rejectedDraft = null;
  }

  void _stashRejectedDraftForRetry({String? sessionId}) {
    final draft = _activeSendDraft;
    _activeSendDraft = null;
    if (draft == null || !draft.hasContent) {
      return;
    }
    final effectiveSessionId = sessionId?.trim();
    // Only check for a missing session ID — do NOT discard the draft
    // when the app is briefly backgrounded, not foreground-active, or
    // off the chat route. The foreground/activity guards that were here
    // previously caused permanent text loss during brief background
    // transitions (notification swipe, incoming call, screen off).
    // consumeRejectedDraft already validates session match and
    // chat-screen-active state at restore time.
    if (effectiveSessionId == null || effectiveSessionId.isEmpty) {
      _clearRejectedDraft();
      return;
    }
    _rejectedDraft = _RejectedDraftEnvelope(
      sessionId: effectiveSessionId,
      draft: draft,
    );
  }
}

extension ChatProviderDraftPersistence on ChatProvider {
  Future<void> persistComposerDraftForSession({
    required String sessionId,
    required ChatComposerDraft? draft,
  }) {
    return _persistComposerDraftForSessionInternal(
      sessionId: sessionId,
      draft: draft,
    );
  }
}
