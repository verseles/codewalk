import 'package:equatable/equatable.dart';

/// Agent option exposed by `/agent` for composer selection.
class Agent extends Equatable {
  const Agent({
    required this.name,
    required this.mode,
    required this.hidden,
    required this.native,
  });

  final String name;
  final String mode;
  final bool hidden;
  final bool native;

  @override
  List<Object?> get props => [name, mode, hidden, native];
}
