import 'dart:async';
import 'dart:typed_data';

import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/presentation/services/project_icon_discovery_service_base.dart';
import 'package:codewalk/presentation/services/project_icon_models.dart';
import 'package:codewalk/presentation/services/project_icon_store_base.dart';

Project paletteProject([String id = 'palette']) => Project(
  id: id,
  name: id,
  path: '/repo/$id',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);

ProjectIconData paletteIcon(
  List<int> bytes, {
  ProjectIconFormat format = ProjectIconFormat.png,
  Project? project,
}) {
  final p = project ?? paletteProject();
  return ProjectIconData(
    bytes: Uint8List.fromList(bytes),
    metadata: ProjectIconMetadata(
      key: projectIconKeyFor(p),
      projectId: p.id,
      projectPath: p.path,
      sourcePath: '${p.path}/icon.${format.extension}',
      storedPath: '/icons/${p.id}.${format.extension}',
      sourceFormat: format,
      storedFormat: format,
      sourceByteLength: bytes.length,
      storedByteLength: bytes.length,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
}

class PaletteStore implements ProjectIconStore {
  PaletteStore(this.icon);
  ProjectIconData? icon;
  Completer<ProjectIconData?>? read;
  int reads = 0;

  @override
  Future<ProjectIconData?> readIcon(String key) async {
    reads++;
    return read == null ? icon : read!.future;
  }

  @override
  Future<void> deleteIcon(String key) async {
    icon = null;
  }

  @override
  Future<ProjectIconData> saveIcon({
    required Project project,
    required String key,
    required ProjectIconCandidate candidate,
  }) async {
    return icon = paletteIcon(
      candidate.bytes,
      format: candidate.storedFormat,
      project: project,
    );
  }
}

class PaletteDiscovery implements ProjectIconDiscoveryService {
  Completer<ProjectIconDiscoveryResult>? pending;
  ProjectIconDiscoveryResult result = const ProjectIconDiscoveryResult(
    status: ProjectIconDiscoveryStatus.notFound,
  );
  int calls = 0;
  @override
  bool get isSupported => true;
  @override
  Future<ProjectIconDiscoveryResult> discover(Project project) async {
    calls++;
    return pending == null ? result : pending!.future;
  }

  void found(ProjectIconData icon) {
    result = ProjectIconDiscoveryResult.found(
      ProjectIconCandidate(
        sourcePath: icon.metadata.sourcePath,
        bytes: icon.bytes,
        sourceFormat: icon.metadata.sourceFormat,
        storedFormat: icon.metadata.storedFormat,
        sourceByteLength: icon.bytes.length,
      ),
    );
  }
}
