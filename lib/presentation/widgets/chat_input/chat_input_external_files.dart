import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

/// Extensions the composer already accepts through the file picker.
///
/// Kept here so dropped (#118) and pasted (#119) files are judged by exactly
/// the same rule as picked ones, instead of each entry point inventing its own.
// Keep this and composerAttachmentExtensionForMime aligned with the native
// Android clipboard pre-gate in MainActivity.
const Set<String> kComposerAttachmentExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
  'pdf',
};

/// Extension of [path], lowercased, without the dot. Empty when absent.
String composerFileExtension(String path) {
  final name = path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) {
    return '';
  }
  return name.substring(dot + 1).toLowerCase();
}

/// File name of [path], or a fallback when the platform gives only a URI.
String composerFileName(String path, {required String fallback}) {
  final name = path.split(RegExp(r'[/\\]')).last.trim();
  return name.isEmpty ? fallback : name;
}

/// Builds a client-local attachment from bytes and a platform-supplied name.
///
/// A MIME hint is used only when the platform did not provide a usable file
/// extension, such as Android clipboard content URIs.
PlatformFile? composerFileFromBytes(
  Uint8List bytes, {
  required String name,
  required String fallbackName,
  String? mimeType,
}) {
  if (bytes.isEmpty) {
    return null;
  }
  var normalizedName = name.trim();
  if (normalizedName.isEmpty) {
    normalizedName = fallbackName;
  }
  var extension = composerFileExtension(normalizedName);
  if (!kComposerAttachmentExtensions.contains(extension)) {
    final inferredExtension = composerAttachmentExtensionForMime(mimeType);
    if (inferredExtension == null) {
      return null;
    }
    extension = inferredExtension;
    normalizedName = '$normalizedName.$extension';
  }
  return ComposerMemoryFile(name: normalizedName, bytes: bytes);
}

/// In-memory [PlatformFile] for client-local bytes (dropped/pasted files).
///
/// file_picker v12 models picked files as an abstract type with async byte
/// access, so bytes that never touch disk get this tiny memory-backed
/// implementation instead of a fake path.
base class ComposerMemoryFile extends PlatformFile {
  ComposerMemoryFile({required this.name, required Uint8List bytes})
    : _bytes = bytes;

  final Uint8List _bytes;

  @override
  final String name;

  @override
  Uri get uri => Uri(scheme: 'composer-memory', path: name);

  @override
  XFile get xFile => XFile.fromData(_bytes, name: name, length: _bytes.length);

  @override
  int? lengthSync() => _bytes.length;

  @override
  Future<int> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}

String? composerAttachmentExtensionForMime(String? mimeType) {
  return switch (mimeType?.trim().toLowerCase()) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/bmp' => 'bmp',
    'image/heic' => 'heic',
    'image/heif' => 'heif',
    'application/pdf' => 'pdf',
    _ => null,
  };
}

bool composerAttachmentNameOrMimeSupported(String name, String? mimeType) {
  return kComposerAttachmentExtensions.contains(composerFileExtension(name)) ||
      composerAttachmentExtensionForMime(mimeType) != null;
}

/// Builds a [PlatformFile] for raw image bytes, such as a pasted screenshot.
///
/// Screenshots arrive without a name, so one is supplied by the caller in the
/// user's language, with the extension derived from the detected format.
PlatformFile? composerFileFromImageBytes(
  Uint8List bytes, {
  required String baseName,
}) {
  if (bytes.isEmpty) {
    return null;
  }
  final extension = composerImageExtensionFromBytes(bytes);
  return composerFileFromBytes(
    bytes,
    name: '$baseName.$extension',
    fallbackName: baseName,
    mimeType: 'image/$extension',
  );
}

/// Detects an image format from its magic bytes.
///
/// The clipboard hands over bytes with no filename, and guessing PNG for
/// everything would mislabel JPEG screenshots, so the header is read instead.
/// Defaults to png, which is what most platforms put on the clipboard.
String composerImageExtensionFromBytes(Uint8List bytes) {
  bool startsWith(List<int> signature, {int offset = 0}) {
    if (bytes.length < offset + signature.length) {
      return false;
    }
    for (var i = 0; i < signature.length; i += 1) {
      if (bytes[offset + i] != signature[i]) {
        return false;
      }
    }
    return true;
  }

  if (startsWith(<int>[0x89, 0x50, 0x4E, 0x47])) {
    return 'png';
  }
  if (startsWith(<int>[0xFF, 0xD8, 0xFF])) {
    return 'jpg';
  }
  if (startsWith(<int>[0x47, 0x49, 0x46, 0x38])) {
    return 'gif';
  }
  if (startsWith(<int>[0x42, 0x4D])) {
    return 'bmp';
  }
  if (startsWith(<int>[0x52, 0x49, 0x46, 0x46]) &&
      startsWith(<int>[0x57, 0x45, 0x42, 0x50], offset: 8)) {
    return 'webp';
  }
  if (startsWith(<int>[0x66, 0x74, 0x79, 0x70], offset: 4)) {
    return 'heic';
  }
  return 'png';
}
