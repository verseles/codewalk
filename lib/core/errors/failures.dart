import 'package:equatable/equatable.dart';

/// Base failure type
abstract class Failure extends Equatable {
  final String message;
  final int? code;

  const Failure(this.message, [this.code]);

  @override
  List<Object?> get props => [message, code];
}

/// Network failure
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.code]);
}

/// Server failure
class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.code]);
}

/// Auth failure
class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.code]);
}

/// Cache failure
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Parse failure
class ParseFailure extends Failure {
  const ParseFailure(super.message);
}

/// Validation failure
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// File failure
class FileFailure extends Failure {
  const FileFailure(super.message);
}

/// Not found failure
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// Unknown failure
class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
