import '../../shared/sessions/session_attachments.dart';
import 'attachment_blob_store_stub.dart'
    if (dart.library.io) 'attachment_blob_store_io.dart'
    as impl;

AttachmentBlobRepository createAttachmentBlobStore() =>
    impl.createAttachmentBlobStore();
