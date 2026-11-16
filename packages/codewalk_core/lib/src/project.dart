import 'identity.dart';

/// Optional project presentation supplied by a harness. It is separate from
/// identity and is never part of a tab's or workspace's persisted reference.
final class ProjectInfo {
  const ProjectInfo(this.ref, {this.icon});

  final ProjectRef ref;

  /// Image source, when the harness supplies one. Clients may render supported
  /// data or network images; absent or unusable images use their local fallback.
  final Uri? icon;
}
