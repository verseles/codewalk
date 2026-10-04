import 'metadata_store.dart';
import 'payload_factory_web.dart'
    if (dart.library.io) 'payload_factory_io.dart'
    as implementation;

import 'payload_store.dart';

PayloadStore createV2PayloadStore(V2MetadataStore metadata) =>
    implementation.createPayloadStore(metadata);
