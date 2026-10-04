import 'credential_factory_web.dart'
    if (dart.library.io) 'credential_factory_io.dart'
    as implementation;

import 'endpoint_credentials.dart';
import 'metadata_store.dart';

EndpointCredentialVault createV2EndpointCredentials(V2MetadataStore metadata) =>
    implementation.createEndpointCredentials(metadata);
