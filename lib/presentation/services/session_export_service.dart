import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/session.dart' show SessionRevert;

/// Builds local transcript exports from the current in-memory session state.
class SessionExportService {
  const SessionExportService();

  String markdown(ChatSession session, List<ChatMessage> messages) {
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('title: ${_yamlScalar(_sessionTitle(session))}')
      ..writeln('session_id: ${_yamlScalar(session.id)}')
      ..writeln('workspace_id: ${_yamlScalar(session.workspaceId)}')
      ..writeln('created_at: ${_yamlScalar(_iso(session.time))}')
      ..writeln('message_count: ${messages.length}')
      ..writeln('exported_at: ${_yamlScalar(_iso(DateTime.now()))}')
      ..writeln('---')
      ..writeln()
      ..writeln('# ${_sessionTitle(session)}')
      ..writeln()
      ..writeln('- Session ID: `${session.id}`')
      ..writeln('- Workspace: `${session.workspaceId}`')
      ..writeln('- Created: ${_iso(session.time)}');

    final directory = session.directory?.trim();
    if (directory != null && directory.isNotEmpty) {
      buffer.writeln('- Directory: `$directory`');
    }
    final summary = session.summary?.trim();
    if (summary != null && summary.isNotEmpty) {
      buffer.writeln('- Summary: $summary');
    }
    buffer.writeln();

    if (messages.isEmpty) {
      buffer.writeln('_No messages in this session._');
      return buffer.toString();
    }

    for (var index = 0; index < messages.length; index += 1) {
      final message = messages[index];
      final role = message.role == MessageRole.user ? 'User' : 'Assistant';
      buffer
        ..writeln('## ${index + 1}. $role - ${_iso(message.time)}')
        ..writeln();

      if (message is AssistantMessage) {
        final details = <String>[];
        if (message.providerId?.trim().isNotEmpty ?? false) {
          details.add('provider `${message.providerId}`');
        }
        if (message.modelId?.trim().isNotEmpty ?? false) {
          details.add('model `${message.modelId}`');
        }
        if (message.cost != null) {
          details.add('cost ${message.cost!.toStringAsFixed(6)}');
        }
        final tokens = message.tokens;
        if (tokens != null) {
          details.add('tokens ${tokens.total}');
        }
        if (details.isNotEmpty) {
          buffer
            ..writeln('_${details.join(' · ')}_')
            ..writeln();
        }
        final error = message.error;
        if (error != null) {
          buffer
            ..writeln('> Error: `${error.name}` - ${error.message}')
            ..writeln();
        }
      }

      if (message.parts.isEmpty) {
        buffer.writeln('_No visible content._');
      } else {
        for (final part in message.parts) {
          _writePartMarkdown(buffer, part);
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  String json(ChatSession session, List<ChatMessage> messages) {
    final payload = <String, dynamic>{
      'schema': 'codewalk.session_export.v1',
      'exportedAt': _iso(DateTime.now()),
      'session': _sessionJson(session),
      'messages': messages.map(_messageJson).toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Uint8List bytes(String content) => Uint8List.fromList(utf8.encode(content));

  String fileName(ChatSession session, String extension) {
    final safeExt = extension
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toLowerCase();
    final ext = safeExt.isEmpty ? 'md' : safeExt;
    var slug = _sessionTitle(session)
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]+'), '-')
        .replaceAll(RegExp(r'\s+', unicode: true), '-')
        .replaceAll(RegExp(r'[^\p{L}\p{N}-]+', unicode: true), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.length > 60) {
      slug = slug.substring(0, 60).replaceAll(RegExp(r'-+$'), '');
    }
    final safeTitle = slug.isEmpty ? 'session' : slug.toLowerCase();
    return '${safeTitle}_${session.id}.$ext';
  }

  void _writePartMarkdown(StringBuffer buffer, MessagePart part) {
    switch (part) {
      case TextPart(:final text):
        buffer
          ..writeln(text.trim().isEmpty ? '_Empty text part._' : text.trim())
          ..writeln();
      case ReasoningPart(:final text):
        buffer
          ..writeln('> Reasoning')
          ..writeln()
          ..writeln(_blockquote(text.trim()))
          ..writeln();
      case FilePart(
        :final filename,
        :final url,
        :final mime,
        :final fileSource,
        :final symbolSource,
      ):
        final label = filename ?? fileSource?.path ?? symbolSource?.path ?? url;
        buffer
          ..writeln('- File: `$label`')
          ..writeln('  - MIME: `$mime`');
        if (fileSource != null) {
          buffer.writeln('  - Source: `${fileSource.path}`');
        }
        if (symbolSource != null) {
          buffer.writeln(
            '  - Symbol: `${symbolSource.name}` in `${symbolSource.path}`',
          );
        }
        buffer.writeln();
      case ToolPart(:final tool, :final state):
        _writeToolMarkdown(buffer, tool, state);
      case AgentPart(:final name):
        buffer
          ..writeln('- Agent: `$name`')
          ..writeln();
      case StepStartPart(:final snapshot):
        buffer
          ..writeln(
            '- Step started${snapshot == null ? '' : ' from `$snapshot`'}',
          )
          ..writeln();
      case StepFinishPart(:final reason, :final cost, :final tokens):
        buffer
          ..writeln('- Step finished: `$reason`')
          ..writeln(
            '  - Cost: ${cost.toStringAsFixed(6)}; tokens: ${tokens.total}',
          )
          ..writeln();
      case SnapshotPart(:final snapshot):
        buffer
          ..writeln('- Snapshot: `$snapshot`')
          ..writeln();
      case PatchPart(:final files, :final hash):
        buffer
          ..writeln('- Patch: `$hash`')
          ..writeln('  - Files: ${files.map((f) => '`$f`').join(', ')}')
          ..writeln();
      case SubtaskPart(:final description, :final agent, :final command):
        buffer
          ..writeln('- Subtask: $description')
          ..writeln('  - Agent: `$agent`');
        if (command != null && command.trim().isNotEmpty) {
          buffer.writeln('  - Command: `$command`');
        }
        buffer.writeln();
      case RetryPart(:final attempt, :final error):
        buffer
          ..writeln('- Retry #$attempt: ${error.message}')
          ..writeln('  - Retryable: `${error.isRetryable}`')
          ..writeln();
      case CompactionPart(:final auto):
        buffer
          ..writeln('- Context compacted (${auto ? 'automatic' : 'manual'})')
          ..writeln();
    }
  }

  void _writeToolMarkdown(StringBuffer buffer, String tool, ToolState state) {
    buffer
      ..writeln('### Tool: `$tool`')
      ..writeln()
      ..writeln('- Status: `${state.status.name}`');
    switch (state) {
      case ToolStatePending():
        break;
      case ToolStateRunning(:final title, :final input):
        if (title != null && title.trim().isNotEmpty) {
          buffer.writeln('- Title: $title');
        }
        buffer
          ..writeln()
          ..writeln('Input:')
          ..writeln(_fencedJson(input));
      case ToolStateCompleted(:final title, :final input, :final output):
        if (title != null && title.trim().isNotEmpty) {
          buffer.writeln('- Title: $title');
        }
        buffer
          ..writeln()
          ..writeln('Input:')
          ..writeln(_fencedJson(input));
        if (output.trim().isNotEmpty) {
          buffer
            ..writeln('Output:')
            ..writeln(_fenced(output.trim()));
        }
      case ToolStateError(:final title, :final input, :final error):
        if (title != null && title.trim().isNotEmpty) {
          buffer.writeln('- Title: $title');
        }
        buffer
          ..writeln()
          ..writeln('Input:')
          ..writeln(_fencedJson(input))
          ..writeln('Error:')
          ..writeln(_fenced(error.trim()));
    }
    buffer.writeln();
  }

  Map<String, dynamic> _sessionJson(ChatSession session) {
    return <String, dynamic>{
      'id': session.id,
      'workspaceId': session.workspaceId,
      'title': session.title,
      'time': _iso(session.time),
      'parentId': session.parentId,
      'directory': session.directory,
      'archivedAt': session.archivedAt == null
          ? null
          : _iso(session.archivedAt!),
      'shared': session.shared,
      'shareUrl': session.shareUrl,
      'summary': session.summary,
      'path': session.path == null
          ? null
          : <String, dynamic>{
              'root': session.path!.root,
              'workspace': session.path!.workspace,
            },
      'revert': _revertJson(session.revert),
    };
  }

  Map<String, dynamic> _messageJson(ChatMessage message) {
    final messageJson = <String, dynamic>{
      'sessionId': message.sessionId,
      'role': message.role.name,
      'time': _iso(message.time),
      if (message is AssistantMessage) ...<String, dynamic>{
        'completedTime': message.completedTime == null
            ? null
            : _iso(message.completedTime!),
        'providerId': message.providerId,
        'modelId': message.modelId,
        'cost': message.cost,
        'tokens': _tokensJson(message.tokens),
        'error': _messageErrorJson(message.error),
        'mode': message.mode,
        'summary': message.summary,
      },
      'parts': message.parts.map(_partJson).toList(growable: false),
    };
    final id = _officialId(message.id);
    if (id != null) {
      messageJson['id'] = id;
    }
    return messageJson;
  }

  Map<String, dynamic> _partJson(MessagePart part) {
    final base = <String, dynamic>{
      'sessionId': part.sessionId,
      'type': part.type.name,
    };
    final id = _officialId(part.id);
    if (id != null) {
      base['id'] = id;
    }
    final messageId = _officialId(part.messageId);
    if (messageId != null) {
      base['messageId'] = messageId;
    }
    switch (part) {
      case TextPart(:final text, :final time):
        return {
          ...base,
          'text': text,
          'time': time == null ? null : _iso(time),
        };
      case ReasoningPart(:final text, :final time):
        return {
          ...base,
          'text': text,
          'time': time == null ? null : _iso(time),
        };
      case FilePart(
        :final url,
        :final mime,
        :final filename,
        :final fileSource,
        :final symbolSource,
      ):
        return {
          ...base,
          'url': url,
          'mime': mime,
          'filename': filename,
          'source': _fileSourceJson(fileSource),
          'symbolSource': _symbolSourceJson(symbolSource),
        };
      case ToolPart(:final callId, :final tool, :final state):
        return {
          ...base,
          'callId': callId,
          'tool': tool,
          'state': _toolStateJson(state),
        };
      case AgentPart(:final name, :final source):
        return {...base, 'name': name, 'source': _agentSourceJson(source)};
      case StepStartPart(:final snapshot):
        return {...base, 'snapshot': snapshot};
      case StepFinishPart(
        :final reason,
        :final snapshot,
        :final cost,
        :final tokens,
      ):
        return {
          ...base,
          'reason': reason,
          'snapshot': snapshot,
          'cost': cost,
          'tokens': _tokensJson(tokens),
        };
      case SnapshotPart(:final snapshot):
        return {...base, 'snapshot': snapshot};
      case PatchPart(:final files, :final hash):
        return {...base, 'files': files, 'hash': hash};
      case SubtaskPart(
        :final prompt,
        :final description,
        :final agent,
        :final model,
        :final command,
      ):
        return {
          ...base,
          'prompt': prompt,
          'description': description,
          'agent': agent,
          'model': model == null
              ? null
              : {'providerId': model.providerId, 'modelId': model.modelId},
          'command': command,
        };
      case RetryPart(:final attempt, :final createdAt, :final error):
        return {
          ...base,
          'attempt': attempt,
          'createdAt': _iso(createdAt),
          'error': {
            'message': error.message,
            'isRetryable': error.isRetryable,
            'statusCode': error.statusCode,
          },
        };
      case CompactionPart(:final auto):
        return {...base, 'auto': auto};
    }
    throw StateError('Unsupported message part type: ${part.runtimeType}');
  }

  Map<String, dynamic>? _tokensJson(MessageTokens? tokens) {
    if (tokens == null) {
      return null;
    }
    return {
      'input': tokens.input,
      'output': tokens.output,
      'reasoning': tokens.reasoning,
      'cacheRead': tokens.cacheRead,
      'cacheWrite': tokens.cacheWrite,
      'total': tokens.total,
    };
  }

  Map<String, dynamic>? _messageErrorJson(MessageError? error) {
    if (error == null) {
      return null;
    }
    return {
      'name': error.name,
      'message': error.message,
      'statusCode': error.statusCode,
      'isRetryable': error.isRetryable,
    };
  }

  Map<String, dynamic>? _fileSourceJson(FileSource? source) {
    if (source == null) {
      return null;
    }
    return {
      'path': source.path,
      'type': source.type,
      'text': _sourceTextJson(source.text),
    };
  }

  Map<String, dynamic>? _symbolSourceJson(SymbolSource? source) {
    if (source == null) {
      return null;
    }
    return {
      'name': source.name,
      'kind': source.kind,
      'path': source.path,
      'range': {
        'startLine': source.range.startLine,
        'startCharacter': source.range.startCharacter,
        'endLine': source.range.endLine,
        'endCharacter': source.range.endCharacter,
      },
      'text': _sourceTextJson(source.text),
    };
  }

  Map<String, dynamic> _sourceTextJson(FilePartSourceText text) {
    return {'value': text.value, 'start': text.start, 'end': text.end};
  }

  Map<String, dynamic>? _revertJson(SessionRevert? revert) {
    if (revert == null) {
      return null;
    }
    return {
      'messageId': revert.messageId,
      'partId': revert.partId,
      'snapshot': revert.snapshot,
      'diff': revert.diff,
    };
  }

  Map<String, dynamic>? _agentSourceJson(AgentSource? source) {
    if (source == null) {
      return null;
    }
    return {'value': source.value, 'start': source.start, 'end': source.end};
  }

  Map<String, dynamic> _toolStateJson(ToolState state) {
    final base = <String, dynamic>{'status': state.status.name};
    switch (state) {
      case ToolStatePending():
        return base;
      case ToolStateRunning(
        :final input,
        :final time,
        :final title,
        :final metadata,
      ):
        return {
          ...base,
          'input': _jsonSafe(input),
          'time': _iso(time),
          'title': title,
          'metadata': _jsonSafe(metadata),
        };
      case ToolStateCompleted(
        :final input,
        :final output,
        :final time,
        :final title,
        :final metadata,
      ):
        return {
          ...base,
          'input': _jsonSafe(input),
          'output': output,
          'time': {
            'start': _iso(time.start),
            'end': time.end == null ? null : _iso(time.end!),
          },
          'title': title,
          'metadata': _jsonSafe(metadata),
        };
      case ToolStateError(
        :final input,
        :final error,
        :final time,
        :final title,
        :final metadata,
      ):
        return {
          ...base,
          'input': _jsonSafe(input),
          'error': error,
          'time': {
            'start': _iso(time.start),
            'end': time.end == null ? null : _iso(time.end!),
          },
          'title': title,
          'metadata': _jsonSafe(metadata),
        };
    }
    throw StateError('Unsupported tool state type: ${state.runtimeType}');
  }

  Object? _jsonSafe(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) {
      return _iso(value);
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry('$key', _jsonSafe(val)));
    }
    return value.toString();
  }

  String _sessionTitle(ChatSession session) {
    final title = session.title?.trim();
    return title == null || title.isEmpty ? 'Untitled session' : title;
  }

  String? _officialId(String id) {
    return id.startsWith('local_user_') ? null : id;
  }

  String _iso(DateTime value) => value.toUtc().toIso8601String();

  String _yamlScalar(String value) {
    return jsonEncode(value);
  }

  String _blockquote(String value) {
    if (value.isEmpty) {
      return '> _Empty reasoning part._';
    }
    return value.split('\n').map((line) => '> $line').join('\n');
  }

  String _fencedJson(Object? value) {
    return _fenced(
      const JsonEncoder.withIndent('  ').convert(_jsonSafe(value)),
      language: 'json',
    );
  }

  String _fenced(String value, {String language = ''}) {
    final fence = value.contains('```') ? '~~~' : '```';
    return '$fence$language\n$value\n$fence\n';
  }
}
