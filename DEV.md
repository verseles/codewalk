# CodeWalk Development Guide

## Project Overview

CodeWalk is a Flutter mobile client for OpenCode-compatible server mode workflows. It provides a mobile interface for session-based AI coding interactions over HTTP APIs and streaming events.

## Core Capability Areas

### 1. Session Management

- Create, update, delete sessions
- Parent/child session structure support
- Session share metadata handling
- Session history retrieval

### 2. Chat System

- Send messages to selected provider/model
- Support typed message parts (text/file/tool/agent)
- Receive streaming assistant updates
- Support message revert/recovery flows

### 3. File-Oriented Workflows

- File discovery/read actions (server capability dependent)
- Symbol/find operations (server capability dependent)
- Project context aware operations

### 4. Provider Management

- Multi-provider setup support
- Model selection and default model mapping
- API key / server auth handling (including basic auth path)

### 5. Agent Workflows

- Agent selection and run configuration
- Built-in and custom agent compatibility
- Tool permission toggles per request

## Technical Stack

- Flutter
- Dart
- Dio for HTTP/SSE transport
- Provider for state management
- SharedPreferences for local persisted settings/cache
- GetIt for dependency injection

## Architecture Pattern

The app follows a Clean Architecture layout:

```text
lib/
  core/           # constants, errors, network, DI
  data/           # datasources, models, repository impls
  domain/         # entities, repository contracts, use cases
  presentation/   # pages, widgets, providers, theme
  main.dart       # entry point
```

### Layer Responsibilities

- `core`: cross-cutting infra and shared primitives
- `data`: server/local integration + DTO mapping
- `domain`: business contracts and use-case orchestration
- `presentation`: UI state and interaction logic

## Module Overview

### Authentication and Server Config

- Server host/port setup
- API key/basic auth setup
- Connection checks and error feedback

### Session Module

- Session list loading and caching
- Session selection and current session persistence
- Create/delete/update/share operations

### Chat Module

- Streaming send/receive flow
- Message list rendering and updates
- Chat input and provider/model context

### Settings Module

- Runtime configuration
- Theme and local preferences
- Provider defaults and server details

## API Surface (High Level)

- `/app`
- `/session`
- `/session/{id}/message`
- `/config/providers`
- `/event`

Exact payload details should be verified against the current server mode docs in Feature 006.

## Data Model Notes

Core domain entities include:

- `Session`
- `Message`
- `Provider`
- `ChatSession`
- `ChatMessage`

The data layer models map API responses to these domain objects and enforce conversion boundaries.

## UX and UI Notes

- Material-based mobile UI
- Chat-first interaction flow
- Session navigation and message timeline
- Explicit loading and error states

## Build and Validation

### Common Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### Optional Build Targets

```bash
flutter build apk --debug
flutter build apk --release
```

## Test Strategy

### Scope

- Unit tests for model mapping/use cases
- Widget tests for chat/session flows
- Integration tests with controllable server responses

### Suggested Targets

- Core business logic: high coverage
- UI behavior: medium coverage
- End-to-end path: smoke + key regressions

## Release and Maintenance

### Release Considerations

- Verify server compatibility before release
- Validate session/chat/provider critical paths
- Confirm no regression in saved settings and auth

### Ongoing Maintenance

- Track API drift and update models/use cases
- Keep dependency versions within tested ranges
- Maintain roadmap and ADR alignment for major decisions

## Current Execution Context

This document is operational guidance. For migration sequencing and feature status, refer to:

- `ROADMAP.md`
- `ROADMAP.feat004.md`
- `ROADMAP.feat005.md`
- `ADR.md`
