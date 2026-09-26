import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../core/utils/path_utils.dart';
import '../../domain/entities/project.dart';
import 'project_icon_discovery_service_base.dart';
import 'project_icon_models.dart';

ProjectIconDiscoveryService createProjectIconDiscoveryService({Dio? dio}) =>
    ProjectIconDiscoveryServiceIo(dio: dio);

class ProjectIconDiscoveryServiceIo implements ProjectIconDiscoveryService {
  const ProjectIconDiscoveryServiceIo({this.dio});

  final Dio? dio;

  @override
  bool get isSupported => true;

  @override
  Future<ProjectIconDiscoveryResult> discover(Project project) async {
    final path = normalizeOptionalFilePath(project.path);
    if (path == null) {
      return const ProjectIconDiscoveryResult(
        status: ProjectIconDiscoveryStatus.notFound,
        message: 'Project path is empty.',
      );
    }
    final localResult = await compute(_discoverProjectIcon, <String, Object?>{
      'path': path,
    });
    if (localResult.found) {
      return localResult;
    }

    final remoteResult = await _discoverRemoteProjectIcon(
      dio: dio,
      rootPath: path,
    );
    if (remoteResult?.found == true) {
      return remoteResult!;
    }
    if (remoteResult != null &&
        remoteResult.status != ProjectIconDiscoveryStatus.notFound) {
      return remoteResult;
    }
    return localResult;
  }
}

class _DirectoryToVisit {
  const _DirectoryToVisit(this.path, this.depth);

  final String path;
  final int depth;
}

class _IconMatch {
  const _IconMatch({
    required this.path,
    required this.relativePath,
    required this.format,
    required this.length,
    required this.priority,
    required this.qualityRank,
  });

  final String path;
  final String relativePath;
  final ProjectIconFormat format;
  final int length;
  final int priority;
  final int qualityRank;
}

Future<ProjectIconDiscoveryResult> _discoverProjectIcon(
  Map<String, Object?> request,
) async {
  final rootPath = request['path']?.toString() ?? '';
  final root = Directory(rootPath);
  if (!root.existsSync()) {
    return ProjectIconDiscoveryResult(
      status: ProjectIconDiscoveryStatus.notFound,
      message: 'Directory does not exist: $rootPath',
    );
  }

  var sawUnsupported = false;
  var sawOversized = false;
  var visited = 0;
  final matches = <_IconMatch>[];
  final matchedPaths = <String>{};

  for (final direct in _directIconCandidates) {
    final result = await _maybeAddIconMatch(
      rootPath: root.path,
      file: File('${root.path}/${direct.relativePath}'),
      relativePath: direct.relativePath,
      priorityOverride: direct.priority,
      matches: matches,
      matchedPaths: matchedPaths,
    );
    sawUnsupported = sawUnsupported || result.unsupported;
    sawOversized = sawOversized || result.oversized;
  }

  final queue = Queue<_DirectoryToVisit>()
    ..add(_DirectoryToVisit(root.path, 0));

  while (queue.isNotEmpty && visited < 5000) {
    final current = queue.removeFirst();
    if (current.depth > 8) {
      continue;
    }
    late final List<FileSystemEntity> entries;
    try {
      entries = await Directory(current.path).list(followLinks: false).toList();
    } catch (_) {
      continue;
    }
    entries.sort(
      (left, right) =>
          left.path.toLowerCase().compareTo(right.path.toLowerCase()),
    );
    for (final entry in entries) {
      visited += 1;
      if (visited > 5000) {
        break;
      }
      if (entry is Directory) {
        if (!_shouldSkipDirectory(entry.path)) {
          queue.add(_DirectoryToVisit(entry.path, current.depth + 1));
        }
        continue;
      }
      if (entry is! File) {
        continue;
      }
      final relativePath = _relativePath(root.path, entry.path);
      final result = await _maybeAddIconMatch(
        rootPath: root.path,
        file: entry,
        relativePath: relativePath,
        matches: matches,
        matchedPaths: matchedPaths,
      );
      sawUnsupported = sawUnsupported || result.unsupported;
      sawOversized = sawOversized || result.oversized;
    }
  }

  if (matches.isEmpty) {
    if (sawOversized) {
      return const ProjectIconDiscoveryResult(
        status: ProjectIconDiscoveryStatus.oversized,
        message: 'Only oversized favicon files were found.',
      );
    }
    if (sawUnsupported) {
      return const ProjectIconDiscoveryResult(
        status: ProjectIconDiscoveryStatus.unsupported,
        message: 'Only unsupported favicon formats were found.',
      );
    }
    return const ProjectIconDiscoveryResult(
      status: ProjectIconDiscoveryStatus.notFound,
      message: 'No favicon file found.',
    );
  }

  matches.sort((left, right) {
    final byPriority = left.priority.compareTo(right.priority);
    if (byPriority != 0) {
      return byPriority;
    }
    final byQuality = left.qualityRank.compareTo(right.qualityRank);
    if (byQuality != 0) {
      return byQuality;
    }
    final byRelativeLength = left.relativePath.length.compareTo(
      right.relativePath.length,
    );
    if (byRelativeLength != 0) {
      return byRelativeLength;
    }
    return left.relativePath.toLowerCase().compareTo(
      right.relativePath.toLowerCase(),
    );
  });
  final chosen = matches.first;
  try {
    final sourceBytes = await File(chosen.path).readAsBytes();
    final candidate = _candidateFromSource(
      path: chosen.path,
      sourceBytes: sourceBytes,
      sourceFormat: chosen.format,
      sourceByteLength: chosen.length,
    );
    if (candidate == null) {
      return ProjectIconDiscoveryResult(
        status: ProjectIconDiscoveryStatus.error,
        message: 'Could not decode project icon: ${chosen.path}',
      );
    }
    if (candidate.bytes.length > projectIconMaxBytes) {
      return const ProjectIconDiscoveryResult(
        status: ProjectIconDiscoveryStatus.oversized,
        message: 'Decoded project icon exceeds the size limit.',
      );
    }
    return ProjectIconDiscoveryResult.found(candidate);
  } catch (error) {
    return ProjectIconDiscoveryResult(
      status: ProjectIconDiscoveryStatus.error,
      message: 'Could not read project icon: $error',
    );
  }
}

