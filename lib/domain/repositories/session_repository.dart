import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/session.dart';
import '../entities/message.dart';

/// Technical comment translated to English.
abstract class SessionRepository {
  /// Technical comment translated to English.
  Future<Either<Failure, List<Session>>> getSessions();

  /// Technical comment translated to English.
  Future<Either<Failure, Session>> getSession(String sessionId);

  /// Technical comment translated to English.
  Future<Either<Failure, Session>> createSession({
    String? parentId,
    String? title,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, Session>> updateSession(
    String sessionId, {
    String? title,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, bool>> deleteSession(String sessionId);

  /// Technical comment translated to English.
  Future<Either<Failure, List<Session>>> getChildSessions(String sessionId);

  /// Technical comment translated to English.
  Future<Either<Failure, Session>> shareSession(String sessionId);

  /// Technical comment translated to English.
  Future<Either<Failure, Session>> unshareSession(String sessionId);

  /// Technical comment translated to English.
  Future<Either<Failure, bool>> abortSession(String sessionId);

  /// Technical comment translated to English.
  Future<Either<Failure, bool>> summarizeSession(
    String sessionId,
    String providerId,
    String modelId,
  );

  /// Technical comment translated to English.
  Future<Either<Failure, List<Message>>> getSessionMessages(String sessionId);

  /// Technical comment translated to English.
  Future<Either<Failure, Message>> sendMessage({
    required String sessionId,
    required String providerId,
    required String modelId,
    required List<MessagePart> parts,
    String? messageId,
    String? agent,
    String? system,
    Map<String, bool>? tools,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, Session>> revertMessage(
    String sessionId,
    String messageId, {
    String? partId,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, Session>> unrevertMessages(String sessionId);
}

/// Technical comment translated to English.
abstract class MessagePart {
  final String type;

  const MessagePart({required this.type});
}

/// Technical comment translated to English.
class TextMessagePart extends MessagePart {
  final String text;
  final bool? synthetic;

  const TextMessagePart({required this.text, this.synthetic})
    : super(type: 'text');
}

/// Technical comment translated to English.
class FileMessagePart extends MessagePart {
  final String mime;
  final String url;
  final String? filename;

  const FileMessagePart({required this.mime, required this.url, this.filename})
    : super(type: 'file');
}

/// Technical comment translated to English.
class AgentMessagePart extends MessagePart {
  final String name;

  const AgentMessagePart({required this.name}) : super(type: 'agent');
}
