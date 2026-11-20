import '../../shared/media/attachment_picker.dart';
import 'attachment_picker_stub.dart'
    if (dart.library.io) 'attachment_picker_io.dart'
    as impl;

AttachmentPickerPort createAttachmentPickerPort() =>
    impl.createAttachmentPickerPort();

AttachmentFileOpener createAttachmentFileOpener() =>
    impl.createAttachmentFileOpener();

MapUriLauncher createMapUriLauncher() => impl.createMapUriLauncher();