class _DirectIconCandidate {
  const _DirectIconCandidate(this.relativePath, this.priority);

  final String relativePath;
  final int priority;
}

class _IconMatchResult {
  const _IconMatchResult({this.unsupported = false, this.oversized = false});

  final bool unsupported;
  final bool oversized;
}

Future<ProjectIconDiscoveryResult?> _discoverRemoteProjectIcon({
  required Dio? dio,
  required String rootPath,
}) async {
  if (dio == null) {
    return null;
  }

  final paths = SplayTreeSet<String>((left, right) {
    final byQuality = _iconQualityRank(left).compareTo(_iconQualityRank(right));
    if (byQuality != 0) {
      return byQuality;
    }
    final byLength = left.length.compareTo(right.length);
    if (byLength != 0) {
      return byLength;
    }
    return left.toLowerCase().compareTo(right.toLowerCase());
  });
  var reachedServer = false;

  reachedServer =
      await _addRemoteRootFavicons(
        dio: dio,
        rootPath: rootPath,
        paths: paths,
      ) ||
      reachedServer;
  reachedServer =
      await _addRemoteFoundFavicons(
        dio: dio,
        rootPath: rootPath,
        paths: paths,
      ) ||
      reachedServer;

  if (!reachedServer) {
    return null;
  }
  if (paths.isEmpty) {
    return const ProjectIconDiscoveryResult(
      status: ProjectIconDiscoveryStatus.notFound,
      message: 'No favicon file found on the OpenCode server.',
    );
  }

  ProjectIconDiscoveryResult? failureResult;
  for (final relativePath in paths) {
    final result = await _readRemoteIconCandidate(
      dio: dio,
      rootPath: rootPath,
      relativePath: relativePath,
    );
    if (result?.found == true) {
      return result;
    }
    failureResult ??= result;
  }

  if (failureResult != null) {
    return failureResult;
  }

  return const ProjectIconDiscoveryResult(
    status: ProjectIconDiscoveryStatus.notFound,
    message: 'No readable favicon file found on the OpenCode server.',
  );
}

