import 'package:codewalk_core/codewalk_core.dart';
import '../../shared/sessions/session_catalog_source.dart';
import 'session_catalog_factory_stub.dart'
    if (dart.library.io) 'session_catalog_factory_io.dart'
    as platform;

SessionCatalogSource createSessionCatalogSource(
  EndpointProfile profile,
  EndpointCredential credential,
) => platform.createSessionCatalogSource(profile, credential);
