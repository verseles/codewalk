# CodeWalk

![CodeWalk Logo](assets/images/logo.256.png)

A native (really fast!!) cross-platform client for [OpenCode](https://github.com/sst/opencode) server mode. Built with Flutter, it provides a conversational interface for session-based AI coding interactions over HTTP APIs and streaming events.

## Highlights

- AI chat interface with streaming responses and realtime event sync (SSE)
- Multi-server profile management (add, edit, remove, switch, health checks)
- Multi-provider and model selection with variant/reasoning effort controls
- Session lifecycle (create, rename, archive, fork, share, delete)
- Project/workspace context switching with directory-scoped state isolation
- Worktree management (create, reset, delete)
- Image and PDF attachments with model capability gating
- Speech-to-text voice input
- Interactive permission and question prompts from the server
- Chat-first layout with responsive sidebar (mobile drawer, desktop split view)
- Desktop keyboard shortcuts (`Ctrl/Cmd + N`, `Ctrl/Cmd + R`, `Ctrl/Cmd + L`, `Esc`)
- Markdown rendering with syntax highlighting and text selection
- Dark theme with Material Design 3
- Cross-platform: Linux, Windows, macOS, Web, Android

## Install in One Command

Install using the `install.cat` pattern:

- Linux & macOS

  ```bash
  curl -fsSL install.cat/verseles/codewalk | sh
  ```

- Windows (PowerShell)

  ```powershell
  irm install.cat/verseles/codewalk | iex
  ```

Run the same command again any time to update/reinstall to the latest GitHub release.

Installers automatically select the best artifact for your OS/CPU:

- Linux: `x64` and `arm64`
- Windows: `x64` and `arm64` (ARM64 falls back to x64 when needed)
- macOS: `x64` and `arm64`

Release assets are published per OS/architecture (no universal desktop archive).

### Uninstall

- Linux & macOS

  ```bash
  curl -fsSL https://raw.githubusercontent.com/verseles/codewalk/main/uninstall.sh | sh
  ```

- Windows (PowerShell)

  ```powershell
  irm https://raw.githubusercontent.com/verseles/codewalk/main/uninstall.ps1 | iex
  ```

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

### Make Targets

```bash
make check      # deps + codegen + analyze + test
make android    # build arm64 APK
make precommit  # check + android
```

### Server Configuration

1. Launch the app and open **Settings** from the sidebar
2. Add a server profile with host and port (e.g., `127.0.0.1:4096`)
3. Configure authentication if required (API key or basic auth)
4. Use **Test Connection** to verify connectivity
5. Multiple server profiles can be added and switched at any time

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
