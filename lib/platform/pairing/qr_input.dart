import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';

import 'qr_input_stub.dart' if (dart.library.io) 'qr_input_io.dart' as platform;

QrInput createQrInput(GlobalKey<NavigatorState> navigator) =>
    platform.createQrInput(navigator);
