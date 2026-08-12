import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/path_utils.dart';
import 'chat_title_generator.dart';

enum WorkspaceFileOperationCode {
  ok,
  unavailable,
  invalidName,
  outsideRoot,
  rootDeleteBlocked,
  missing,
  alreadyExists,
  permissionDenied,
  notDirectory,
  failed,
  malformedResponse,
}

class WorkspaceFileOperationResult {
  const WorkspaceFileOperationResult({
    required this.ok,
    required this.code,
    required this.message,
    this.path,
    this.newPath,
  });

  final bool ok;
  final WorkspaceFileOperationCode code;
  final String message;
  final String? path;
  final String? newPath;

  WorkspaceFileOperationResult copyWith({String? path, String? newPath}) {
    return WorkspaceFileOperationResult(
      ok: ok,
      code: code,
      message: message,
      path: path ?? this.path,
      newPath: newPath ?? this.newPath,
    );
  }
}

class WorkspaceFileOperationsCapabilities {
  const WorkspaceFileOperationsCapabilities({
    required this.shellFileOpsSupported,
    required this.message,
  });

  final bool shellFileOpsSupported;
  final String message;
}

abstract class WorkspaceFileOperationsService {
  Future<WorkspaceFileOperationsCapabilities> getCapabilities({
    required String serverScopeKey,
    required String directory,
  });

  Future<void> invalidateCapabilities({
    required String serverScopeKey,
    required String directory,
  });

  Future<WorkspaceFileOperationResult> createFile({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  });

  Future<WorkspaceFileOperationResult> createFolder({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  });

  Future<WorkspaceFileOperationResult> rename({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String oldName,
    required String newName,
  });

  Future<WorkspaceFileOperationResult> duplicateFile({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String sourceName,
    required String destinationName,
  });

  Future<WorkspaceFileOperationResult> delete({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  });

  Future<WorkspaceFileOperationResult> writeFile({
    required String serverScopeKey,
    required String rootDirectory,
    required String path,
    required String content,
  });
}

