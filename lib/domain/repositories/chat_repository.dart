import 'package:dartz/dartz.dart';
import '../entities/chat_message.dart';
import '../entities/chat_realtime.dart';
import '../entities/chat_session.dart';
import '../../core/errors/failures.dart';

/// Technical comment translated to English.
abstract class ChatRepository {
  /// Technical comment translated to English.
  Future<Either<Failure, List<ChatSession>>> getSessions({
    String? directory,
    String? search,
    bool? rootsOnly,
    int? startEpochMs,
    int? limit,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, ChatSession>> getSession(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, ChatSession>> createSession(
    String projectId,
    SessionCreateInput input, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, ChatSession>> updateSession(
    String projectId,
    String sessionId,
    SessionUpdateInput input, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, void>> deleteSession(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, ChatSession>> shareSession(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, ChatSession>> unshareSession(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, ChatSession>> forkSession(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, Map<String, SessionStatusInfo>>> getSessionStatus({
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, List<ChatSession>>> getSessionChildren(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, List<SessionTodo>>> getSessionTodo(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, List<SessionDiff>>> getSessionDiff(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, List<ChatMessage>>> getMessages(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, ChatMessage>> getMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Stream<Either<Failure, ChatMessage>> sendMessage(
    String projectId,
    String sessionId,
    ChatInput input, {
    String? directory,
  });

  /// Subscribe to global session/message events from SSE.
  Stream<Either<Failure, ChatEvent>> subscribeEvents({String? directory});

  /// List pending permission requests.
  Future<Either<Failure, List<ChatPermissionRequest>>> listPermissions({
    String? directory,
  });

  /// Respond to a permission request.
  Future<Either<Failure, void>> replyPermission({
    required String requestId,
    required String reply,
    String? message,
    String? directory,
  });

  /// List pending question requests.
  Future<Either<Failure, List<ChatQuestionRequest>>> listQuestions({
    String? directory,
  });

  /// Submit answers for a question request.
  Future<Either<Failure, void>> replyQuestion({
    required String requestId,
    required List<List<String>> answers,
    String? directory,
  });

  /// Reject a question request.
  Future<Either<Failure, void>> rejectQuestion({
    required String requestId,
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, void>> abortSession(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, void>> revertMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, void>> unrevertMessages(
    String projectId,
    String sessionId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, void>> initSession(
    String projectId,
    String sessionId, {
    required String messageId,
    required String providerId,
    required String modelId,
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, void>> summarizeSession(
    String projectId,
    String sessionId, {
    required String providerId,
    required String modelId,
    String? directory,
  });
}
