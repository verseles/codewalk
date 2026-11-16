import '../../shared/sessions/project_icon_data.dart';
import 'project_icon_loader_stub.dart'
    if (dart.library.io) 'project_icon_loader_io.dart'
    as platform;

// Small shared image cache: tabs, lists and pickers reuse identical bytes and
// concurrent fetches. Nothing persists, and failed/remote images expire too.
final _images = <Uri, (DateTime, Future<ProjectIconData?>)>{};

Future<ProjectIconData?> loadProjectIcon(Uri uri) {
  final now = DateTime.now();
  final cached = _images.remove(uri);
  if (cached != null &&
      now.difference(cached.$1) < const Duration(minutes: 1)) {
    _images[uri] = cached;
    return cached.$2;
  }
  final image = uri.isScheme('data')
      ? Future.value(ProjectIconData.fromDataUri(uri))
      : platform.loadNetworkProjectIcon(uri);
  _images[uri] = (now, image);
  while (_images.length > 32) {
    _images.remove(_images.keys.first);
  }
  return image;
}
