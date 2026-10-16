import 'dart:math';
import 'package:codewalk_core/codewalk_core.dart';

CommandId mintCommandId() {
  final random = Random.secure();
  final hex = [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
  return CommandId('cmd_$hex');
}
