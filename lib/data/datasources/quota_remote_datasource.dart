import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/quota.dart';
import '../../presentation/services/chat_title_generator.dart';

part 'quota_remote_datasource.part.js.dart';

abstract class QuotaRemoteDataSource {
  Future<List<QuotaProviderResult>> fetchQuotaResults();
}

class QuotaRemoteDataSourceImpl implements QuotaRemoteDataSource {
  QuotaRemoteDataSourceImpl({required this.dio});

  final Dio dio;

  static const String _shellPrefix = 'CW_QUOTA_JSON:';

  static const Set<String> _supportedAuthKeys = <String>{
    'anthropic',
    'claude',
    'openrouter',
    'openai',
    'codex',
    'chatgpt',
    'google',
    'google.oauth',
    'github-copilot',
    'copilot',
    'github-copilot-addon',
    'opencode-go',
    'nano-gpt',
    'nanogpt',
    'nano_gpt',
    'wafer',
    'wafer-ai',
    'wafer_ai',
    'wafer.ai',
    'kimi-for-coding',
    'kimi',
    'zhipuai-coding-plan',
    'zhipuai',
    'zhipu',
    'minimax-coding-plan',
    'minimax-cn-coding-plan',
    'zai-coding-plan',
    'zai',
    'z.ai',
    'cursor',
    'ollama-cloud',
    'ollamacloud',
    // OpenCode v1.16.2 (Snowflake Cortex) and v1.17.x (Grok/xAI, Cohere North).
    'snowflake-cortex',
    'snowflake',
    'cortex',
    'grok',
    'xai',
    'x-ai',
    'cohere',
    'cohere-north',
    'cohere-north-mini-code',
  };

  @override
  Future<List<QuotaProviderResult>> fetchQuotaResults() async {
    final viaRest = await _fetchViaOpenChamberRest();
    if (viaRest != null) {
      AppLogger.info('[Quota] REST path returned ${viaRest.length} results');
      return viaRest;
    }
    AppLogger.info('[Quota] REST path unavailable, trying shell fallback');
    return _fetchViaShellFallback();
  }

