import '../../core/i18n/l10n_bridge.dart';
import 'local_opencode_server_runtime_types.dart';

LocalOpencodeServerRuntime createLocalOpencodeServerRuntime() {
  return _UnsupportedLocalOpencodeServerRuntime();
}

class _UnsupportedLocalOpencodeServerRuntime
    implements LocalOpencodeServerRuntime {
  @override
  bool get isSupported => false;

  @override
  bool get isRunning => false;

  @override
  Stream<String> get stdoutLines => const Stream<String>.empty();

  @override
  Stream<String> get stderrLines => const Stream<String>.empty();

  @override
  Stream<int> get exitCodes => const Stream<int>.empty();

  @override
  Future<LocalOpencodeServerStartResult> start({
    required String host,
    required int port,
    String? commandPath,
  }) async {
    return LocalOpencodeServerStartResult(
      ok: false,
      errorMessage:
          L10nBridge.current?.appProviderDesktopOnly ??
          'Managed local server is available only on desktop.',
    );
  }

  @override
  Future<LocalOpencodeEnvironmentReport> diagnose({String? commandPath}) async {
    return LocalOpencodeEnvironmentReport(
      supported: false,
      platform: 'unsupported',
      opencode: LocalToolStatus(
        available: false,
        note:
            L10nBridge.current?.appProviderDesktopOnly ??
            'Managed local server is available only on desktop.',
      ),
      node: const LocalToolStatus(available: false),
      npm: const LocalToolStatus(available: false),
      bun: const LocalToolStatus(available: false),
      wsl: const LocalToolStatus(available: false),
      hasNetworkAccess: false,
      installDirectoryWritable: false,
      recommendation:
          L10nBridge.current?.appProviderDesktopBuildRequired ??
          'Use a desktop build to configure a managed local server.',
    );
  }

  @override
  Future<LocalOpencodeInstallResult> install({
    required LocalOpencodeInstallMethod method,
    void Function(String line)? onLog,
  }) async {
    onLog?.call('Managed local server is available only on desktop.');
    return LocalOpencodeInstallResult(
      ok: false,
      errorMessage:
          L10nBridge.current?.appProviderDesktopOnly ??
          'Managed local server is available only on desktop.',
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
