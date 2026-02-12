import 'package:equatable/equatable.dart';

/// Agent option exposed by `/agent` for composer selection.
class Agent extends Equatable {
  const Agent({
    required this.name,
    required this.mode,
    required this.hidden,
    required this.native,
    this.color,
  });

  final String name;
  final String mode;
  final bool hidden;
  final bool native;
  final String? color;

  @override
  List<Object?> get props => [name, mode, hidden, native, color];
}