class WorkspaceFileOperationsServiceImpl
    implements WorkspaceFileOperationsService {
  WorkspaceFileOperationsServiceImpl({required Dio dio}) : _dio = dio;

  static const String _shellPrefix = 'CW_FILE_OP_JSON:';
  static const int _contentEnvironmentChunkSize = 48 * 1024;
  static const List<String> _shellDecoders = <String>[
    'base64 -d',
    'base64 -D',
    'base64 --decode',
    "python3 -c 'import base64,sys;sys.stdout.buffer.write(base64.b64decode(sys.stdin.buffer.read()))'",
  ];

  final Dio _dio;
  final Map<String, WorkspaceFileOperationsCapabilities> _capabilityCache =
      <String, WorkspaceFileOperationsCapabilities>{};
  final Map<String, String> _shellDecoderCache = <String, String>{};

  @override
  Future<WorkspaceFileOperationsCapabilities> getCapabilities({
    required String serverScopeKey,
    required String directory,
  }) {
    return _getCapabilities(
      serverScopeKey: serverScopeKey,
      directory: directory,
      baseUrl: _dio.options.baseUrl,
    );
  }

  Future<WorkspaceFileOperationsCapabilities> _getCapabilities({
    required String serverScopeKey,
    required String directory,
    required String baseUrl,
  }) async {
    if (_isUnsafeRoot(directory)) {
      return WorkspaceFileOperationsCapabilities(
        shellFileOpsSupported: false,
        message:
            L10nBridge.current?.filesActiveProjectRequired ??
            'File operations require an active project directory.',
      );
    }
    final key = _capabilityKey(serverScopeKey, directory);
    final cached = _capabilityCache[key];
    if (cached != null) {
      return cached;
    }

    WorkspaceFileOperationResult? result;
    for (final decoder in _shellDecoders) {
      result = await _runShellScript(
        directory: normalizeFilePath(directory),
        command: _buildProbeCommand(decoder),
        baseUrl: baseUrl,
      );
      if (result.ok) {
        _shellDecoderCache[key] = decoder;
        break;
      }
      if (result.code == WorkspaceFileOperationCode.outsideRoot) {
        break;
      }
    }
    result ??= _result(WorkspaceFileOperationCode.unavailable);
    final capabilities = WorkspaceFileOperationsCapabilities(
      shellFileOpsSupported: result.ok,
      message: result.message,
    );
    if (!_isBoundBaseUrlActive(baseUrl)) {
      return capabilities;
    }
    _capabilityCache[key] = capabilities;
    return capabilities;
  }

  @override
  Future<void> invalidateCapabilities({
    required String serverScopeKey,
    required String directory,
  }) async {
    final key = _capabilityKey(serverScopeKey, directory);
    _capabilityCache.remove(key);
    _shellDecoderCache.remove(key);
  }

  @override
  Future<WorkspaceFileOperationResult> createFile({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  }) async {
    final baseUrl = _dio.options.baseUrl;
    final prepared = await _prepareLeafOperation(
      serverScopeKey: serverScopeKey,
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
      baseUrl: baseUrl,
    );
    if (prepared.result != null) {
      return prepared.result!;
    }

    final target = _joinPath(prepared.parentDirectory, prepared.name);
    return _runMutation(
      serverScopeKey: serverScopeKey,
      rootDirectory: prepared.rootDirectory,
      commandBuilder: (decoder) => _buildCreateFileCommand(
        rootDirectory: prepared.rootDirectory,
        parentDirectory: prepared.parentDirectory,
        name: prepared.name,
        decoder: decoder,
      ),
      path: target,
      baseUrl: baseUrl,
    );
  }

  @override
  Future<WorkspaceFileOperationResult> createFolder({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  }) async {
    final baseUrl = _dio.options.baseUrl;
    final prepared = await _prepareLeafOperation(
      serverScopeKey: serverScopeKey,
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
      baseUrl: baseUrl,
    );
    if (prepared.result != null) {
      return prepared.result!;
    }

    final target = _joinPath(prepared.parentDirectory, prepared.name);
    return _runMutation(
      serverScopeKey: serverScopeKey,
      rootDirectory: prepared.rootDirectory,
      commandBuilder: (decoder) => _buildCreateFolderCommand(
        rootDirectory: prepared.rootDirectory,
        parentDirectory: prepared.parentDirectory,
        name: prepared.name,
        decoder: decoder,
      ),
      path: target,
      baseUrl: baseUrl,
    );
  }

  @override
  Future<WorkspaceFileOperationResult> rename({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String oldName,
    required String newName,
  }) async {
    final baseUrl = _dio.options.baseUrl;
    final preparedOld = _normalizeLeafName(oldName);
    if (preparedOld.result != null) {
      return preparedOld.result!;
    }
    final preparedNew = _normalizeLeafName(newName);
    if (preparedNew.result != null) {
      return preparedNew.result!;
    }

    final root = normalizeFilePath(rootDirectory);
    final parent = normalizeFilePath(parentDirectory);
    final rootCheck = _validateRootParent(rootDirectory: root, parent: parent);
    if (rootCheck != null) {
      return rootCheck;
    }

    final source = _joinPath(parent, preparedOld.name);
    final destination = _joinPath(parent, preparedNew.name);
    if (normalizeFilePath(source) == normalizeFilePath(root)) {
      return _result(WorkspaceFileOperationCode.rootDeleteBlocked);
    }

    return _runMutation(
      serverScopeKey: serverScopeKey,
      rootDirectory: root,
      commandBuilder: (decoder) => _buildRenameCommand(
        rootDirectory: root,
        parentDirectory: parent,
        oldName: preparedOld.name,
        newName: preparedNew.name,
        decoder: decoder,
      ),
      path: source,
      newPath: destination,
      baseUrl: baseUrl,
    );
  }

  @override
  Future<WorkspaceFileOperationResult> duplicateFile({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String sourceName,
    required String destinationName,
  }) async {
    final baseUrl = _dio.options.baseUrl;
    final preparedSource = _normalizeLeafName(sourceName);
    if (preparedSource.result != null) {
      return preparedSource.result!;
    }
    final preparedDestination = _normalizeLeafName(destinationName);
    if (preparedDestination.result != null) {
      return preparedDestination.result!;
    }

    final root = normalizeFilePath(rootDirectory);
    final parent = normalizeFilePath(parentDirectory);
    final rootCheck = _validateRootParent(rootDirectory: root, parent: parent);
    if (rootCheck != null) {
      return rootCheck;
    }

    final source = _joinPath(parent, preparedSource.name);
    final destination = _joinPath(parent, preparedDestination.name);
    return _runMutation(
      serverScopeKey: serverScopeKey,
      rootDirectory: root,
      commandBuilder: (decoder) => _buildDuplicateFileCommand(
        rootDirectory: root,
        parentDirectory: parent,
        sourceName: preparedSource.name,
        destinationName: preparedDestination.name,
        decoder: decoder,
      ),
      path: source,
      newPath: destination,
      baseUrl: baseUrl,
    );
  }

  @override
  Future<WorkspaceFileOperationResult> delete({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  }) async {
    final baseUrl = _dio.options.baseUrl;
    final prepared = await _prepareLeafOperation(
      serverScopeKey: serverScopeKey,
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
      checkCapabilities: false,
      baseUrl: baseUrl,
    );
    if (prepared.result != null) {
      return prepared.result!;
    }

    final target = _joinPath(prepared.parentDirectory, prepared.name);
    if (normalizeFilePath(target) ==
        normalizeFilePath(prepared.rootDirectory)) {
      return _result(WorkspaceFileOperationCode.rootDeleteBlocked);
    }

    final capabilities = await _getCapabilities(
      serverScopeKey: serverScopeKey,
      directory: prepared.rootDirectory,
      baseUrl: baseUrl,
    );
    if (!capabilities.shellFileOpsSupported) {
      return _result(
        WorkspaceFileOperationCode.unavailable,
        message: capabilities.message,
      );
    }

    return _runMutation(
      serverScopeKey: serverScopeKey,
      rootDirectory: prepared.rootDirectory,
      commandBuilder: (decoder) => _buildDeleteCommand(
        rootDirectory: prepared.rootDirectory,
        parentDirectory: prepared.parentDirectory,
        name: prepared.name,
        decoder: decoder,
      ),
      path: target,
      baseUrl: baseUrl,
    );
  }

  @override
  Future<WorkspaceFileOperationResult> writeFile({
    required String serverScopeKey,
    required String rootDirectory,
    required String path,
    required String content,
  }) async {
    final baseUrl = _dio.options.baseUrl;
    final prepared = await _preparePathOperation(
      serverScopeKey: serverScopeKey,
      rootDirectory: rootDirectory,
      path: path,
      baseUrl: baseUrl,
    );
    if (prepared.result != null) {
      return prepared.result!;
    }

    final target = _joinPath(prepared.parentDirectory, prepared.name);
    return _runMutation(
      serverScopeKey: serverScopeKey,
      rootDirectory: prepared.rootDirectory,
      commandBuilder: (decoder) => _buildWriteFileCommand(
        rootDirectory: prepared.rootDirectory,
        parentDirectory: prepared.parentDirectory,
        name: prepared.name,
        contentBase64: base64Encode(utf8.encode(content)),
        decoder: decoder,
      ),
      path: target,
      baseUrl: baseUrl,
    );
  }

  Future<WorkspaceFileOperationResult> _runMutation({
    required String serverScopeKey,
    required String rootDirectory,
    required String Function(String decoder) commandBuilder,
    required String baseUrl,
    String? path,
    String? newPath,
  }) async {
    final capabilities = await _getCapabilities(
      serverScopeKey: serverScopeKey,
      directory: rootDirectory,
      baseUrl: baseUrl,
    );
    if (!capabilities.shellFileOpsSupported) {
      return _result(
        WorkspaceFileOperationCode.unavailable,
        message: capabilities.message,
      );
    }
    final decoder =
        _shellDecoderCache[_capabilityKey(serverScopeKey, rootDirectory)];
    if (decoder == null) {
      return _result(WorkspaceFileOperationCode.unavailable);
    }

    final result = await _runShellScript(
      directory: rootDirectory,
      command: commandBuilder(decoder),
      baseUrl: baseUrl,
    );
    if (!result.ok) {
      AppLogger.warn(
        'Workspace file operation failed',
        tags: const <String>{'files'},
        metrics: <String, Object?>{
          'code': result.code.name,
          'pathHash': path == null ? null : AppLogger.safeContextId(path),
          'newPathHash': newPath == null
              ? null
              : AppLogger.safeContextId(newPath),
        },
      );
    }
    if (result.code == WorkspaceFileOperationCode.unavailable ||
        result.code == WorkspaceFileOperationCode.malformedResponse) {
      await invalidateCapabilities(
        serverScopeKey: serverScopeKey,
        directory: rootDirectory,
      );
    }
    return result.copyWith(path: path, newPath: newPath);
  }

  Future<_PreparedLeafOperation> _prepareLeafOperation({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String name,
    required String baseUrl,
    bool checkCapabilities = true,
  }) async {
    final preparedName = _normalizeLeafName(name);
    if (preparedName.result != null) {
      return _PreparedLeafOperation(result: preparedName.result!);
    }

    final root = normalizeFilePath(rootDirectory);
    final parent = normalizeFilePath(parentDirectory);
    final rootCheck = _validateRootParent(rootDirectory: root, parent: parent);
    if (rootCheck != null) {
      return _PreparedLeafOperation(result: rootCheck);
    }

    if (checkCapabilities) {
      final capabilities = await _getCapabilities(
        serverScopeKey: serverScopeKey,
        directory: root,
        baseUrl: baseUrl,
      );
      if (!capabilities.shellFileOpsSupported) {
        return _PreparedLeafOperation(
          result: _result(
            WorkspaceFileOperationCode.unavailable,
            message: capabilities.message,
          ),
        );
      }
    }

    return _PreparedLeafOperation(
      rootDirectory: root,
      parentDirectory: parent,
      name: preparedName.name,
    );
  }

  Future<_PreparedLeafOperation> _preparePathOperation({
    required String serverScopeKey,
    required String rootDirectory,
    required String path,
    required String baseUrl,
  }) async {
    final root = normalizeFilePath(rootDirectory);
    final normalizedPath = normalizeFilePath(path);
    if (normalizedPath.isEmpty || _hasUnsafePathTraversal(normalizedPath)) {
      return _PreparedLeafOperation(
        result: _result(WorkspaceFileOperationCode.outsideRoot),
      );
    }

    final target = normalizedPath.startsWith('/')
        ? normalizedPath
        : _joinPath(root, normalizedPath);
    if (normalizeFilePath(target) == root) {
      return _PreparedLeafOperation(
        result: _result(WorkspaceFileOperationCode.rootDeleteBlocked),
      );
    }
    final name = fileBasename(target);
    final preparedName = _normalizeLeafName(name);
    if (preparedName.result != null) {
      return _PreparedLeafOperation(result: preparedName.result!);
    }

    final parent = _parentPath(target);
    final rootCheck = _validateRootParent(rootDirectory: root, parent: parent);
    if (rootCheck != null) {
      return _PreparedLeafOperation(result: rootCheck);
    }

    final capabilities = await _getCapabilities(
      serverScopeKey: serverScopeKey,
      directory: root,
      baseUrl: baseUrl,
    );
    if (!capabilities.shellFileOpsSupported) {
      return _PreparedLeafOperation(
        result: _result(
          WorkspaceFileOperationCode.unavailable,
          message: capabilities.message,
        ),
      );
    }

    return _PreparedLeafOperation(
      rootDirectory: root,
      parentDirectory: parent,
      name: preparedName.name,
    );
  }

  _PreparedLeafName _normalizeLeafName(String raw) {
    final value = raw.trim();
    if (value.isEmpty ||
        value == '.' ||
        value == '..' ||
        value.contains('/') ||
        value.contains('\\') ||
        value.contains('\x00') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return _PreparedLeafName(
        result: _result(WorkspaceFileOperationCode.invalidName),
      );
    }
    return _PreparedLeafName(name: value);
  }

  WorkspaceFileOperationResult? _validateRootParent({
    required String rootDirectory,
    required String parent,
  }) {
    if (rootDirectory.isEmpty || parent.isEmpty) {
      return _result(WorkspaceFileOperationCode.missing);
    }
    if (_isUnsafeRoot(rootDirectory)) {
      return _result(WorkspaceFileOperationCode.outsideRoot);
    }
    if (!_isPathUnderRoot(rootDirectory, parent)) {
      return _result(WorkspaceFileOperationCode.outsideRoot);
    }
    return null;
  }

  bool _isPathUnderRoot(String rootDirectory, String candidate) {
    final root = normalizeFilePath(rootDirectory);
    final value = normalizeFilePath(candidate);
    return value == root || value.startsWith('$root/');
  }

  bool _isUnsafeRoot(String directory) {
    final normalized = normalizeFilePath(directory);
    return normalized.isEmpty || normalized == '/';
  }

  String _joinPath(String parent, String name) {
    final normalizedParent = normalizeFilePath(parent);
    if (normalizedParent == '/') {
      return '/$name';
    }
    return normalizeFilePath(joinParentPath(normalizedParent, name));
  }

  String _parentPath(String path) {
    final normalized = normalizeFilePath(path);
    if (normalized.isEmpty || normalized == '/') {
      return '/';
    }
    final separator = normalized.lastIndexOf('/');
    if (separator <= 0) {
      return '/';
    }
    return normalized.substring(0, separator);
  }

  bool _hasUnsafePathTraversal(String path) {
    if (path.contains('\x00') || path.contains('\n') || path.contains('\r')) {
      return true;
    }
    return normalizeFilePath(path).split('/').any((segment) => segment == '..');
  }

  Future<WorkspaceFileOperationResult> _runShellScript({
    required String directory,
    required String command,
    required String baseUrl,
  }) async {
    if (!_isBoundBaseUrlActive(baseUrl)) {
      return _result(WorkspaceFileOperationCode.unavailable);
    }
    String? sessionId;
    try {
      sessionId = await _createEphemeralSession(
        directory: directory,
        baseUrl: baseUrl,
      );
      if (sessionId == null) {
        return _result(WorkspaceFileOperationCode.unavailable);
      }
      if (!_isBoundBaseUrlActive(baseUrl)) {
        return _result(WorkspaceFileOperationCode.unavailable);
      }

      final response = await _dio.post<dynamic>(
        _boundRequestPath(baseUrl, '/session/$sessionId/shell'),
        data: <String, dynamic>{'agent': 'build', 'command': command},
        queryParameters: <String, String>{'directory': directory},
      );
      if (response.statusCode != 200 || response.data is! Map) {
        return _result(WorkspaceFileOperationCode.failed);
      }
      final envelope = Map<String, dynamic>.from(response.data as Map);
      final payload = extractSentinelPayload(envelope);
      if (payload == null) {
        return _result(
          WorkspaceFileOperationCode.malformedResponse,
          message: extractShellFailureMessage(envelope),
        );
      }
      return parseSentinelPayload(payload);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return _result(WorkspaceFileOperationCode.unavailable);
      }
      return _result(WorkspaceFileOperationCode.failed);
    } catch (_) {
      return _result(WorkspaceFileOperationCode.failed);
    } finally {
      if (sessionId != null && _isBoundBaseUrlActive(baseUrl)) {
        try {
          await _dio.delete<dynamic>(
            _boundRequestPath(baseUrl, '/session/$sessionId'),
            queryParameters: <String, String>{'directory': directory},
          );
        } catch (_) {}
        final ephemeralId = sessionId;
        Future<void>.delayed(const Duration(seconds: 5), () {
          ChatTitleGenerator.ephemeralSessionIds.remove(ephemeralId);
        });
      }
    }
  }

  Future<String?> _createEphemeralSession({
    required String directory,
    required String baseUrl,
  }) async {
    final response = await _dio.post<dynamic>(
      _boundRequestPath(baseUrl, '/session'),
      data: <String, dynamic>{
        'title': ChatTitleGenerator.ephemeralSessionTitle,
      },
      queryParameters: <String, String>{'directory': directory},
    );
    final data = response.data;
    if (data is! Map) {
      return null;
    }
    final sessionId = data['id'] as String?;
    if (sessionId == null || sessionId.trim().isEmpty) {
      return null;
    }
    ChatTitleGenerator.ephemeralSessionIds.add(sessionId);
    return sessionId;
  }

  String _boundRequestPath(String baseUrl, String path) {
    final normalizedBase = baseUrl.trim();
    if (normalizedBase.isEmpty) {
      return path;
    }
    return '${normalizedBase.replaceFirst(RegExp(r'/+$'), '')}$path';
  }

  bool _isBoundBaseUrlActive(String baseUrl) {
    return _dio.options.baseUrl.trim() == baseUrl.trim();
  }

  String _capabilityKey(String serverScopeKey, String directory) {
    return '$serverScopeKey::${normalizeFilePath(directory)}';
  }

  @visibleForTesting
  static String? extractSentinelPayload(Map<String, dynamic> envelope) {
    final officialOutputs = <String>[];
    final parts = envelope['parts'];
    if (parts is List) {
      for (final part in parts) {
        if (part is! Map) {
          continue;
        }
        final state = part['state'];
        if (state is! Map) {
          continue;
        }
        final output = state['output'];
        if (output is String && output.isNotEmpty) {
          officialOutputs.add(output);
          continue;
        }
        final metadata = state['metadata'];
        if (metadata is Map) {
          final metadataOutput = metadata['output'];
          if (metadataOutput is String && metadataOutput.isNotEmpty) {
            officialOutputs.add(metadataOutput);
          }
        }
      }
    }

    final officialPayload = _lastValidSentinelPayload(officialOutputs);
    if (officialPayload != null) {
      return officialPayload;
    }

    final legacyStrings = <String>[];
    _collectStringValues(envelope, legacyStrings);
    return _lastValidSentinelPayload(legacyStrings);
  }

  @visibleForTesting
  static String extractShellFailureMessage(Map<String, dynamic> envelope) {
    final parts = envelope['parts'];
    if (parts is List) {
      for (final part in parts.reversed) {
        if (part is! Map) {
          continue;
        }
        final state = part['state'];
        if (state is! Map) {
          continue;
        }
        final status = state['status'];
        if (status == 'error') {
          return _safeShellFailureMessage(state['error']);
        }
        if (status == 'pending' || status == 'running') {
          return L10nBridge.current?.filesShellCommandDidNotComplete ??
              'File operation shell command did not complete.';
        }
      }
    }

    final info = envelope['info'];
    if (info is Map) {
      final error = info['error'];
      if (error is Map) {
        final data = error['data'];
        if (data is Map && data['message'] != null) {
          return _safeShellFailureMessage(data['message']);
        }
      }
    }

    return L10nBridge.current?.filesShellCommandNoResult ??
        'File operation shell command returned no result.';
  }

  static String _safeShellFailureMessage(dynamic raw) {
    final normalized = raw is String ? raw.trim().toLowerCase() : '';
    if (normalized.contains('unexpected end of file') ||
        normalized.contains('unexpected eof')) {
      return L10nBridge.current?.filesShellCommandTruncated ??
          'File operation shell command was truncated by the server.';
    }
    if (normalized.contains('syntax error')) {
      return L10nBridge.current?.filesShellCommandSyntaxError ??
          'File operation shell command failed with a syntax error.';
    }
    if (normalized.contains('not found')) {
      return L10nBridge.current?.filesShellUtilityNotFound ??
          'A required shell utility was not found.';
    }
    return L10nBridge.current?.filesShellCommandFailed ??
        'File operation shell command failed before returning a result.';
  }

  static String? _lastValidSentinelPayload(Iterable<String> values) {
    String? lastPayload;
    final combined = StringBuffer();
    for (final value in values) {
      combined.write(value);
      for (final line in value.split('\n')) {
        final payload = _sentinelPayloadFromLine(line);
        if (payload != null && _isValidSentinelPayload(payload)) {
          lastPayload = payload;
        }
      }
    }
    for (final line in combined.toString().split('\n')) {
      final payload = _sentinelPayloadFromLine(line);
      if (payload != null && _isValidSentinelPayload(payload)) {
        lastPayload = payload;
      }
    }
    return lastPayload;
  }

  static String? _sentinelPayloadFromLine(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith(_shellPrefix)) {
      return null;
    }
    return trimmed.substring(_shellPrefix.length);
  }

  static bool _isValidSentinelPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map &&
          decoded['code'] is String &&
          _codeFromWire(decoded['code'] as String?) != null;
    } catch (_) {
      return false;
    }
  }

  static void _collectStringValues(dynamic data, List<String> values) {
    if (data is String && data.trim().isNotEmpty) {
      values.add(data);
      return;
    }
    if (data is Map) {
      for (final value in data.values) {
        _collectStringValues(value, values);
      }
      return;
    }
    if (data is List) {
      for (final value in data) {
        _collectStringValues(value, values);
      }
    }
  }

  @visibleForTesting
  static WorkspaceFileOperationResult parseSentinelPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return _result(WorkspaceFileOperationCode.malformedResponse);
      }
      final map = Map<String, dynamic>.from(decoded);
      final code = _codeFromWire(map['code'] as String?);
      if (code == null) {
        return _result(WorkspaceFileOperationCode.malformedResponse);
      }
      final ok = map['ok'] == true && code == WorkspaceFileOperationCode.ok;
      final message = map['message'] as String? ?? _defaultMessage(code);
      return WorkspaceFileOperationResult(
        ok: ok,
        code: code,
        message: message,
        path: map['path'] as String?,
        newPath: map['newPath'] as String?,
      );
    } catch (_) {
      return _result(WorkspaceFileOperationCode.malformedResponse);
    }
  }

  static WorkspaceFileOperationCode? _codeFromWire(String? raw) {
    switch (raw) {
      case 'ok':
        return WorkspaceFileOperationCode.ok;
      case 'unavailable':
        return WorkspaceFileOperationCode.unavailable;
      case 'invalidName':
        return WorkspaceFileOperationCode.invalidName;
      case 'outsideRoot':
        return WorkspaceFileOperationCode.outsideRoot;
      case 'rootDeleteBlocked':
        return WorkspaceFileOperationCode.rootDeleteBlocked;
      case 'missing':
        return WorkspaceFileOperationCode.missing;
      case 'alreadyExists':
        return WorkspaceFileOperationCode.alreadyExists;
      case 'permissionDenied':
        return WorkspaceFileOperationCode.permissionDenied;
      case 'notDirectory':
        return WorkspaceFileOperationCode.notDirectory;
      case 'failed':
        return WorkspaceFileOperationCode.failed;
      case 'malformedResponse':
        return WorkspaceFileOperationCode.malformedResponse;
    }
    return null;
  }

  static WorkspaceFileOperationResult _result(
    WorkspaceFileOperationCode code, {
    String? message,
  }) {
    return WorkspaceFileOperationResult(
      ok: code == WorkspaceFileOperationCode.ok,
      code: code,
      message: message ?? _defaultMessage(code),
    );
  }

  static String _defaultMessage(WorkspaceFileOperationCode code) {
    final l10n = L10nBridge.current;
    switch (code) {
      case WorkspaceFileOperationCode.ok:
        return 'ok';
      case WorkspaceFileOperationCode.unavailable:
        return l10n?.filesOperationUnavailable ??
            'File operations are not available for this server.';
      case WorkspaceFileOperationCode.invalidName:
        return l10n?.filesInvalidName ??
            'Enter a valid name without path separators.';
      case WorkspaceFileOperationCode.outsideRoot:
        return l10n?.filesOutsideRoot ??
            'The path is outside the project root.';
      case WorkspaceFileOperationCode.rootDeleteBlocked:
        return l10n?.filesRootDeleteBlocked ??
            'The project root cannot be deleted.';
      case WorkspaceFileOperationCode.missing:
        return l10n?.filesPathMissing ?? 'Path does not exist.';
      case WorkspaceFileOperationCode.alreadyExists:
        return l10n?.filesAlreadyExists ??
            'A file or folder with that name already exists.';
      case WorkspaceFileOperationCode.permissionDenied:
        return l10n?.filesPermissionDenied ?? 'Permission denied.';
      case WorkspaceFileOperationCode.notDirectory:
        return l10n?.filesParentNotDirectory ?? 'Parent is not a directory.';
      case WorkspaceFileOperationCode.failed:
        return l10n?.filesOperationFailed ?? 'File operation failed.';
      case WorkspaceFileOperationCode.malformedResponse:
        return l10n?.filesMalformedResponse ??
            'File operation returned an invalid response.';
    }
  }

  @visibleForTesting
  static String buildProbeCommandForTest() =>
      _buildProbeCommand(_shellDecoders.first);

  static String _buildProbeCommand(String decoder) {
    return _singleShellCommand(
      script:
          "root=\$(pwd -P 2>/dev/null || printf /)\nif [ \"\$root\" = / ]; then\n  printf '%s\\n' '$_shellPrefix{\"ok\":false,\"code\":\"outsideRoot\",\"message\":\"Path is outside the project root.\"}'\nelse\n  printf '%s\\n' '$_shellPrefix{\"ok\":true,\"code\":\"ok\",\"message\":\"shell file operations available\"}'\nfi\n",
      decoder: decoder,
    );
  }

  @visibleForTesting
  static String shellQuoteForTest(String value) => _shQuote(value);

  static String _shQuote(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  @visibleForTesting
  String buildCreateFileCommandForTest({
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  }) {
    return _buildCreateFileCommand(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
      decoder: _shellDecoders.first,
    );
  }

  @visibleForTesting
  String buildDeleteCommandForTest({
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  }) {
    return _buildDeleteCommand(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
      decoder: _shellDecoders.first,
    );
  }

  @visibleForTesting
  String buildDuplicateFileCommandForTest({
    required String rootDirectory,
    required String parentDirectory,
    required String sourceName,
    required String destinationName,
  }) {
    return _buildDuplicateFileCommand(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      sourceName: sourceName,
      destinationName: destinationName,
      decoder: _shellDecoders.first,
    );
  }

  @visibleForTesting
  String buildWriteFileCommandForTest({
    required String rootDirectory,
    required String parentDirectory,
    required String name,
    required String content,
  }) {
    return _buildWriteFileCommand(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
      contentBase64: base64Encode(utf8.encode(content)),
      decoder: _shellDecoders.first,
    );
  }

  String _buildCreateFileCommand({
    required String rootDirectory,
    required String parentDirectory,
    required String name,
    required String decoder,
  }) {
    return _buildScript(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
      decoder: decoder,
      body: r'''
cw_validate_name "$CW_NAME"
cw_prepare_parent
target="$parent/$CW_NAME"
if [ -e "$target" ] || [ -L "$target" ]; then cw_fail alreadyExists; fi
if ! [ -w "$parent" ]; then cw_fail permissionDenied; fi
if : > "$target" 2>/dev/null; then cw_ok; fi
cw_fail failed
''',
    );
  }

  String _buildCreateFolderCommand({
    required String rootDirectory,
    required String parentDirectory,
    required String name,
    required String decoder,
  }) {
    return _buildScript(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
      decoder: decoder,
      body: r'''
cw_validate_name "$CW_NAME"
cw_prepare_parent
target="$parent/$CW_NAME"
if [ -e "$target" ] || [ -L "$target" ]; then cw_fail alreadyExists; fi
if ! [ -w "$parent" ]; then cw_fail permissionDenied; fi
if mkdir -- "$target" 2>/dev/null; then cw_ok; fi
cw_fail failed
''',
    );
  }

  String _buildRenameCommand({
    required String rootDirectory,
    required String parentDirectory,
    required String oldName,
    required String newName,
    required String decoder,
  }) {
    return _buildScript(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: oldName,
      newName: newName,
      decoder: decoder,
      body: r'''
cw_validate_name "$CW_NAME"
cw_validate_name "$CW_NEW_NAME"
cw_prepare_parent
source="$parent/$CW_NAME"
destination="$parent/$CW_NEW_NAME"
if [ "$source" = "$root" ]; then cw_fail rootDeleteBlocked; fi
if ! [ -e "$source" ] && ! [ -L "$source" ]; then cw_fail missing; fi
if [ -e "$destination" ] || [ -L "$destination" ]; then cw_fail alreadyExists; fi
if ! [ -w "$parent" ]; then cw_fail permissionDenied; fi
if mv -- "$source" "$destination" 2>/dev/null; then cw_ok; fi
cw_fail failed
''',
    );
  }

  String _buildDuplicateFileCommand({
    required String rootDirectory,
    required String parentDirectory,
    required String sourceName,
    required String destinationName,
    required String decoder,
  }) {
    return _buildScript(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: sourceName,
      newName: destinationName,
      decoder: decoder,
      body: r'''
cw_validate_name "$CW_NAME"
cw_validate_name "$CW_NEW_NAME"
cw_prepare_parent
source="$parent/$CW_NAME"
destination="$parent/$CW_NEW_NAME"
if [ "$source" = "$root" ]; then cw_fail rootDeleteBlocked; fi
if ! [ -e "$source" ] && ! [ -L "$source" ]; then cw_fail missing; fi
if [ -d "$source" ] || [ -L "$source" ]; then cw_fail failed; fi
if [ -e "$destination" ] || [ -L "$destination" ]; then cw_fail alreadyExists; fi
if ! [ -r "$source" ] || ! [ -w "$parent" ]; then cw_fail permissionDenied; fi
tmpdir=$(mktemp -d "$parent/.cw-copy.XXXXXX" 2>/dev/null) || cw_fail failed
tmp="$tmpdir/content"
if cp -p -- "$source" "$tmp" 2>/dev/null; then
  if ln -- "$tmp" "$destination" 2>/dev/null; then
    rm -f -- "$tmp" 2>/dev/null || true
    rmdir -- "$tmpdir" 2>/dev/null || true
    cw_ok
  fi
fi
rm -f -- "$tmp" 2>/dev/null || true
rmdir -- "$tmpdir" 2>/dev/null || true
if [ -e "$destination" ] || [ -L "$destination" ]; then cw_fail alreadyExists; fi
cw_fail failed
''',
    );
  }

  String _buildDeleteCommand({
    required String rootDirectory,
    required String parentDirectory,
    required String name,
    required String decoder,
  }) {
    return _buildScript(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
      decoder: decoder,
      body: r'''
cw_validate_name "$CW_NAME"
cw_prepare_parent
target="$parent/$CW_NAME"
if [ "$target" = "$root" ]; then cw_fail rootDeleteBlocked; fi
if ! [ -e "$target" ] && ! [ -L "$target" ]; then cw_fail missing; fi
if ! [ -w "$parent" ]; then cw_fail permissionDenied; fi
errdir=$(mktemp -d "$parent/.cw-delete.XXXXXX" 2>/dev/null || true)
err=''
status=''
if [ -n "$errdir" ]; then
  err="$errdir/stderr"
  status="$errdir/status"
fi
if [ -n "$err" ] && cd -- "$parent" 2>/dev/null; then
  if [ -d "$target" ] && ! [ -L "$target" ]; then
    { rm -r -- "$CW_NAME" >/dev/null; printf '%s' "$?" > "$status"; } 2>&1 | sed -n '1,3p' | cut -c 1-240 > "$err"
  else
    { rm -- "$CW_NAME" >/dev/null; printf '%s' "$?" > "$status"; } 2>&1 | sed -n '1,3p' | cut -c 1-240 > "$err"
  fi
  rm_status=$(cat "$status" 2>/dev/null || printf '1')
  if [ "$rm_status" = "0" ]; then
    rm -f -- "$err" "$status" 2>/dev/null || true
    rmdir -- "$errdir" 2>/dev/null || true
    cw_ok
  fi
else
  if [ -d "$target" ] && ! [ -L "$target" ]; then
    if cd -- "$parent" 2>/dev/null && rm -r -- "$CW_NAME" 2>/dev/null; then cw_ok; fi
  else
    if cd -- "$parent" 2>/dev/null && rm -- "$CW_NAME" 2>/dev/null; then cw_ok; fi
  fi
fi
rm_error=''
if [ -n "$err" ]; then
  rm_error=$(cat "$err" 2>/dev/null || true)
  rm -f -- "$err" "$status" 2>/dev/null || true
  rmdir -- "$errdir" 2>/dev/null || true
fi
if [ -n "${rm_error:-}" ]; then cw_fail_message failed "$rm_error"; fi
cw_fail failed
''',
    );
  }

  String _buildWriteFileCommand({
    required String rootDirectory,
    required String parentDirectory,
    required String name,
    required String contentBase64,
    required String decoder,
  }) {
    return _buildScript(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
      contentBase64: contentBase64,
      decoder: decoder,
      body: r'''
cw_validate_name "$CW_NAME"
cw_prepare_parent
target="$parent/$CW_NAME"
if [ "$target" = "$root" ]; then cw_fail rootDeleteBlocked; fi
if ! [ -e "$target" ] && ! [ -L "$target" ]; then cw_fail missing; fi
if [ -d "$target" ] && ! [ -L "$target" ]; then cw_fail notDirectory; fi
if ! [ -w "$target" ] || ! [ -w "$parent" ]; then cw_fail permissionDenied; fi
tmpdir=$(mktemp -d "$parent/.cw-write.XXXXXX" 2>/dev/null) || cw_fail failed
tmp="$tmpdir/content"
if cw_decode_content "$tmp"; then
  cw_copy_mode "$target" "$tmp"
  if mv -- "$tmp" "$target" 2>/dev/null; then
    rmdir -- "$tmpdir" 2>/dev/null || true
    cw_ok
  fi
fi
rm -f -- "$tmp" 2>/dev/null || true
rmdir -- "$tmpdir" 2>/dev/null || true
cw_fail failed
''',
    );
  }

  String _buildScript({
    required String rootDirectory,
    required String parentDirectory,
    required String name,
    required String body,
    String? newName,
    String? contentBase64,
    required String decoder,
  }) {
    final variables = <String, String>{
      'CW_ROOT_INPUT': rootDirectory,
      'CW_PARENT_INPUT': parentDirectory,
      'CW_NAME': name,
    };
    if (newName != null) {
      variables['CW_NEW_NAME'] = newName;
    }
    if (contentBase64 != null) {
      final chunkCount =
          (contentBase64.length + _contentEnvironmentChunkSize - 1) ~/
          _contentEnvironmentChunkSize;
      variables['CW_CONTENT_CHUNK_COUNT'] = '$chunkCount';
      for (var index = 0; index < chunkCount; index += 1) {
        final start = index * _contentEnvironmentChunkSize;
        final end = min(
          start + _contentEnvironmentChunkSize,
          contentBase64.length,
        );
        variables['CW_CONTENT_B64_$index'] = contentBase64.substring(
          start,
          end,
        );
      }
    }
    final script = 'set -u\n${_shellHelpers()}${body.trim()}\n';
    return _singleShellCommand(
      script: script,
      variables: variables,
      decoder: decoder,
    );
  }

  static String _singleShellCommand({
    required String script,
    required String decoder,
    Map<String, String> variables = const <String, String>{},
  }) {
    final assignments = variables.entries
        .map((entry) => '${entry.key}=${_shQuote(entry.value)}')
        .join(' ');
    final encodedScript = base64Encode(utf8.encode(script));
    final environment = assignments.isEmpty ? '' : '$assignments ';
    return "printf '%s' ${_shQuote(encodedScript)} | $decoder | "
        '${environment}sh';
  }

  String _shellHelpers() {
    return r'''
cw_emit() { printf '%s\n' "CW_FILE_OP_JSON:$1"; }
cw_ok() { cw_emit '{"ok":true,"code":"ok","message":"ok"}'; exit 0; }
cw_fail() {
  case "$1" in
    invalidName) cw_emit '{"ok":false,"code":"invalidName","message":"Invalid name."}' ;;
    outsideRoot) cw_emit '{"ok":false,"code":"outsideRoot","message":"Path is outside the project root."}' ;;
    rootDeleteBlocked) cw_emit '{"ok":false,"code":"rootDeleteBlocked","message":"The project root cannot be deleted."}' ;;
    missing) cw_emit '{"ok":false,"code":"missing","message":"Path does not exist."}' ;;
    alreadyExists) cw_emit '{"ok":false,"code":"alreadyExists","message":"A file or folder with that name already exists."}' ;;
    permissionDenied) cw_emit '{"ok":false,"code":"permissionDenied","message":"Permission denied."}' ;;
    notDirectory) cw_emit '{"ok":false,"code":"notDirectory","message":"Parent is not a directory."}' ;;
    *) cw_emit '{"ok":false,"code":"failed","message":"File operation failed."}' ;;
  esac
  exit 0
}
cw_json_escape() {
  printf '%s' "$1" | tr '\r\n' '  ' | tr -d '\000-\011\013-\037\177' | sed 's/\\/\\\\/g; s/"/\\"/g'
}
cw_fail_message() {
  code="$1"
  message=$(cw_json_escape "$2")
  cw_emit "{\"ok\":false,\"code\":\"$code\",\"message\":\"$message\"}"
  exit 0
}
cw_validate_name() {
  case "$1" in
    ''|'.'|'..'|*/*|*\\*) cw_fail invalidName ;;
  esac
}
cw_content_base64() {
  index=0
  while [ "$index" -lt "${CW_CONTENT_CHUNK_COUNT:-0}" ]; do
    eval "chunk=\${CW_CONTENT_B64_$index-}"
    printf '%s' "$chunk"
    index=$((index + 1))
  done
}
cw_decode_content() {
  if command -v base64 >/dev/null 2>&1; then
    if cw_content_base64 | base64 -d > "$1" 2>/dev/null; then return 0; fi
    if cw_content_base64 | base64 -D > "$1" 2>/dev/null; then return 0; fi
    if cw_content_base64 | base64 --decode > "$1" 2>/dev/null; then return 0; fi
  fi
  if command -v python3 >/dev/null 2>&1; then
    if cw_content_base64 | python3 -c 'import base64,sys;sys.stdout.buffer.write(base64.b64decode(sys.stdin.buffer.read()))' > "$1" 2>/dev/null; then return 0; fi
  fi
  return 1
}
cw_copy_mode() {
  if chmod --reference="$1" "$2" 2>/dev/null; then return 0; fi
  mode=''
  if command -v stat >/dev/null 2>&1; then
    mode=$(stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null || true)
  fi
  if [ -n "$mode" ]; then chmod "$mode" "$2" 2>/dev/null || true; fi
  return 0
}
cw_prepare_parent() {
  root=$(cd -- "$CW_ROOT_INPUT" 2>/dev/null && pwd -P) || cw_fail missing
  if [ "$root" = "/" ]; then cw_fail outsideRoot; fi
  parent=$(cd -- "$CW_PARENT_INPUT" 2>/dev/null && pwd -P) || cw_fail missing
  if ! [ -d "$parent" ]; then cw_fail notDirectory; fi
  case "$parent" in
    "$root"|"$root"/*) ;;
    *) cw_fail outsideRoot ;;
  esac
}
''';
  }
}

class _PreparedLeafName {
  const _PreparedLeafName({this.name = '', this.result});

  final String name;
  final WorkspaceFileOperationResult? result;
}

class _PreparedLeafOperation {
  const _PreparedLeafOperation({
    this.rootDirectory = '',
    this.parentDirectory = '',
    this.name = '',
    this.result,
  });

  final String rootDirectory;
  final String parentDirectory;
  final String name;
  final WorkspaceFileOperationResult? result;
}
