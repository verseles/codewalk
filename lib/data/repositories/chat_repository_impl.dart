import 'package:dartz/dartz.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_realtime.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/chat_session_model.dart';

/// Chat repository implementation
class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl({required this.remoteDataSource});

  final ChatRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<ChatSession>>> getSessions({
    String? directory,
    String? search,
    bool? rootsOnly,
    int? startEpochMs,
    int? limit,
  }) async {
    try {
      final sessions = await remoteDataSource.getSessions(
        directory: directory,
        search: search,
        rootsOnly: rootsOnly,
        startEpochMs: startEpochMs,
        limit: limit,
      );
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
  Future<Either<Failure, ChatSession>> forkSession(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  }) async {
    try {
      final session = await remoteDataSource.forkSession(
        projectId,
        sessionId,
        messageId: messageId,
        directory: directory,
      );
      return Right(session.toDomain());
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ValidationException {
      return const Left(ValidationFailure('Invalid input parameters'));
    } on ServerException {
      return const Left(ServerFailure('Failed to fork session'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, Map<String, SessionStatusInfo>>> getSessionStatus({
    String? directory,
  }) async {
    try {
      final map = await remoteDataSource.getSessionStatus(directory: directory);
      return Right(map.map((key, value) => MapEntry(key, value.toDomain())));
    } on NotFoundException {
      return const Left(NotFoundFailure('Session status not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to load session status'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, List<ChatSession>>> getSessionChildren(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final children = await remoteDataSource.getSessionChildren(
        projectId,
        sessionId,
        directory: directory,
      );
      return Right(children.map((item) => item.toDomain()).toList());
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to load session children'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, List<SessionTodo>>> getSessionTodo(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    try {
      final todos = await remoteDataSource.getSessionTodo(
        projectId,
        sessionId,
        directory: directory,
      );
      return Right(todos.map((item) => item.toDomain()).toList());
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to load session todo'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, List<SessionDiff>>> getSessionDiff(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  }) async {
    try {
      final diff = await remoteDataSource.getSessionDiff(
        projectId,
        sessionId,
        messageId: messageId,
        directory: directory,
      );
      return Right(diff.map((item) => item.toDomain()).toList());
    } on NotFoundException {
      return const Left(NotFoundFailure('Session not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to load session diff'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
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
    AppLogger.info(
      'Repository send start session=$sessionId provider=${input.providerId} model=${input.modelId} variant=${input.variant ?? "auto"} directory=${directory ?? "-"}',
    );
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
      AppLogger.info('Repository send stream completed session=$sessionId');
    } on NotFoundException {
      AppLogger.warn('Repository send failed: session not found $sessionId');
      yield const Left(NotFoundFailure('Session not found'));
    } on ValidationException {
      AppLogger.warn('Repository send failed: validation error');
      yield const Left(ValidationFailure('Invalid input parameters'));
    } on ServerException {
      AppLogger.warn('Repository send failed: server error');
      yield const Left(ServerFailure('Failed to send message'));
    } on NetworkException {
      AppLogger.warn('Repository send failed: network error');
      yield const Left(NetworkFailure('Network connection failed'));
    } catch (e) {
      AppLogger.error('Repository send failed: unexpected exception', error: e);
      yield const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Stream<Either<Failure, ChatEvent>> subscribeEvents({
    String? directory,
  }) async* {
    try {
      final eventStream = remoteDataSource.subscribeEvents(
        directory: directory,
      );
      await for (final event in eventStream) {
        yield Right(event.toDomain());
      }
    } on ServerException {
      yield const Left(ServerFailure('Failed to subscribe to realtime events'));
    } on NetworkException {
      yield const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
      yield const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Stream<Either<Failure, ChatEvent>> subscribeGlobalEvents() async* {
    try {
      final eventStream = remoteDataSource.subscribeGlobalEvents();
      await for (final event in eventStream) {
        yield Right(event.toDomain());
      }
    } on ServerException {
      yield const Left(ServerFailure('Failed to subscribe to global events'));
    } on NetworkException {
      yield const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
      yield const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, List<ChatPermissionRequest>>> listPermissions({
    String? directory,
  }) async {
    try {
      final items = await remoteDataSource.listPermissions(
        directory: directory,
      );
      return Right(
        items.map((item) => item.toDomain()).toList(growable: false),
      );
    } on NotFoundException {
      return const Left(NotFoundFailure('Permission route not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to list permissions'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, void>> replyPermission({
    required String requestId,
    required String reply,
    String? message,
    String? directory,
  }) async {
    try {
      await remoteDataSource.replyPermission(
        requestId: requestId,
        reply: reply,
        message: message,
        directory: directory,
      );
      return const Right(null);
    } on NotFoundException {
      return const Left(NotFoundFailure('Permission request not found'));
    } on ValidationException {
      return const Left(ValidationFailure('Invalid permission response'));
    } on ServerException {
      return const Left(ServerFailure('Failed to respond permission'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, List<ChatQuestionRequest>>> listQuestions({
    String? directory,
  }) async {
    try {
      final items = await remoteDataSource.listQuestions(directory: directory);
      return Right(
        items.map((item) => item.toDomain()).toList(growable: false),
      );
    } on NotFoundException {
      return const Left(NotFoundFailure('Question route not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to list questions'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, void>> replyQuestion({
    required String requestId,
    required List<List<String>> answers,
    String? directory,
  }) async {
    try {
      await remoteDataSource.replyQuestion(
        requestId: requestId,
        answers: answers,
        directory: directory,
      );
      return const Right(null);
    } on NotFoundException {
      return const Left(NotFoundFailure('Question request not found'));
    } on ValidationException {
      return const Left(ValidationFailure('Invalid question response'));
    } on ServerException {
      return const Left(ServerFailure('Failed to respond question'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
      return const Left(UnknownFailure('Unknown error'));
    }
  }

  @override
  Future<Either<Failure, void>> rejectQuestion({
    required String requestId,
    String? directory,
  }) async {
    try {
      await remoteDataSource.rejectQuestion(
        requestId: requestId,
        directory: directory,
      );
      return const Right(null);
    } on NotFoundException {
      return const Left(NotFoundFailure('Question request not found'));
    } on ServerException {
      return const Left(ServerFailure('Failed to reject question'));
    } on NetworkException {
      return const Left(NetworkFailure('Network connection failed'));
    } catch (_) {
      return const Left(UnknownFailure('Unknown error'));
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
