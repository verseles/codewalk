import 'dart:io';

/// The cache belongs to this user; shared /tmp paths cannot hold update files.
Future<Directory> prepareLinuxUpdateCache(Directory root) async {
  if (FileSystemEntity.isLinkSync(root.path)) {
    throw FileSystemException('Update cache must not be a link', root.path);
  }
  await root.create(recursive: true);
  final permission = await Process.run('/bin/chmod', ['700', root.path]);
  if (permission.exitCode != 0 || (root.statSync().mode & 0x1ff) != 0x1c0) {
    throw FileSystemException('Update cache must be private', root.path);
  }
  final cutoff = DateTime.now().subtract(const Duration(hours: 24));
  await for (final entity in root.list(followLinks: false)) {
    if (entity is Directory &&
        RegExp(r'/codewalk-install-[1-9]\d*$').hasMatch(entity.path) &&
        entity.statSync().modified.isBefore(cutoff)) {
      await entity.delete(recursive: true);
    }
  }
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File &&
        (entity.path.endsWith('.part') || entity.path.endsWith('.part.json')) &&
        entity.statSync().modified.isBefore(cutoff)) {
      await entity.delete();
    }
  }
  return root;
}

Future<String> linuxUpdatePartPath(
  Directory root,
  String tag,
  String name,
) async {
  final directory = Directory('${root.path}/${Uri.encodeComponent(tag)}');
  if (FileSystemEntity.isLinkSync(directory.path)) {
    throw FileSystemException(
      'Update directory must not be a link',
      directory.path,
    );
  }
  await directory.create();
  return '${directory.path}/$name.part';
}
