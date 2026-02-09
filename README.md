# CodeWalk

A cross-platform client for [OpenCode](https://github.com/sst/opencode) server mode. Built with Flutter, it provides a conversational interface for session-based AI coding interactions over HTTP APIs and streaming events.

## Features

- AI chat interface with streaming responses
- Server connection with configurable host, port, and authentication
- Session management (create, switch, delete, share)
- Multi-provider and model selection
- Responsive chat layout (mobile drawer, desktop split view)
- Desktop keyboard shortcuts (`Ctrl/Cmd + N`, `Ctrl/Cmd + R`, `Ctrl/Cmd + L`, `Esc`)
- Markdown rendering with syntax highlighting
- Dark theme with Material Design 3

## Getting Started

### Prerequisites

- Flutter SDK (>=3.8.1)
- Dart SDK
- An OpenCode-compatible server instance
- Platform toolchain for your target:
  - Linux desktop: `clang`, `cmake`, `ninja`, `pkg-config`
  - Windows desktop: build from a Windows host
  - macOS desktop: build from a macOS host

### Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app (examples):
   ```bash
   flutter run -d linux
   flutter run -d chrome
   flutter run -d android
   ```

3. Build artifacts (examples):
   ```bash
   flutter build linux
   flutter build web
   ```

### Server Configuration

1. Launch the app and navigate to **Server Settings**
2. Enter your server host and port (e.g., `127.0.0.1:4096`)
3. Configure authentication if required (API key or basic auth)
4. Use **Test Connection** to verify connectivity

## Architecture

The project follows Clean Architecture with three layers: Domain, Data, and Presentation. Dependency injection via `get_it`, HTTP via `dio`, state management via `provider`.

For full technical details, see [CODEBASE.md](CODEBASE.md).

## Tech Stack

- **Framework:** Flutter
- **Language:** Dart
- **State Management:** Provider
- **HTTP Client:** Dio
- **Local Storage:** SharedPreferences
- **Dependency Injection:** GetIt
- **Design System:** Material Design 3

## License

This project is dual-licensed:

- **Open Source:** [GNU Affero General Public License v3.0 (AGPLv3)](LICENSE) -- free for everyone.
- **Commercial:** A [separate commercial license](LICENSE-COMMERCIAL.md) is available for organizations with annual revenue exceeding USD 500M that wish to use the software without AGPLv3 obligations.

## Origin and Acknowledgment

CodeWalk is a fork of [OpenMode](https://github.com/easychen/openMode), originally created by [easychen](https://github.com/easychen). The original project is licensed under MIT.

Substantial modifications have been made since the fork, including licensing changes, code restructuring, rebranding, full English standardization, and documentation rewrites. All modifications are licensed under AGPLv3 (or the commercial license, where applicable).

See [NOTICE](NOTICE) for full attribution details.