Future<bool> _addRemoteRootFavicons({
  required Dio dio,
  required String rootPath,
  required Set<String> paths,
}) async {
  try {
    final response = await dio.get(
      '/file',
      queryParameters: <String, dynamic>{'path': '.', 'directory': rootPath},
    );
    final data = response.data;
    if (data is! List) {
      return true;
    }
    for (final item in data) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final type = map['type']?.toString().trim().toLowerCase();
      if (type != null && type.isNotEmpty && type != 'file') {
        continue;
      }
      final rawPath = map['path']?.toString() ?? map['name']?.toString() ?? '';
      final relativePath = _normalizeRemoteRelativePath(
        rootPath: rootPath,
        path: rawPath,
      );
      if (relativePath != null && _isRemoteFaviconPath(relativePath)) {
        paths.add(relativePath);
      }
    }
    return true;
  } on DioException {
    return false;
  }
}

Future<bool> _addRemoteFoundFavicons({
  required Dio dio,
  required String rootPath,
  required Set<String> paths,
}) async {
  try {
    final response = await dio.get(
      '/find/file',
      queryParameters: <String, dynamic>{
        'query': 'favicon',
        'type': 'file',
        'limit': '200',
        'directory': rootPath,
      },
    );
    final data = response.data;
    if (data is! List) {
      return true;
    }
    for (final item in data) {
      final rawPath = switch (item) {
        String() => item,
        Map() => item['path']?.toString() ?? item['name']?.toString() ?? '',
        _ => '',
      };
      final relativePath = _normalizeRemoteRelativePath(
        rootPath: rootPath,
        path: rawPath,
      );
      if (relativePath != null && _isRemoteFaviconPath(relativePath)) {
        paths.add(relativePath);
      }
    }
    return true;
  } on DioException {
    return false;
  }
}

Future<ProjectIconDiscoveryResult?> _readRemoteIconCandidate({
  required Dio dio,
  required String rootPath,
  required String relativePath,
}) async {
  final format = ProjectIconFormatX.fromName(fileBasename(relativePath));
  if (format == null) {
    return const ProjectIconDiscoveryResult(
      status: ProjectIconDiscoveryStatus.unsupported,
      message: 'Only unsupported favicon formats were found.',
    );
  }

  try {
    final response = await dio.get(
      '/file/content',
      queryParameters: <String, dynamic>{
        'path': relativePath,
        'directory': rootPath,
      },
    );
    final sourceBytes = _remoteContentBytes(response.data);
    if (sourceBytes == null || sourceBytes.isEmpty) {
      return null;
    }
    if (sourceBytes.length > projectIconMaxBytes) {
      return const ProjectIconDiscoveryResult(
        status: ProjectIconDiscoveryStatus.oversized,
        message: 'Project icon is over the 5 MB limit.',
      );
    }
    final candidate = _candidateFromSource(
      path: _remoteSourcePath(rootPath: rootPath, relativePath: relativePath),
      sourceBytes: sourceBytes,
      sourceFormat: format,
      sourceByteLength: sourceBytes.length,
    );
    if (candidate == null) {
      return ProjectIconDiscoveryResult(
        status: ProjectIconDiscoveryStatus.error,
        message: 'Could not decode project icon: $relativePath',
      );
    }
    if (candidate.bytes.length > projectIconMaxBytes) {
      return const ProjectIconDiscoveryResult(
        status: ProjectIconDiscoveryStatus.oversized,
        message: 'Decoded project icon exceeds the size limit.',
      );
    }
    return ProjectIconDiscoveryResult.found(candidate);
  } on DioException catch (error) {
    if (error.response?.statusCode == 404) {
      return null;
    }
    return ProjectIconDiscoveryResult(
      status: ProjectIconDiscoveryStatus.error,
      message: 'Could not read project icon from OpenCode server: $error',
    );
  } on FormatException catch (error) {
    return ProjectIconDiscoveryResult(
      status: ProjectIconDiscoveryStatus.error,
      message: 'Could not decode project icon from OpenCode server: $error',
    );
  }
}

