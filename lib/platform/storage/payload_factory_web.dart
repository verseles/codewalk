import 'metadata_store.dart';
import 'payload_store.dart';

PayloadStore createPayloadStore(V2MetadataStore metadata) =>
    PreferencesPayloadStore(metadata);
