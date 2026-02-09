# AI Chat Feature Implementation

## Overview

This document describes the AI chat implementation in the Flutter app. The feature is based on the same server-mode interaction model used by OpenCode and provides a complete conversational workflow.

## Architecture

### Clean Architecture Layers

```text
presentation/     # UI layer
  pages/          # Chat page and navigation
  widgets/        # Message/input/session list widgets
  providers/      # State management

domain/           # Business layer
  entities/       # ChatSession, ChatMessage, parts
  repositories/   # Repository contracts
  usecases/       # Message/session operations

data/             # Data layer
  models/         # DTO and mapping models
  datasources/    # Remote APIs
  repositories/   # Repository implementations
```

### Core Entities

- `ChatMessage`
  - Supports user and assistant messages.
  - Supports typed parts (`TextPart`, `FilePart`, `ToolPart`, `ReasoningPart`).
- `ChatSession`
  - Session identity and metadata.
  - Optional share/summary information.
  - Path/workspace linkage.

## API Integration

### Primary Endpoints

- `GET /session` - list sessions
- `POST /session` - create session
- `GET /session/:id/message` - list messages
- `POST /session/:id/message` - send message (streaming updates)
- `DELETE /session/:id` - delete session
- `POST /session/:id/share` - share session

### Streaming Update Flow

- Uses SSE events (`/event`) for incremental message updates.
- Client merges event updates with full message fetch when needed.
- Handles transient errors and stream close paths.

## Delivered Features

### Session Management

- Implemented:
  - Create session
  - List sessions
  - Select/switch session
- Partial (UI present, full backend wiring pending in historical plan):
  - Rename session
  - Delete session advanced controls
  - Share/unshare advanced controls

### Messaging

- Implemented:
  - Send text message
  - Receive streaming assistant response
  - Message history display
  - Markdown rendering
  - Copy message
- Partial:
  - File upload pipeline
  - Image upload pipeline

### UX and State

- Provider-based reactive state updates
- Loading/error states and retry paths
- Auto-scroll behavior with stream updates
- Input state control during send/stream lifecycle

## Technical Notes

### State Management

- `Provider` is used for app/chat/project state.
- Chat updates are streamed and folded into UI state.

### Persistence/Config

- Runtime data synchronized via REST endpoints.
- Local preferences/cache used for selected session/settings.

### Dependency Injection

- `GetIt` container for datasource/repository/use-case/provider wiring.

### Error Handling

- Exceptions mapped to domain failures.
- User-facing messages normalized in provider layer.

## Usage

### Start a Chat

1. Open chat from home.
2. Load existing sessions or create a new one.
3. Select provider/model as needed.

### Send a Message

1. Enter text.
2. Send by button/keyboard action.
3. Observe streamed assistant updates.

### Manage Sessions

1. Open session list from navigation/menu.
2. Switch sessions as needed.
3. Create additional sessions for new topics.

## Environment Requirements

- Flutter SDK compatible with current `pubspec.yaml`
- Reachable OpenCode-compatible server endpoint
- Network path that supports SSE updates

## Remaining Work (Historical Backlog)

### High Priority

- File upload + send
- Image upload + display
- Full session management actions (rename/delete/share UX parity)
- Revert/resend flows hardening

### Medium Priority

- Offline cache improvements
- Message search
- Chat export
- Additional theme customization

### Low Priority

- Voice input
- Message encryption options
- Multi-language support framework
- Accessibility improvements

## Validation Commands

```bash
flutter analyze
flutter build apk --debug
flutter test
```

## Summary

The AI chat feature is integrated and usable end-to-end with session-based context and streaming responses. The implementation follows a maintainable layered structure and can be extended incrementally for file/media workflows and deeper session controls.