Uint8List? _remoteContentBytes(dynamic data) {
  if (data is List<int>) {
    return Uint8List.fromList(data);
  }
  if (data is String) {
    return Uint8List.fromList(utf8.encode(data));
  }
  if (data is! Map) {
    return null;
  }

  final map = Map<String, dynamic>.from(data);
  final rawContent = map['content'];
  if (rawContent is! String) {
    return null;
  }
  final type = map['type']?.toString().trim().toLowerCase();
  final encoding = map['encoding']?.toString().trim().toLowerCase();
  final isBinary =
      map['binary'] == true || type == 'binary' || encoding == 'base64';
  if (isBinary) {
    return Uint8List.fromList(base64Decode(rawContent));
  }
  return Uint8List.fromList(utf8.encode(rawContent));
}

String? _normalizeRemoteRelativePath({
  required String rootPath,
  required String path,
}) {
  final root = normalizeFilePath(rootPath);
  var relativePath = normalizeFilePath(path);
  if (relativePath.isEmpty || relativePath == '.') {
    return null;
  }
  if (relativePath == root) {
    return null;
  }
  final prefix = filePathChildPrefix(root);
  if (relativePath.startsWith(prefix)) {
    relativePath = relativePath.substring(prefix.length);
  }
  while (relativePath.startsWith('/')) {
    relativePath = relativePath.substring(1);
  }
  while (relativePath.startsWith('./')) {
    relativePath = relativePath.substring(2);
  }
  final parts = relativePath.split('/');
  if (parts.any((part) => part.isEmpty || part == '..')) {
    return null;
  }
  return relativePath;
}

bool _isRemoteFaviconPath(String relativePath) {
  final path = normalizeFilePath(relativePath).toLowerCase();
  final name = fileBasename(relativePath).toLowerCase();
  if (_isFaviconName(name)) {
    return ProjectIconFormatX.fromName(name) != null;
  }
  if (!_isSizedWebIconName(name)) {
    return false;
  }
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  return parts.length == 1 ||
      (parts.length <= 3 &&
          (parts[0] == 'web' || parts[0] == 'public' || parts[0] == 'static'));
}

String _remoteSourcePath({
  required String rootPath,
  required String relativePath,
}) {
  final root = normalizeFilePath(rootPath);
  if (root == '/') {
    return '/$relativePath';
  }
  return joinParentPath(root, relativePath);
}

const _directIconCandidates = <_DirectIconCandidate>[
  _DirectIconCandidate('build/icon.png', 200),
  _DirectIconCandidate('build/icon.ico', 200),
  _DirectIconCandidate('build/icon.svg', 200),
  _DirectIconCandidate('build/icon.webp', 200),
  _DirectIconCandidate('build/icon.jpg', 200),
  _DirectIconCandidate('build/icon.jpeg', 200),
  _DirectIconCandidate('windows/runner/resources/app_icon.ico', 320),
  _DirectIconCandidate('linux/runner/resources/app_icon.png', 320),
];

Future<_IconMatchResult> _maybeAddIconMatch({
  required String rootPath,
  required File file,
  required String relativePath,
  required List<_IconMatch> matches,
  required Set<String> matchedPaths,
  int? priorityOverride,
}) async {
  final normalizedRelativePath = normalizeFilePath(relativePath);
  final name = fileBasename(normalizedRelativePath);
  final priority = priorityOverride ?? _iconPriority(normalizedRelativePath);
  if (priority == null) {
    return const _IconMatchResult();
  }
  try {
    if (!file.existsSync()) {
      return const _IconMatchResult();
    }
  } catch (_) {
    return const _IconMatchResult();
  }
  if (!matchedPaths.add(normalizeFilePath(file.path))) {
    return const _IconMatchResult();
  }
  final format = ProjectIconFormatX.fromName(name);
  if (format == null) {
    return const _IconMatchResult(unsupported: true);
  }
  late final int length;
  try {
    length = await file.length();
  } catch (_) {
    return const _IconMatchResult();
  }
  if (length <= 0) {
    return const _IconMatchResult();
  }
  if (length > projectIconMaxBytes) {
    return const _IconMatchResult(oversized: true);
  }
  matches.add(
    _IconMatch(
      path: file.path,
      relativePath: _relativePath(rootPath, file.path),
      format: format,
      length: length,
      priority: priority,
      qualityRank: _iconQualityRank(normalizedRelativePath),
    ),
  );
  return const _IconMatchResult();
}

