import 'package:dartz/dartz.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/chat_session_model.dart';

/// Chat repository implementation
class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl({required this.remoteDataSource});

  final ChatRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<ChatSession>>> getSessions({
    String? directory,
  }) async {
    try {
      final sessions = await remoteDataSource.getSessions(directory: directory);
      return Right(sessions.map((s) => s.toDomain()).toList());
    } on ServerException {
      return const Left(ServerFailure('Failed to load sessions'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, ChatSession>> getSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final session = await remoteDataSource.getSession(
        projectId,
        sessionId,
        directory: directory,
      );
      return Right(session.toDomain());
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to load session'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, ChatSession>> createSession(
    String projectId,
    SessionCreateInput input, {
    String? directory,
  }) async {
    try {
      final inputModel = SessionCreateInputModel.fromDomain(input);
      final session = await remoteDataSource.createSession(
        projectId,
        inputModel,
        directory: directory,
      );
      return Right(session.toDomain());
    } on ValidationException {
      return const Left(ValidationFailure('Invalid input parameters'));
    } on ServerException {
      return const Left(ServerFailure('Failed to create session'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, ChatSession>> updateSession(
    String projectId,
    String sessionId,
    SessionUpdateInput input, {
    String? directory,
  }) async {
    try {
      final inputModel = SessionUpdateInputModel.fromDomain(input);
      final session = await remoteDataSource.updateSession(
        projectId,
        sessionId,
        inputModel,
        directory: directory,
      );
      return Right(session.toDomain());
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ValidationException {
      return const Left(ValidationFailure('Invalid input parameters'));
    } on ServerException {
      return const Left(ServerFailure('Failed to update session'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      await remoteDataSource.deleteSession(
        projectId,
        sessionId,
        directory: directory,
      );
      return const Right(null);
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to delete session'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, ChatSession>> shareSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final session = await remoteDataSource.shareSession(
        projectId,
        sessionId,
        directory: directory,
      );
      return Right(session.toDomain());
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to share session'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, ChatSession>> unshareSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final session = await remoteDataSource.unshareSession(
        projectId,
        sessionId,
        directory: directory,
      );
      return Right(session.toDomain());
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to unshare session'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getMessages(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final messages = await remoteDataSource.getMessages(
        projectId,
        sessionId,
        directory: directory,
      );
      return Right(messages.map((m) => m.toDomain()).toList());
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to load message list'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, ChatMessage>> getMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  }) async {
    try {
      final message = await remoteDataSource.getMessage(
        projectId,
        sessionId,
        messageId,
        directory: directory,
      );
      return Right(message.toDomain());
    } on NotFoundException {
      return const Left(NotFoundFailure('Message not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to load message'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Stream<Either<Failure, ChatMessage>> sendMessage(
    String projectId,
    String sessionId,
    ChatInput input, {
    String? directory,
  }) async* {
    try {
      final inputModel = ChatInputModel.fromDomain(input);
      final messageStream = remoteDataSource.sendMessage(
        projectId,
        sessionId,
        inputModel,
        directory: directory,
      );

      await for (final message in messageStream) {
        yield Right(message.toDomain());
      }
    } on NotFoundException {
      yield const Left(NotFoundFailure('Session not found'));
    } on ValidationException {
      yield const Left(ValidationFailure('Invalid input parameters'));
    } on ServerException {
      yield const Left(ServerFailure('Failed to send message'));
    } on NetworkException {
      yield const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      yield const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, void>> abortSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      await remoteDataSource.abortSession(
        projectId,
        sessionId,
        directory: directory,
      );
      return const Right(null);
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to abort session'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, void>> revertMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  }) async {
    try {
      await remoteDataSource.revertMessage(
        projectId,
        sessionId,
        messageId,
        directory: directory,
      );
      return const Right(null);
    } on NotFoundException {
      return const Left(NotFoundFailure('Message not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to revert message'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, void>> unrevertMessages(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      await remoteDataSource.unrevertMessages(
        projectId,
        sessionId,
        directory: directory,
      );
      return const Right(null);
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to restore messages'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, void>> initSession(
    String projectId,
    String sessionId, {
    required String messageId,
    required String providerId,
    required String modelId,
    String? directory,
  }) async {
    try {
      await remoteDataSource.initSession(
        projectId,
        sessionId,
        messageId: messageId,
        providerId: providerId,
        modelId: modelId,
        directory: directory,
      );
      return const Right(null);
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ValidationException {
      return const Left(ValidationFailure('Invalid input parameters'));
    } on ServerException {
      return const Left(ServerFailure('Failed to initialize session'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, void>> summarizeSession(
    String projectId,
    String sessionId, {
    required String providerId,
    required String modelId,
    String? directory,
  }) async {
    try {
      await remoteDataSource.summarizeSession(
        projectId,
        sessionId,
        providerId: providerId,
        modelId: modelId,
        directory: directory,
      );
      return const Right(null);
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to summarize session'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }
}
