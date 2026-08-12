import '../../core/i18n/l10n_bridge.dart';

/// Protocol-level abort notice value echoed by the server. Kept as a raw
/// English constant because it is matched against server payloads
/// (`chat_provider_abort_policy_ops.dart`), not displayed directly.
const String kChatAbortNoticeMessage = 'What you want to do different?';

bool isAbortLikeError({String? name, required String message}) {
  final normalizedName = name?.trim().toLowerCase() ?? '';
  final normalizedMessage = message.trim().toLowerCase();

  if (normalizedName.contains('abort') || normalizedName.contains('cancel')) {
    return true;
  }

  return normalizedMessage.contains('aborted') ||
      normalizedMessage.contains('abort') ||
      normalizedMessage.contains('cancelled') ||
      normalizedMessage.contains('canceled') ||
      normalizedMessage.contains('cancelled by user') ||
      normalizedMessage.contains('canceled by user');
}

String normalizeAbortMessageForDisplay(String message, {String? name}) {
  if (isAbortLikeError(name: name, message: message)) {
    return L10nBridge.current?.chatAbortNotice ?? kChatAbortNoticeMessage;
  }
  return message;
}
