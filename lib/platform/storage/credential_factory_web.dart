import 'endpoint_credentials.dart';
import 'metadata_store.dart';

EndpointCredentialVault createEndpointCredentials(V2MetadataStore metadata) =>
    EndpointCredentialVault(
      backend: MemoryEndpointCredentialBackend(),
      beforeMutation: metadata.ensureSchema,
    );
