import '../../shared/sessions/session_attachments.dart';
import 'attachment_blob_store.dart';

AttachmentBlobRepository createAttachmentBlobStore() =>
    MemoryAttachmentBlobStore();
