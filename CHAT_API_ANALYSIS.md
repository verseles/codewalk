# Chat API Analysis Report

## Resolution Summary

### 1. Auto-scroll behavior fixed

Problem:
After AI replies, the message list did not always scroll to the latest message.

Root cause:
- `_scrollToBottom()` was only triggered when the user sent a message.
- Incoming assistant updates did not always trigger the same scroll path.

Solution implemented:
1. Added a scroll callback mechanism in `ChatProvider`.
2. Triggered scroll updates from `_updateOrAddMessage`.
3. Added smart-scroll behavior so auto-scroll runs only when the user is near the bottom, reducing disruption while reading history.

Updated files:
- `lib/presentation/providers/chat_provider.dart`
- `lib/presentation/pages/chat_page.dart`

### 2. Message API payload history requirement validated

Question:
Does `POST /session/:id/message` require full conversation history in the request?

Conclusion:
No. The API expects only the current message payload.

Evidence:
- API contract for `POST /session/:id/message` maps to `ChatInput`.
- `ChatInput` includes only current-message `parts` plus metadata (`sessionID`, `providerID`, `modelID`, etc.).
- The server maintains conversation context using `sessionID`.
- The TUI implementation follows the same pattern.

Current Flutter implementation is correct:

```dart
final input = ChatInput(
  messageId: messageId,
  providerId: _selectedProviderId ?? 'anthropic',
  modelId: _selectedModelId ?? 'claude-3-5-sonnet-20241022',
  agent: 'general',
  system: '',
  tools: const {},
  parts: [TextInputPart(text: text)],
);
```

## Request/Context Model

1. Create session via `POST /session` to obtain `sessionID`.
2. Send only current message via `POST /session/:id/message`.
3. Server restores and manages conversation context by `sessionID`.
4. Fetch full history via `GET /session/:id/message`.

## Benefits

- Smaller request payloads.
- Lower client complexity.
- Better performance for frequent chat updates.
- Centralized context optimization on server side.

## Final Status

- Auto-scroll issue: resolved.
- Message payload strategy: validated and correct.
- Chat flow now shows latest assistant updates reliably while preserving user reading context.
