import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';

QrInput createQrInput(GlobalKey<NavigatorState> navigator) => _Unavailable();

final class _Unavailable implements QrInput {
  @override
  bool get cameraAvailable => false;
  @override
  QrInputTask image() => _Task();
  @override
  QrInputTask camera() => _Task();
}

final class _Task implements QrInputTask {
  @override
  Future<String?> get result =>
      Future.error(const QrInputException(QrInputFailure.unavailable));
  @override
  void cancel() {}
}
