import 'metadata_store.dart';
import 'payload_io.dart';
import 'payload_store.dart';

PayloadStore createPayloadStore(V2MetadataStore metadata) =>
    FilePayloadStore(beforeMutation: metadata.ensureSchema);
