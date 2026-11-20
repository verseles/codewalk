# CodeWalk

<p align="center"><img src="demo-desktop.gif" alt="CodeWalk desktop demo" /></p>
<p align="center">https://github.com/user-attachments/assets/032f64e2-e8ee-4024-b49a-ca95a774653f</p>

![CodeWalk Logo](assets/images/logo.256.png)

A fast, native cross-platform client for [OpenCode](https://github.com/anomalyco/opencode) servers — built for mobile and desktop.

> **CodeWalk 2.0** connects directly to **OpenCode 2** servers on Android, Linux, Windows, and macOS (Apple Silicon). Using OpenCode 1? You can stay on CodeWalk 1 via `CODEWALK_CHANNEL=v1` or the web app at [codewalk.verseles.com](https://codewalk.verseles.com) *(v2 Web soon)*.

---

## Features

### Chat & Workspace
- 💬 **Realtime AI chat** — streaming responses, quick history loading, and persistent message drafts.
- 🧩 **Compact activity timeline** — tool calls, shell runs, and reasoning stay on clean single lines and collapse neatly once the assistant replies, while intermediate replies stay visible.
- 🤖 **Subagents & live shells capsule** — track active and completed subagents and shell commands from one floating pill, inspect live output, or stop running tasks.
- 🗂 **Project sidebar & session tabs** — conversations grouped by project with automatic project icons and browser-style tabs on desktop *(per-project tab colors: v2 soon)*.
- 🧠 **Models, agents & permissions** — switch providers, models, variants, and agents, save favorites, answer permission and question prompts, or toggle auto-approval per session.
- ✨ **Rich replies** — Markdown, syntax-highlighted code blocks, inline Mermaid diagrams, LaTeX math, and [basic HTML formatting](#basic-html-in-assistant-replies).
- 📎 **Attachments** — attach images, files/PDFs, audio, and geographic location from the composer `+` button, with timeline image lightbox previews, file cards, inline audio player, and clickable map cards *(drag-and-drop & clipboard paste: v2 soon)*.
- ↩️ **Undo, redo & compact** — step back to earlier turns and compact long sessions *(visual diff & fork views: v2 soon)*.

### Platforms & Experience
- 📱 **Mobile & desktop native** — Material 3 across **Android**, **Linux**, **Windows**, and **macOS (Apple Silicon)** with customizable themes, palettes, and desktop keyboard shortcuts *(Web & iOS: v2 soon)*.
- 🖧 **Multi-server profiles & QR pairing** — switch between multiple OpenCode 2 servers, check connection status, and pair in seconds via QR code or pairing link *(one-click local OpenCode install/launch: v2 soon)*.
- 🌐 **14 languages** — English, Português (Brasil), Español, Deutsch, Français, Italiano, Русский, 中文, 日本語, 한국어, हिन्दी, বাংলা, العربية, and اردو, with right-to-left layout support.
- 🎙 **Voice dictation** — built-in speech-to-text on Android and macOS *(Linux/Windows voice input & read-aloud TTS: v2 soon)*.
- 🔄 **Seamless updates** — automatic update checks and verified in-app installs on Android and managed Linux installs (Windows and macOS update via the one-command scripts below).

### Coming from v1 *(v2 soon)*
- 📁 **File manager & code editor** *(v2 soon)* — browse, open, and edit project files inside the app.
- 🖥 **Embedded terminal** *(v2 soon)* — run commands directly on your OpenCode host.
- 🏷 **Skills & `@` mentions** *(v2 soon)* — reference project files, directories, agents, and skills directly in the composer.
- 📤 **Share, export & forward** *(v2 soon)* — share messages as themed images, export sessions to Markdown/JSON, or forward messages to other sessions.
- 💬 **Canned answers** *(v2 soon)* — reusable global or per-project quick replies.
- 📊 **Context usage & provider quotas** *(v2 soon)* — monitor context window usage and host quotas.
- 🔔 **Notifications & sounds** *(v2 soon)* — alerts when prompts finish or need your approval.
- 🔐 **Cloudflare Access & Tailscale** *(v2 soon)* — built-in support for private remote servers.
- 📶 **Data saver** *(v2 soon)* — reduce background sync on cellular connections.
- 🌐 **Web app (`codewalk.verseles.com`)** *(v2 soon)* — currently runs CodeWalk 1.

---

## Install

### Linux & macOS (Apple Silicon)

```bash
curl -fsSL install.cat/verseles/codewalk | sh
```

### Windows (PowerShell)

```powershell
irm install.cat/verseles/codewalk | iex
```

### Android

Open [install.cat/verseles/codewalk](https://install.cat/verseles/codewalk) in your Android browser to download the signed APK, or grab any build from the [Releases page](https://github.com/verseles/codewalk/releases).

> Run the same install command again any time to update. Published desktop builds cover **Linux (`x64`, `arm64`)**, **Windows (`x64`; Windows ARM64 runs `x64` under emulation)**, and **macOS Apple Silicon (`arm64`)**. Unsigned Windows and ad-hoc signed macOS builds may show a SmartScreen or Gatekeeper prompt on first launch (`install.sh` clears macOS quarantine automatically).

<details>
<summary>Channels, v1 → v2 migration & uninstall</summary>

New installations default to `stable` (CodeWalk 2). Existing CodeWalk 1 installations are protected from accidental upgrades and require explicit consent (`CODEWALK_MIGRATION=accept-v2`). Existing CodeWalk 2 beta installs automatically graduate to stable `v2.0.0` on the next update.

**Linux & macOS:**

```bash
# Stay on CodeWalk 1 (remembered for future updates)
curl -fsSL install.cat/verseles/codewalk | CODEWALK_CHANNEL=v1 sh

# Migrate an existing CodeWalk 1 installation to CodeWalk 2
curl -fsSL install.cat/verseles/codewalk | CODEWALK_MIGRATION=accept-v2 sh

# Opt in to CodeWalk 2 betas
curl -fsSL install.cat/verseles/codewalk | CODEWALK_CHANNEL=beta CODEWALK_MIGRATION=accept-v2 sh

# Install one exact release
curl -fsSL install.cat/verseles/codewalk | CODEWALK_VERSION=v2.0.0 sh

# Uninstall (preserves user data on Linux)
curl -fsSL https://raw.githubusercontent.com/verseles/codewalk/main/uninstall.sh | sh
```

**Windows (PowerShell):**

```powershell
# Stay on CodeWalk 1
$env:CODEWALK_CHANNEL='v1'; irm install.cat/verseles/codewalk | iex

# Migrate an existing CodeWalk 1 installation to CodeWalk 2
$env:CODEWALK_MIGRATION='accept-v2'; irm install.cat/verseles/codewalk | iex

# Uninstall
irm https://raw.githubusercontent.com/verseles/codewalk/main/uninstall.ps1 | iex
```

On Linux, binaries install to `${XDG_DATA_HOME:-$HOME/.local/share}/codewalk-app`, keeping application files separate from user data (`com.verseles.codewalk` and legacy `codewalk`).

</details>

### Connect to Your Server

1. Launch CodeWalk and open **Settings → Servers** (or tap **Add server** on first launch).
2. Scan your server's QR code, open a pairing link, or enter your server URL (default `http://127.0.0.1:4096`).
3. Add Basic Auth credentials if your server requires them, save, and start chatting.

---

## Basic HTML in Assistant Replies

<details>
<summary>Supported tags and examples</summary>

Assistant replies can mix these case-insensitive HTML tags with Markdown. Formatting and progress bars follow the app theme on mobile and desktop.

| Tag | Effect | Example |
| --- | --- | --- |
| `<b>` | Bold | `<b>Important</b>` |
| `<i>` | Italic | `<i>Note</i>` |
| `<u>` | Underline | `<u>Highlighted</u>` |
| `<br>` | Line break; `<br/>` and `<br />` also work | `First line<br>Second line` |
| `<sub>` | Subscript | `H<sub>2</sub>O` |
| `<sup>` | Superscript | `x<sup>2</sup>` |
| `<progress>` | Native progress bar | `<progress value="25" max="100">Loading</progress>` |

Tags inside code blocks stay literal, and copying a message preserves its original markup. Support is limited to the tags above; arbitrary HTML and CSS are not rendered.

</details>

---

## Development

<details>
<summary>Building, testing & releasing from source</summary>

### Prerequisites

- Flutter SDK (`3.47.9`, Dart `>=3.8.1`)
- An OpenCode 2 server instance
- Platform toolchain:
  - Linux: `clang`, `cmake`, `ninja`, `pkg-config`, `libgtk-3-dev`, `libsecret-1-dev`
  - Windows / macOS: native host toolchain

### Run & Build

```bash
flutter pub get
flutter run -d linux --target lib/main_v2.dart
flutter build linux --release --target lib/main_v2.dart
```

### Make Targets

```bash
make check               # deps + analyze + coverage/v2/release tool tests + full test suite
make check-fast          # fast subset of checks
make test-release-tools  # release plan, artifact verifier & publication guards
make v2-native-check     # workspace packages, architecture guard & contract tests
make coverage            # full tests with 85% coverage floor
make release V=beta      # cut the next v2.0.0-beta.N (DRY_RUN=1 prints plan only)
make release V=stable    # graduate main to v2.0.0 (DRY_RUN=1 prints plan only)
```

On `main`, the Release workflow builds and verifies five targets from `lib/main_v2.dart` (Android arm64, Linux x64/ARM64, Windows x64, macOS arm64) and publishes via a create-only release script (`v2.0.0-beta.N` as prerelease, `v2.0.0` as latest stable). Manual dispatch from `main` with `dry_run_version` (`2.0.0-beta.N` or `2.0.0`) builds and verifies all five targets without publishing. CodeWalk 1 releases stay on the `v1` branch.

### Architecture & Tech Stack

CodeWalk 2 uses a modular Dart workspace (`packages/codewalk_core`, `packages/codewalk_net`, `packages/harness_opencode`, `packages/harness_host`) separating canonical domain models and harness adapters from the Flutter UI (`lib/`).

- **Framework:** Flutter & Dart (Material Design 3)
- **Routing & State:** GoRouter, Provider, GetIt
- **Storage:** SharedPreferences & FlutterSecureStorage

</details>

---

## Community

Chat with users, get release news, and send feedback: [Telegram — t.me/codewalkapp](https://t.me/codewalkapp). Release highlights also appear in-app under **Settings → Release history**.

## License

This project is dual-licensed:

- **Open Source:** [GNU Affero General Public License v3.0 (AGPLv3)](LICENSE) — free for everyone.
- **Commercial:** A [separate commercial license](LICENSE-COMMERCIAL.md) is available for organizations with annual revenue exceeding USD 1M that wish to use the software without AGPLv3 obligations.

## Origin and Acknowledgment

CodeWalk is a fork of [OpenMode](https://github.com/easychen/openMode), originally created by [easychen](https://github.com/easychen) under the MIT license. See [NOTICE](NOTICE) for full attribution details.
