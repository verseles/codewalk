# OpenMode

![](./assets/images/logo.256.png)

> 🚧 [WIP] This app is a work in progress, and only basic features are implemented.

> 🤖 [Vibe Project] The vast majority of the code was implemented by Cursor.

**Mobile App for OpenCode and more**

OpenMode is a mobile client for [OpenCode](https://github.com/sst/opencode) (and more, maybe). Built with Flutter, it provides a seamless and intuitive interface for interacting with AI assistants, managing code projects, and enhancing your development workflow on the go.



https://github.com/user-attachments/assets/75236c93-5741-4b51-ab45-9fdf7900f0ae



## ✨ Features

- 🤖 **AI Chat Interface**: Engage in natural conversations with AI assistants
- 🔗 **Server Connection**: Connect to OpenCode servers with configurable settings
- 💬 **Session Management**: Create and manage multiple chat sessions
- 🎨 **Modern UI**: Beautiful dark theme with Material Design 3
- 📱 **Cross-platform**: Built with Flutter for iOS and Android
- ⚡ **Real-time Communication**: Instant messaging with AI assistants
- 🔧 **Configurable**: Flexible server configuration options

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.8.1)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- OpenCode server instance

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/openmode.git
   cd openmode
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Configuration

1. Launch the app
2. Navigate to **Server Settings**
3. Configure your OpenCode server:
   - **Host Address**: Your server IP (e.g., 127.0.0.1)
   - **Port**: Your server port (e.g., 4096)
4. Tap **Test Connection** to verify connectivity
5. Save your settings

## 📱 Screenshots

*Screenshots coming soon...*

## 🏗️ Architecture

OpenMode follows Clean Architecture principles with clear separation of concerns:

```
lib/
├── core/                 # Core utilities and constants
│   ├── constants/       # App and API constants
│   ├── di/             # Dependency injection
│   ├── errors/         # Error handling
│   ├── network/        # Network client configuration
│   └── utils/          # Utility functions
├── data/               # Data layer
│   ├── datasources/    # Local and remote data sources
│   ├── models/         # Data models
│   └── repositories/   # Repository implementations
├── domain/             # Business logic layer
│   ├── entities/       # Business entities
│   ├── repositories/   # Repository interfaces
│   └── usecases/       # Business use cases
└── presentation/       # UI layer
    ├── pages/          # App screens
    ├── providers/      # State management
    ├── theme/          # App theming
    └── widgets/        # Reusable UI components
```

## 🛠️ Tech Stack

- **Framework**: Flutter
- **Language**: Dart
- **State Management**: Provider
- **HTTP Client**: Dio
- **Local Storage**: SharedPreferences
- **Dependency Injection**: GetIt
- **Architecture**: Clean Architecture
- **Design System**: Material Design 3


## 📄 License

This project is dual-licensed:

- **Open Source:** [GNU Affero General Public License v3.0 (AGPLv3)](LICENSE) — free for everyone.
- **Commercial:** A [separate commercial license](LICENSE-COMMERCIAL.md) is available for organizations with annual revenue exceeding USD 500M that wish to use the software without AGPLv3 obligations.

See [NOTICE](NOTICE) for attribution and origin details.

## 🙏 Acknowledgments

- OpenCode team for the amazing AI assistant platform
- Flutter team for the excellent mobile framework
- Material Design team for the beautiful design system