  Future<List<QuotaProviderResult>?> _fetchViaOpenChamberRest() async {
    try {
      final response = await dio.get<dynamic>('/api/quota/providers');
      if (response.statusCode != 200) {
        AppLogger.info(
          '[Quota] REST /api/quota/providers returned ${response.statusCode}',
        );
        return null;
      }
      final payload = response.data;
      if (payload is! Map) {
        AppLogger.info(
          '[Quota] REST payload is not a Map: ${payload.runtimeType}',
        );
        return null;
      }
      final providers =
          (payload['providers'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
      if (providers.isEmpty) {
        AppLogger.info('[Quota] REST returned empty providers list');
        return const <QuotaProviderResult>[];
      }
      AppLogger.info('[Quota] REST found providers: $providers');
      final results = await Future.wait(
        providers.map(_fetchQuotaForProviderRest),
      );
      return results.whereType<QuotaProviderResult>().toList(growable: false);
    } on DioException catch (error) {
      // Any DioException means the REST endpoint is not available on this
      // host.  Return null so the strategy chain falls through to the shell
      // fallback instead of silently returning an empty list.
      AppLogger.info(
        '[Quota] REST DioException (status=${error.response?.statusCode}): '
        '${error.type}',
      );
      return null;
    } catch (error) {
      AppLogger.info('[Quota] REST unexpected error: $error');
      return null;
    }
  }

  Future<QuotaProviderResult?> _fetchQuotaForProviderRest(
    String providerId,
  ) async {
    try {
      final response = await dio.get<dynamic>('/api/quota/$providerId');
      if (response.statusCode != 200) {
        return null;
      }
      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        return QuotaProviderResult.fromJson(payload);
      }
      if (payload is Map) {
        return QuotaProviderResult.fromJson(Map<String, dynamic>.from(payload));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<QuotaProviderResult>> _fetchViaShellFallback() async {
    String? sessionId;
    try {
      sessionId = await _createEphemeralSession();
      if (sessionId == null) {
        AppLogger.info('[Quota] Shell fallback: failed to create session');
        return const <QuotaProviderResult>[];
      }
      AppLogger.info('[Quota] Shell fallback: session $sessionId created');
      final response = await dio.post<dynamic>(
        '/session/$sessionId/shell',
        data: <String, dynamic>{
          'agent': 'build',
          'command': _buildQuotaShellCommand(),
        },
      );
      if (response.statusCode != 200 || response.data is! Map) {
        AppLogger.info(
          '[Quota] Shell fallback: bad response '
          '(status=${response.statusCode}, '
          'type=${response.data.runtimeType})',
        );
        return const <QuotaProviderResult>[];
      }
      final envelope = Map<String, dynamic>.from(response.data as Map);
      final output = _extractShellJsonPayload(envelope);
      if (output == null) {
        // Dump parts content for diagnosis.
        final parts = envelope['parts'] as List<dynamic>? ?? const <dynamic>[];
        for (var i = 0; i < parts.length; i++) {
          final part = parts[i];
          try {
            // Log top-level keys and state sub-keys separately.
            if (part is Map) {
              final m = Map<String, dynamic>.from(part);
              AppLogger.info(
                '[Quota] Shell parts[$i] keys: ${m.keys.toList()}',
              );
              final state = m['state'];
              if (state is Map) {
                final sm = Map<String, dynamic>.from(state);
                AppLogger.info(
                  '[Quota] Shell parts[$i].state keys: ${sm.keys.toList()}',
                );
                for (final entry in sm.entries) {
                  final val = entry.value;
                  if (val is String) {
                    AppLogger.info(
                      '[Quota] Shell parts[$i].state.${entry.key}: '
                      'String(length=${val.length})',
                    );
                  } else {
                    AppLogger.info(
                      '[Quota] Shell parts[$i].state.${entry.key}: '
                      '${val?.runtimeType ?? 'null'}',
                    );
                  }
                }
              } else {
                AppLogger.info(
                  '[Quota] Shell parts[$i].state: ${state?.runtimeType ?? "null"}',
                );
              }
            }
          } catch (e) {
            AppLogger.info('[Quota] Shell parts[$i]: dump error $e');
          }
        }
        AppLogger.info(
          '[Quota] Shell fallback: no CW_QUOTA_JSON found in response. '
          'Keys: ${envelope.keys.toList()}',
        );
        return const <QuotaProviderResult>[];
      }
      final decoded = jsonDecode(output);
      if (decoded is! Map) {
        AppLogger.info('[Quota] Shell fallback: decoded payload is not a Map');
        return const <QuotaProviderResult>[];
      }
      final results = decoded['results'] as List<dynamic>? ?? const <dynamic>[];
      final meta = decoded['meta'];
      if (meta is Map) {
        AppLogger.info(
          '[Quota] Shell fallback meta: ${Map<String, dynamic>.from(meta)}',
        );
      }
      AppLogger.info(
        '[Quota] Shell fallback: got ${results.length} raw results',
      );
      final parsedResults = results
          .whereType<Map>()
          .map(
            (item) =>
                QuotaProviderResult.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
      AppLogger.info(
        '[Quota] Shell fallback parsed results: ${parsedResults.map((item) => '${item.providerId}(ok=${item.ok}, configured=${item.configured}, visible=${item.hasVisibleData}, error=${item.error ?? '-'})').toList()}',
      );
      return parsedResults;
    } catch (error) {
      AppLogger.info('[Quota] Shell fallback error: $error');
      return const <QuotaProviderResult>[];
    } finally {
      if (sessionId != null) {
        try {
          await dio.delete<dynamic>('/session/$sessionId');
        } catch (_) {}
        final ephemeralId = sessionId;
        Future<void>.delayed(const Duration(seconds: 5), () {
          ChatTitleGenerator.ephemeralSessionIds.remove(ephemeralId);
        });
      }
    }
  }

  Future<String?> _createEphemeralSession() async {
    try {
      final response = await dio.post<dynamic>(
        '/session',
        data: <String, dynamic>{
          'title': ChatTitleGenerator.ephemeralSessionTitle,
        },
      );
      final map = response.data as Map<String, dynamic>?;
      final sessionId = map?['id'] as String?;
      if (sessionId == null || sessionId.trim().isEmpty) {
        return null;
      }
      ChatTitleGenerator.ephemeralSessionIds.add(sessionId);
      return sessionId;
    } catch (_) {
      return null;
    }
  }

  String? _extractShellJsonPayload(Map<String, dynamic> envelope) {
    final parts = envelope['parts'] as List<dynamic>? ?? const <dynamic>[];
    for (final part in parts) {
      if (part is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(part);
      // Search every string value in the part for the CW_QUOTA_JSON: prefix.
      // The OpenCode shell response may put output in 'text', 'result',
      // 'output', or nested inside the 'tool' object depending on version.
      final found = _searchStringValues(map);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  /// Recursively search all string values in [data] for a line starting with
  /// [_shellPrefix] and return the JSON payload after the prefix.
  String? _searchStringValues(Map<String, dynamic> data) {
    for (final value in data.values) {
      if (value is String && value.trim().isNotEmpty) {
        for (final line in value.split('\n').reversed) {
          final trimmed = line.trim();
          if (trimmed.startsWith(_shellPrefix)) {
            return trimmed.substring(_shellPrefix.length);
          }
        }
      } else if (value is Map) {
        final found = _searchStringValues(Map<String, dynamic>.from(value));
        if (found != null) {
          return found;
        }
      } else if (value is List) {
        for (final item in value) {
          if (item is Map) {
            final found = _searchStringValues(Map<String, dynamic>.from(item));
            if (found != null) {
              return found;
            }
          } else if (item is String && item.trim().isNotEmpty) {
            for (final line in item.split('\n').reversed) {
              final trimmed = line.trim();
              if (trimmed.startsWith(_shellPrefix)) {
                return trimmed.substring(_shellPrefix.length);
              }
            }
          }
        }
      }
    }
    return null;
  }

  String _buildQuotaShellCommand() {
    final supportedKeysLiteral = jsonEncode(_supportedAuthKeys.toList());

    final payload = StringBuffer()
      ..write(_jsSharedHelpers())
      ..write('\n')
      ..write(_jsClaudeProvider())
      ..write(_jsOpenRouterProvider())
      ..write(_jsCodexProvider())
      ..write(_jsGoogleProvider())
      ..write(_jsGitHubCopilotProvider())
      ..write(_jsOpenCodeGoProvider())
      ..write(_jsNanoGptProvider())
      ..write(_jsWaferProvider())
      ..write(_jsGitHubCopilotAddonProvider())
      ..write(_jsKimiForCodingProvider())
      ..write(_jsZhipuaiCodingPlanProvider())
      ..write(_jsMinimaxCodingPlanProvider())
      ..write(_jsMinimaxCnCodingPlanProvider())
      ..write(_jsZaiCodingPlanProvider())
      ..write(_jsCursorProvider())
      ..write(_jsOllamaCloudProvider())
      ..write(_jsDispatcher(supportedKeysLiteral: supportedKeysLiteral));

    final b64 = base64Encode(utf8.encode(payload.toString()));
    return "node -e \"eval(Buffer.from('$b64','base64').toString('utf8'))\""
        " || printf '%s\\n' '$_shellPrefix{\"results\":[]}'";
  }
}
