import 'package:dio/dio.dart';

import '../../core/logging/app_logger.dart';

class ChatTitleGeneratorMessage {
  const ChatTitleGeneratorMessage({required this.role, required this.text});

  final String role;
  final String text;
}

abstract class ChatTitleGenerator {
  Future<String?> generateTitle(
    List<ChatTitleGeneratorMessage> messages, {
    int maxWords,
  });
}

class ChatAtTitleGenerator implements ChatTitleGenerator {
  ChatAtTitleGenerator({Dio? dio})
    : _dio = dio ?? Dio(BaseOptions(baseUrl: 'https://ch.at'));

  final Dio _dio;

  static const int _maxTitleLength = 80;
  static const int _defaultMaxWords = 6;

  @override
  Future<String?> generateTitle(
    List<ChatTitleGeneratorMessage> messages, {
    int maxWords = _defaultMaxWords,
  }) async {
    if (messages.isEmpty) {
      return null;
    }

    final effectiveMaxWords = maxWords.clamp(1, 12).toInt();
    final prompt = _buildPrompt(messages, maxWords: effectiveMaxWords);
    try {
      final response = await _dio.post<dynamic>(
        '/v1/chat/completions',
        data: <String, dynamic>{
          'messages': <Map<String, String>>[
            const <String, String>{
              'role': 'system',
              'content':
                  'You generate concise conversation titles. Return only the final title text.',
            },
            <String, String>{'role': 'user', 'content': prompt},
          ],
        },
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final title = _extractTitle(response.data);
      if (title == null || title.isEmpty) {
        return null;
      }
      return _normalizeTitle(title);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'AI title generation failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  String _buildPrompt(
    List<ChatTitleGeneratorMessage> messages, {
    required int maxWords,
  }) {
    final lines = StringBuffer();
    for (var index = 0; index < messages.length; index += 1) {
      final message = messages[index];
      lines.writeln(
        '${index + 1}. ${message.role.toUpperCase()}: ${message.text}',
      );
    }

    return [
      'Based on the texts below, generate a title for this conversation with at most $_maxTitleLength characters.',
      'Use at most $maxWords words.',
      'Use plain text only, no quotes, no markdown.',
      lines.toString().trimRight(),
    ].join('\n\n');
  }

  String? _extractTitle(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final choices = raw['choices'];
    if (choices is! List || choices.isEmpty) {
      return null;
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      return null;
    }
    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      return null;
    }
    final content = message['content'];
    if (content is String) {
      return content;
    }
    if (content is List) {
      final parts = content
          .whereType<Map>()
          .map((item) => item['text'])
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (parts.isNotEmpty) {
        return parts.join(' ');
      }
    }
    return null;
  }

  String? _normalizeTitle(String raw) {
    var normalized = raw.trim();
    if (normalized.length >= 2 &&
        normalized.startsWith('"') &&
        normalized.endsWith('"')) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length > _maxTitleLength) {
      normalized = normalized.substring(0, _maxTitleLength).trimRight();
    }
    return normalized;
  }
}