ProjectIconCandidate? _candidateFromSource({
  required String path,
  required Uint8List sourceBytes,
  required ProjectIconFormat sourceFormat,
  required int sourceByteLength,
}) {
  if (sourceFormat == ProjectIconFormat.ico) {
    final decoded = img.IcoDecoder().decodeImageLargest(sourceBytes);
    if (decoded == null) {
      return null;
    }
    return ProjectIconCandidate(
      sourcePath: path,
      bytes: Uint8List.fromList(img.encodePng(decoded, singleFrame: true)),
      sourceFormat: ProjectIconFormat.ico,
      storedFormat: ProjectIconFormat.png,
      sourceByteLength: sourceByteLength,
    );
  }
  return ProjectIconCandidate(
    sourcePath: path,
    bytes: sourceBytes,
    sourceFormat: sourceFormat,
    storedFormat: sourceFormat,
    sourceByteLength: sourceByteLength,
  );
}

bool _isFaviconName(String name) {
  final normalized = name.trim().toLowerCase();
  if (!normalized.startsWith('favicon.')) {
    return false;
  }
  return normalized.indexOf('.', 'favicon.'.length) == -1;
}

int? _iconPriority(String relativePath) {
  final path = normalizeFilePath(relativePath).toLowerCase();
  final name = fileBasename(path).toLowerCase();
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();

  if (_isTauriIcon(parts, name)) {
    return 100;
  }
  if (_isElectronIcon(parts, name)) {
    return 200;
  }
  if (_isAppleAppIcon(parts, name)) {
    return 300;
  }
  if (path == 'windows/runner/resources/app_icon.ico') {
    return 320;
  }
  if (_isAndroidLauncherIcon(parts, name)) {
    return 400;
  }
  if (_isCommonAppIcon(parts, name)) {
    return 600;
  }
  if (_isWebIcon(parts, name)) {
    return 800;
  }
  return null;
}

bool _isTauriIcon(List<String> parts, String name) {
  return parts.length >= 3 &&
      parts[0] == 'src-tauri' &&
      parts[1] == 'icons' &&
      _isKnownIconName(name);
}

bool _isElectronIcon(List<String> parts, String name) {
  if (!_isKnownIconName(name)) {
    return false;
  }
  return parts.length == 2 && parts[0] == 'build';
}

bool _isAppleAppIcon(List<String> parts, String name) {
  if (!name.endsWith('.png')) {
    return false;
  }
  return parts.any((part) => part == 'appicon.appiconset');
}

bool _isAndroidLauncherIcon(List<String> parts, String name) {
  if (!name.endsWith('.png')) {
    return false;
  }
  final hasRes = parts.contains('res');
  final hasMipmap = parts.any((part) => part.startsWith('mipmap'));
  return hasRes &&
      hasMipmap &&
      (name == 'ic_launcher.png' ||
          name == 'ic_launcher_round.png' ||
          name == 'ic_launcher_foreground.png');
}

bool _isCommonAppIcon(List<String> parts, String name) {
  if (_isFaviconName(name)) {
    return false;
  }
  if (!_isKnownIconName(name)) {
    return false;
  }
  if (parts.length == 1) {
    return true;
  }
  if (parts.length <= 4) {
    if (parts[0] == 'linux') {
      return parts.length >= 3 &&
          (parts[1] == 'runner' || parts[1] == 'resources');
    }
    return parts[0] == 'assets' ||
        parts[0] == 'asset' ||
        parts[0] == 'icons' ||
        parts[0] == 'icon' ||
        parts[0] == 'images' ||
        parts[0] == 'resources' ||
        parts[0] == 'res';
  }
  return false;
}

bool _isWebIcon(List<String> parts, String name) {
  if (_isFaviconName(name)) {
    return true;
  }
  if (!_isSizedWebIconName(name)) {
    return false;
  }
  return parts.length == 1 ||
      (parts.length <= 3 &&
          (parts[0] == 'web' || parts[0] == 'public' || parts[0] == 'static'));
}

