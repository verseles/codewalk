// Read-only legacy adapter performs no filesystem mutation.
// ignore_for_file: avoid_slow_async_io

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'legacy_source.dart';

/// Reads original v1 SHA-1-named raw UTF-8 payloads without changing them.
///
/// The caller supplies the source directory. No plugin, preferences, legacy
/// cache getter or ambient application directory lookup is used. Stable
/// directory/file symlinks are rejected. Dart has no atomic no-follow open,
/// so these checks do not prove containment under adversarial concurrent
/// pathname replacement.
final class NativeLegacyPayloadReader implements LegacyPayloadReader {
  NativeLegacyPayloadReader({
    required Directory directory,
    this.maxReadableBytes = byteCeiling,
    this.maxPayloadChars = characterCeiling,
    File Function(String path)? fileFactory,
  }) : _directory = directory,
       _fileFactory = fileFactory ?? File.new {
    if (maxReadableBytes < 1 ||
        maxReadableBytes > byteCeiling ||
        maxPayloadChars < 0 ||
        maxPayloadChars > characterCeiling) {
      throw ArgumentError('Legacy read limits may only narrow the ceilings');
    }
  }

  static const int byteCeiling = 8 * 1024 * 1024;
  static const int characterCeiling = 2 * 1024 * 1024;
  static final RegExp _digestFilename = RegExp(r'^[0-9a-f]{40}\.json$');

  final Directory _directory;
  final File Function(String path) _fileFactory;
  final int maxReadableBytes;
  final int maxPayloadChars;

  static String _filename(String logicalKey) =>
      '${sha1.convert(utf8.encode(logicalKey))}.json';

  static String _childPath(String root, String filename) =>
      root.endsWith(Platform.pathSeparator)
      ? '$root$filename'
      : '$root${Platform.pathSeparator}$filename';

  static String _basename(String filename) {
    var separator = filename.lastIndexOf(Platform.pathSeparator);
    // Windows accepts both separators; Unix permits backslashes in names.
    if (Platform.isWindows) {
      final slash = filename.lastIndexOf('/');
      if (slash > separator) separator = slash;
    }
    return filename.substring(separator + 1);
  }

  Future<String?> _sourceDirectory() async {
    final type = await FileSystemEntity.type(
      _directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.directory) {
      throw const LegacyReadException(LegacyReadFailure.unavailable);
    }
    // Access children through the canonical root rather than parent aliases.
    final root = await _directory.resolveSymbolicLinks();
    if (await FileSystemEntity.type(root, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const LegacyReadException(LegacyReadFailure.unavailable);
    }
    return root;
  }

  Future<void> _requireRegularFile(String filename) async {
    if (await FileSystemEntity.type(filename, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const LegacyReadException(LegacyReadFailure.unavailable);
    }
  }

  @override
  Future<String?> read(String logicalKey) async {
    try {
      final root = await _sourceDirectory();
      if (root == null) return null;
      final filename = _childPath(root, _filename(logicalKey));
      final type = await FileSystemEntity.type(filename, followLinks: false);
      if (type == FileSystemEntityType.notFound) return null;
      if (type != FileSystemEntityType.file) {
        throw const LegacyReadException(LegacyReadFailure.unavailable);
      }
      final file = _fileFactory(filename);
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size < 0) {
        throw const LegacyReadException(LegacyReadFailure.unavailable);
      }
      if (stat.size > maxReadableBytes) {
        throw const LegacyReadException(LegacyReadFailure.oversized);
      }
      await _requireRegularFile(filename);
      final bytes = BytesBuilder(copy: false);
      // The extra byte detects growth after stat. The independent chunk guard
      // also rejects a backend that ignores the requested stream end.
      await for (final chunk in file.openRead(0, maxReadableBytes + 1)) {
        if (chunk.length > maxReadableBytes - bytes.length) {
          throw const LegacyReadException(LegacyReadFailure.oversized);
        }
        bytes.add(chunk);
      }
      if (await _sourceDirectory() != root) {
        throw const LegacyReadException(LegacyReadFailure.unavailable);
      }
      await _requireRegularFile(filename);
      final value = utf8.decode(bytes.takeBytes(), allowMalformed: false);
      if (value.length > maxPayloadChars) {
        throw const LegacyReadException(LegacyReadFailure.oversized);
      }
      return value;
    } on LegacyReadException {
      rethrow;
    } on FormatException {
      throw const LegacyReadException(LegacyReadFailure.malformed);
    } catch (_) {
      // Neither native exception text nor source paths/contents escape.
      throw const LegacyReadException(LegacyReadFailure.unavailable);
    }
  }

  @override
  Future<Set<String>> unclaimedFiles(Set<String> knownLogicalKeys) async {
    try {
      final root = await _sourceDirectory();
      if (root == null) return const {};
      final claimed = knownLogicalKeys.map(_filename).toSet();
      final unclaimed = <String>{};
      // Never recurse or follow links. Digest-shaped links/nonregular entries
      // are opaque unresolved names too: their contents are never opened.
      await for (final entity in Directory(
        root,
      ).list(recursive: false, followLinks: false)) {
        final name = _basename(entity.path);
        if (_digestFilename.hasMatch(name) && !claimed.contains(name)) {
          unclaimed.add(name);
        }
      }
      if (await _sourceDirectory() != root) {
        throw const LegacyReadException(LegacyReadFailure.unavailable);
      }
      return Set.unmodifiable(unclaimed);
    } on LegacyReadException {
      rethrow;
    } catch (_) {
      throw const LegacyReadException(LegacyReadFailure.unavailable);
    }
  }
}
