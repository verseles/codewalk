part of 'chat_remote_datasource.dart';

extension _ChatRemoteDataSourceCommandAndErrorHelpers
    on ChatRemoteDataSourceImpl {
  Future<ChatMessageModel> _sendShellCommand(
    String sessionId,
    ChatInputModel input, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      final command = input.parts
          .where((part) => part.type == 'text')
          .map((part) => part.text ?? '')
          .join('\n')
          .trim();
      if (command.isEmpty) {
        throw const ValidationException('Shell command cannot be empty');
      }

      final response = await dio.post(
        '/session/$sessionId/shell',
        data: <String, dynamic>{'agent': 'build', 'command': command},
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode != 200) {
        throw ServerException(
          L10nBridge.current?.errorRunShellCommandFailed ??
              'Failed to run shell command',
        );
      }

      final map = response.data as Map<String, dynamic>;
      final info = (map['info'] as Map<String, dynamic>?) ?? map;
      final parts = (map['parts'] as List<dynamic>?) ?? const <dynamic>[];
      return ChatMessageModel.fromJson({...info, 'parts': parts});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw NotFoundException(
          L10nBridge.current?.chatProviderErrorNotFound ?? 'Resource not found',
        );
      }
      if (e.response?.statusCode == 400) {
        throw ValidationException(
          L10nBridge.current?.chatProviderErrorInvalidInput ??
              'Invalid input parameters',
        );
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage:
            L10nBridge.current?.errorRunShellCommandFailed ??
            'Failed to run shell command',
      );
    } catch (e) {
      if (e is ValidationException) {
        rethrow;
      }
      throw ServerException(
        L10nBridge.current?.errorRunShellCommandFailed ??
            'Failed to run shell command',
      );
    }
  }

  Future<ChatMessageModel> _sendSlashCommand(
    String sessionId,
    ChatInputModel input, {
    String? directory,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (directory != null) {
        queryParams['directory'] = directory;
      }

      final rawCommand = input.parts
          .where((part) => part.type == 'text')
          .map((part) => part.text ?? '')
          .join('\n')
          .trim();
      final normalized = rawCommand.startsWith('/')
          ? rawCommand.substring(1).trimLeft()
          : rawCommand;
      if (normalized.isEmpty) {
        throw const ValidationException('Slash command cannot be empty');
      }

      final separatorMatch = RegExp(r'\s').firstMatch(normalized);
      final command =
          (separatorMatch == null
                  ? normalized
                  : normalized.substring(0, separatorMatch.start))
              .trim();
      if (command.isEmpty) {
        throw const ValidationException('Slash command cannot be empty');
      }
      final arguments = separatorMatch == null
          ? ''
          : normalized.substring(separatorMatch.start).trimLeft();

      final payload = <String, dynamic>{'command': command};
      if (arguments.isNotEmpty) {
        payload['arguments'] = arguments;
      }
      if (input.providerId.trim().isNotEmpty &&
          input.modelId.trim().isNotEmpty) {
        payload['model'] = <String, dynamic>{
          'providerID': input.providerId,
          'modelID': input.modelId,
        };
      }

      final response = await dio.post(
        '/session/$sessionId/command',
        data: payload,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.statusCode != 200) {
        throw ServerException(
          L10nBridge.current?.errorRunSlashCommandFailed ??
              'Failed to run slash command',
        );
      }

      final map = response.data as Map<String, dynamic>;
      final info = (map['info'] as Map<String, dynamic>?) ?? map;
      final parts = (map['parts'] as List<dynamic>?) ?? const <dynamic>[];
      return ChatMessageModel.fromJson({...info, 'parts': parts});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw NotFoundException(
          L10nBridge.current?.chatProviderErrorNotFound ?? 'Resource not found',
        );
      }
      if (e.response?.statusCode == 400) {
        throw ValidationException(
          L10nBridge.current?.chatProviderErrorInvalidInput ??
              'Invalid input parameters',
        );
      }
      throw _serverExceptionFromDio(
        e,
        fallbackMessage:
            L10nBridge.current?.errorRunSlashCommandFailed ??
            'Failed to run slash command',
      );
    } catch (e) {
      if (e is ValidationException) {
        rethrow;
      }
      throw ServerException(
        L10nBridge.current?.errorRunSlashCommandFailed ??
            'Failed to run slash command',
      );
    }
  }

  ServerException _serverExceptionFromDio(
    DioException exception, {
    required String fallbackMessage,
  }) {
    final statusCode = exception.response?.statusCode;
    final extractedMessage = _extractServerMessage(exception.response?.data);
    final message = extractedMessage.isEmpty
        ? _fallbackServerMessageForStatus(
            statusCode: statusCode,
            fallbackMessage: fallbackMessage,
          )
        : extractedMessage;
    return ServerException(message, statusCode);
  }

  String _fallbackServerMessageForStatus({
    required int? statusCode,
    required String fallbackMessage,
  }) {
    return switch (statusCode) {
      401 || 403 =>
        L10nBridge.current?.errorFormatAuthenticationFailedReconnect ??
            'Authentication failed. Reconnect the provider and try again.',
      409 =>
        L10nBridge.current?.errorSessionBusy ??
            'Session is busy processing another request.',
      429 =>
        L10nBridge.current?.errorFormatRateLimitExceeded ??
            'Rate limit exceeded. Wait a moment and try again.',
      // V2: explicit 503 — server explicitly unavailable (retryable)
      503 =>
        L10nBridge.current?.errorFormatServiceTemporarilyUnavailable ??
            'Service temporarily unavailable. The server may be starting up — please try again shortly.',
      _ when statusCode != null && statusCode >= 500 =>
        L10nBridge.current?.errorFormatProviderTemporarilyUnavailable ??
            'Provider temporarily unavailable. Try again shortly.',
      _ => fallbackMessage,
    };
  }

  String _extractValidationErrors(dynamic payload) {
    if (payload is! List) {
      return '';
    }
    final messages = <String>[];
    for (final item in payload) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final field = map['field']?.toString().trim();
        final message =
            map['message']?.toString().trim() ??
            map['detail']?.toString().trim() ??
            '';
        if (message.isEmpty) {
          continue;
        }
        messages.add(
          field != null && field.isNotEmpty ? '$field: $message' : message,
        );
        continue;
      }
      final message = item.toString().trim();
      if (message.isNotEmpty) {
        messages.add(message);
      }
    }
    return messages.join('; ');
  }

  ValidationException _validationExceptionFromDio(
    DioException exception, {
    required String fallbackMessage,
  }) {
    final extractedMessage = _extractServerMessage(exception.response?.data);
    if (extractedMessage.isNotEmpty) {
      return ValidationException(extractedMessage);
    }
    return ValidationException(fallbackMessage);
  }

  String _extractTypedDetails(dynamic payload) {
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final details = <String>[];
      for (final entry in map.entries) {
        final value = entry.value;
        if (value == null) {
          continue;
        }
        if (value is String) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) {
            details.add('${entry.key}=$trimmed');
          }
          continue;
        }
        if (value is num || value is bool) {
          details.add('${entry.key}=$value');
        }
      }
      return details.join(', ');
    }
    if (payload is List) {
      return payload.map((item) => item.toString().trim()).join(', ');
    }
    return payload?.toString().trim() ?? '';
  }

  String _composeTypedServerMessage({
    String? code,
    String? name,
    String? message,
    String? details,
  }) {
    final normalizedCode = code?.trim();
    final normalizedName = name?.trim();
    final normalizedMessage = message?.trim();
    final normalizedDetails = details?.trim();
    final prefix = <String>[
      if (normalizedName != null && normalizedName.isNotEmpty) normalizedName,
      if (normalizedCode != null && normalizedCode.isNotEmpty)
        '[${normalizedCode}]',
    ].join(' ');
    final body = <String>[
      if (normalizedMessage != null && normalizedMessage.isNotEmpty)
        normalizedMessage,
      if (normalizedDetails != null && normalizedDetails.isNotEmpty)
        '($normalizedDetails)',
    ].join(' ');
    if (prefix.isNotEmpty && body.isNotEmpty) {
      return '$prefix: $body';
    }
    if (body.isNotEmpty) {
      return body;
    }
    return prefix;
  }

  String _extractNamedServerError(Map<String, dynamic> map) {
    final name = map['name']?.toString().trim();
    final code = map['code']?.toString().trim();
    if ((name == null || name.isEmpty) && (code == null || code.isEmpty)) {
      return '';
    }

    final data = map['data'];
    final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;
    final dataMessage = dataMap?['message']?.toString().trim();
    final directMessage = map['message']?.toString().trim();
    final detail = map['detail']?.toString().trim();
    final details = <String, dynamic>{};
    final sourceDetails = map['details'] ?? map['meta'];
    if (sourceDetails is Map) {
      details.addAll(Map<String, dynamic>.from(sourceDetails));
    }
    if (dataMap != null) {
      details.addAll(dataMap);
    }
    details.remove('message');

    return _composeTypedServerMessage(
      code: code,
      name: name,
      message: dataMessage != null && dataMessage.isNotEmpty
          ? dataMessage
          : directMessage != null && directMessage.isNotEmpty
          ? directMessage
          : detail,
      details: _extractTypedDetails(details),
    );
  }

  String _extractServerMessage(dynamic payload) {
    if (payload == null) {
      return '';
    }
    if (payload is String) {
      final trimmed = payload.trim();
      if (trimmed.isEmpty) {
        return '';
      }
      try {
        final decoded = jsonDecode(trimmed);
        return _extractServerMessage(decoded);
      } catch (_) {
        return trimmed;
      }
    }
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final validationErrors = _extractValidationErrors(map['errors']);
      if (validationErrors.isNotEmpty) {
        return validationErrors;
      }
      final namedError = _extractNamedServerError(map);
      if (namedError.isNotEmpty) {
        return namedError;
      }
      final errorPayload = map['error'];
      final nestedError = _extractServerMessage(errorPayload);
      if (nestedError.isNotEmpty) {
        return nestedError;
      }
      final dataPayload = map['data'];
      final nestedData = _extractServerMessage(dataPayload);
      if (nestedData.isNotEmpty) {
        return nestedData;
      }
      final direct = map['message']?.toString().trim();
      final detail = map['detail']?.toString().trim();
      final typed = _composeTypedServerMessage(
        code: map['code']?.toString(),
        name: map['name']?.toString(),
        message: direct != null && direct.isNotEmpty ? direct : detail,
        details: _extractTypedDetails(map['details'] ?? map['meta']),
      );
      if (typed.isNotEmpty) {
        return typed;
      }
      return '';
    }
    return payload.toString().trim();
  }
}