bool _isKnownIconName(String name) {
  final normalized = name.trim().toLowerCase();
  if (ProjectIconFormatX.fromName(normalized) == null) {
    return false;
  }
  if (_isFaviconName(normalized)) {
    return true;
  }
  if (_isSizedWebIconName(normalized)) {
    return true;
  }
  final separator = normalized.lastIndexOf('.');
  final stem = separator < 0 ? normalized : normalized.substring(0, separator);
  return stem == 'icon' ||
      stem == 'app_icon' ||
      stem == 'appicon' ||
      stem == 'launcher_icon' ||
      stem == 'logo' ||
      stem == 'storelogo' ||
      stem == 'square' ||
      stem.startsWith('icon-') ||
      stem.startsWith('app-icon') ||
      stem.startsWith('icon_') ||
      stem.startsWith('icon.') ||
      stem.startsWith('app_icon-') ||
      stem.startsWith('app_icon_') ||
      stem.startsWith('app_icon.') ||
      stem.startsWith('appicon-') ||
      stem.startsWith('appicon_') ||
      stem.startsWith('appicon.') ||
      stem.startsWith('launcher_icon-') ||
      stem.startsWith('launcher_icon_') ||
      stem.startsWith('launcher_icon.') ||
      stem.startsWith('logo-') ||
      stem.startsWith('logo_') ||
      stem.startsWith('logo.') ||
      stem.startsWith('square') ||
      RegExp(r'^\d+x\d+(@2x)?$').hasMatch(stem);
}

bool _isSizedWebIconName(String name) {
  final normalized = name.trim().toLowerCase();
  final separator = normalized.lastIndexOf('.');
  if (separator < 0 || ProjectIconFormatX.fromName(normalized) == null) {
    return false;
  }
  final stem = normalized.substring(0, separator);
  return stem.startsWith('favicon-') ||
      stem.startsWith('icon-') ||
      stem.startsWith('android-chrome-') ||
      stem.startsWith('mstile-');
}

int _iconQualityRank(String relativePath) {
  final path = relativePath.toLowerCase();
  final name = fileBasename(path).toLowerCase();
  if (name == 'ic_launcher.png') {
    return _androidDensityRank(path);
  }
  if (name == 'ic_launcher_round.png') {
    return 10 + _androidDensityRank(path);
  }
  if (name == 'ic_launcher_foreground.png') {
    return 30 + _androidDensityRank(path);
  }
  const sizes = <int>[
    1024,
    512,
    310,
    256,
    192,
    180,
    167,
    152,
    144,
    128,
    96,
    76,
    72,
    64,
    60,
    48,
    40,
    32,
    29,
    20,
    16,
  ];
  for (var index = 0; index < sizes.length; index += 1) {
    final size = sizes[index];
    if (name.contains('${size}x$size') || _containsNumberToken(name, size)) {
      return index;
    }
  }
  return 40;
}

bool _containsNumberToken(String value, int number) {
  final token = number.toString();
  var start = value.indexOf(token);
  while (start >= 0) {
    final before = start == 0 ? null : value.codeUnitAt(start - 1);
    final afterIndex = start + token.length;
    final after = afterIndex >= value.length
        ? null
        : value.codeUnitAt(afterIndex);
    if (!_isAsciiDigit(before) && !_isAsciiDigit(after)) {
      return true;
    }
    start = value.indexOf(token, start + 1);
  }
  return false;
}

bool _isAsciiDigit(int? codeUnit) {
  return codeUnit != null && codeUnit >= 48 && codeUnit <= 57;
}

int _androidDensityRank(String path) {
  if (path.contains('mipmap-xxxhdpi')) {
    return 0;
  }
  if (path.contains('mipmap-xxhdpi')) {
    return 1;
  }
  if (path.contains('mipmap-xhdpi')) {
    return 2;
  }
  if (path.contains('mipmap-hdpi')) {
    return 3;
  }
  if (path.contains('mipmap-mdpi')) {
    return 4;
  }
  return 5;
}

bool _shouldSkipDirectory(String path) {
  final name = fileBasename(path).trim().toLowerCase();
  const skip = <String>{
    '.git',
    'node_modules',
    'dist',
    'build',
    '.dart_tool',
    '.gradle',
    '.next',
    '.turbo',
    '.cache',
    'coverage',
    'tmp',
    'logs',
    'pods',
    'ephemeral',
  };
  return skip.contains(name);
}

String _relativePath(String rootPath, String filePath) {
  final root = normalizeFilePath(rootPath);
  final file = normalizeFilePath(filePath);
  final prefix = filePathChildPrefix(root);
  return file.startsWith(prefix) ? file.substring(prefix.length) : file;
}
