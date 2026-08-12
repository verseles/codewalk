part of '../chat_input_widget.dart';

extension _ChatInputSpeechController on _ChatInputWidgetState {
  void _focusInputFromExternal() {
    _ensureInputFocus();
  }

  Future<void> _toggleVoiceInputFromExternal() async {
    _ensureInputFocus();
    await _toggleVoiceInput();
  }

  Future<void> _toggleVoiceInput() async {
    if (_isStartingListening) {
      return;
    }
    if (_isListening) {
      await _stopListening();
      return;
    }
    await _startListening();
  }

  Future<_SpeechServiceResolution?> _resolveSpeechServiceForStart(
    SettingsProvider settingsProvider,
    AppLocalizations l10n,
  ) async {
    final primaryEngine = settingsProvider.speechToTextEngine;
    final candidates = <SpeechToTextEngine>[primaryEngine];
    if (primaryEngine == SpeechToTextEngine.native) {
      if (_isSherpaEngineSupported) {
        candidates.add(SpeechToTextEngine.sherpa);
      }
      if (_isParakeetEngineSupported) {
        candidates.add(SpeechToTextEngine.parakeet);
      }
      if (_isSenseVoiceEngineSupported) {
        candidates.add(SpeechToTextEngine.sensevoice);
      }
    } else if (primaryEngine == SpeechToTextEngine.sherpa) {
      candidates.add(SpeechToTextEngine.native);
      if (_isParakeetEngineSupported) {
        candidates.add(SpeechToTextEngine.parakeet);
      }
      if (_isSenseVoiceEngineSupported) {
        candidates.add(SpeechToTextEngine.sensevoice);
      }
    } else if (primaryEngine == SpeechToTextEngine.parakeet) {
      if (_isNativeEngineSupported) {
        candidates.add(SpeechToTextEngine.native);
      }
      if (_isSherpaEngineSupported) {
        candidates.add(SpeechToTextEngine.sherpa);
      }
      if (_isSenseVoiceEngineSupported) {
        candidates.add(SpeechToTextEngine.sensevoice);
      }
    } else if (primaryEngine == SpeechToTextEngine.sensevoice) {
      if (_isNativeEngineSupported) {
        candidates.add(SpeechToTextEngine.native);
      }
      if (_isSherpaEngineSupported) {
        candidates.add(SpeechToTextEngine.sherpa);
      }
      if (_isParakeetEngineSupported) {
        candidates.add(SpeechToTextEngine.parakeet);
      }
    } else {
      if (_isNativeEngineSupported) {
        candidates.add(SpeechToTextEngine.native);
      }
      if (_isSherpaEngineSupported) {
        candidates.add(SpeechToTextEngine.sherpa);
      }
      if (_isParakeetEngineSupported) {
        candidates.add(SpeechToTextEngine.parakeet);
      }
      if (_isSenseVoiceEngineSupported) {
        candidates.add(SpeechToTextEngine.sensevoice);
      }
    }

    String? unavailableReason;
    SpeechInputService? lastAttempted;
    SpeechToTextEngine? lastAttemptedEngine;
    for (var i = 0; i < candidates.length; i++) {
      final engine = candidates[i];
      final service = _serviceForEngine(engine);
      if (service == null) {
        continue;
      }
      lastAttempted = service;
      lastAttemptedEngine = engine;
      if (await service.initialize()) {
        return _SpeechServiceResolution(
          service: service,
          engine: engine,
          usedFallback: i > 0,
          unavailableReason: unavailableReason,
        );
      }
      unavailableReason ??= _localizedUnavailableReason(
        l10n,
        engine,
        service.unavailableReasonKey,
      );
    }

    if (lastAttempted == null) {
      return null;
    }
    return _SpeechServiceResolution(
      service: lastAttempted,
      engine: lastAttemptedEngine ?? candidates.last,
      usedFallback: true,
      unavailableReason: unavailableReason,
    );
  }

  // Maps a typed [SpeechInputService.unavailableReasonKey] to a localized
  // user-facing message at the UI boundary. Speech services must not resolve
  // the locale themselves; they emit stable, locale-independent codes and the
  // widget maps them here where AppLocalizations is always available.
  String _localizedUnavailableReason(
    AppLocalizations l10n,
    SpeechToTextEngine engine,
    String? reasonKey,
  ) {
    final label = _speechEngineLabel(engine);
    return switch (reasonKey) {
      'nativeDisabled' => l10n.speechNativeDisabledWindows,
      'microphoneDenied' => l10n.speechMicPermissionDisabled,
      'desktopOnly' => l10n.speechDesktopOnly(label),
      'runtimeFailed' => l10n.speechRuntimeFailed(label),
      'modelIncomplete' => l10n.speechModelFilesIncomplete(label),
      'platformUnavailable' => l10n.speechUnavailableOnPlatform(label),
      'noInputDevice' => l10n.speechMicNoInputDevice,
      'deviceBusy' => l10n.speechMicDeviceBusy,
      'unsupportedFormat' => l10n.speechMicUnsupportedFormat,
      'speechPrivacy' => l10n.speechMicSpeechPrivacy,
      'backendUnavailable' => l10n.speechMicBackendUnavailable,
      _ => l10n.msgVoiceInputUnavailable,
    };
  }

  Future<void> _startListening() async {
    if (!widget.enabled || _isStartingListening) return;

    if (!mounted) {
      return;
    }

    _startListeningLoading();
    // Let Flutter paint the loading state before potentially heavy STT init.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (!mounted) {
      return;
    }

    final settingsProvider = context.read<SettingsProvider>();
    final l10n = context.l10n;
    final resolution = await _resolveSpeechServiceForStart(
      settingsProvider,
      l10n,
    );
    if (resolution == null) {
      _finishListeningLoading();
      if (!mounted) return;
      _showVoiceInputUnavailableSnackbar(context);
      return;
    }

    final service = resolution.service;
    _activeSpeechService = service;
    if (resolution.usedFallback && mounted) {
      final label = _speechEngineLabel(resolution.engine);
      final reason = resolution.unavailableReason?.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.speechEngineFallbackNotice(
              label,
              reason != null && reason.isNotEmpty
                  ? reason
                  : l10n.msgVoiceInputUnavailable,
            ),
          ),
        ),
      );
    }

    final pauseFor = Duration(
      seconds: settingsProvider.speechSilenceTimeoutSeconds,
    );

    final textWindow = splitComposerTextAtSelection(_controller.value);
    _speechPrefix = textWindow.leadingText;
    _speechSuffix = textWindow.trailingText;
    _speechCommittedText = '';
    try {
      await service.startListening(
        onResult: _onSpeechResult,
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        pauseFor: pauseFor,
        localeId: _localeForService(service, settingsProvider),
      );
      if (!mounted) return;
      _setState(() {
        _isListening = service.isListening;
      });
      if (_isListening) {
        _finishListeningLoading();
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Voice input start failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _setState(() {
        _isListening = false;
      });
      _finishListeningLoading();
      // The just-attempted service is the one whose startListening threw
      // (or whose initialize returned false). Use it for the typed reason
      // instead of the previous _activeSpeechService.
      _showVoiceInputUnavailableSnackbar(
        context,
        reasonService: resolution.service,
      );
    }
  }

  Future<void> _stopListening() async {
    final service = _activeSpeechService;
    if (service == null) {
      _finishListeningLoading();
      if (mounted) {
        _setState(() {
          _isListening = false;
        });
      }
      return;
    }
    try {
      await service.stopListening();
    } catch (_) {
      // Ignore platform stop errors to keep compose flow resilient.
    } finally {
      _finishListeningLoading();
      if (mounted) {
        _setState(() {
          _isListening = false;
        });
      }
    }
  }

  void _onSpeechResult(String recognized, bool isFinal) {
    if (!mounted) return;

    final text = recognized.trim();
    if (isFinal && text.isNotEmpty) {
      _speechCommittedText = _appendSpeechSegment(_speechCommittedText, text);
    }

    final spokenText = isFinal
        ? _speechCommittedText
        : _appendSpeechSegment(_speechCommittedText, text);
    final leadingText = _appendSpeechSegment(_speechPrefix, spokenText);
    final nextValue = composeComposerValueWithSuffix(
      leadingText: leadingText,
      trailingText: _speechSuffix,
    );
    _controller.value = nextValue;

    _setState(() {
      _isComposing = nextValue.text.trim().isNotEmpty;
    });
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;

    // 'model_required' is emitted by downloadable on-device engines when no
    // local model is installed yet. Show the matching setup dialog.
    if (status == 'model_required') {
      _finishListeningLoading();
      final service = _activeSpeechService;
      if (service is MoonshineSpeechInputService) {
        _showMoonshineDownloadDialog();
      } else if (service is ParakeetSpeechInputService) {
        _showParakeetDownloadDialog();
      } else if (service is SenseVoiceSpeechInputService) {
        _showSenseVoiceDownloadDialog();
      } else {
        _showSherpaDownloadDialog();
      }
      return;
    }

    if (status == 'listening' || status == 'done') {
      _finishListeningLoading();
    }

    final service = _activeSpeechService;
    final listening = status == 'listening' || (service?.isListening ?? false);
    if (_isListening == listening) return;
    _setState(() {
      _isListening = listening;
    });
  }

  void _onSpeechError() {
    if (!mounted) return;
    _finishListeningLoading();
    _setState(() {
      _isListening = false;
    });
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    if (isWindows) {
      _showVoiceInputUnavailableSnackbar(
        context,
        reasonService: _activeSpeechService,
      );
    }
  }

  Future<void> _showSherpaDownloadDialog() async {
    if (!mounted) return;
    _finishListeningLoading();
    _setState(() {
      _isListening = false;
    });
    final downloaded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SherpaModelDownloadDialog(),
    );
    // Re-initialize the service (model is now on disk) and start listening.
    if (downloaded == true && mounted) {
      _sherpaSpeechServiceInstance = null;
      _activeSpeechService = null;
      await _startListening();
    }
  }

  Future<void> _showMoonshineDownloadDialog() async {
    if (!mounted) return;
    _finishListeningLoading();
    _setState(() {
      _isListening = false;
    });
    final downloaded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MoonshineModelDownloadDialog(),
    );
    if (downloaded == true && mounted) {
      _moonshineSpeechServiceInstance = null;
      _activeSpeechService = null;
      await _startListening();
    }
  }

  Future<void> _showParakeetDownloadDialog() async {
    if (!mounted) return;
    _finishListeningLoading();
    _setState(() {
      _isListening = false;
    });
    final downloaded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ParakeetModelDownloadDialog(),
    );
    if (downloaded == true && mounted) {
      _parakeetSpeechServiceInstance = null;
      _activeSpeechService = null;
      await _startListening();
    }
  }

  Future<void> _showSenseVoiceDownloadDialog() async {
    if (!mounted) return;
    _finishListeningLoading();
    _setState(() {
      _isListening = false;
    });
    final downloaded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SenseVoiceModelDownloadDialog(),
    );
    if (downloaded == true && mounted) {
      _senseVoiceSpeechServiceInstance = null;
      _activeSpeechService = null;
      await _startListening();
    }
  }

  // Show a snackbar that points the user at the exact Windows settings page
  // when the speech service is unavailable. On non-Windows targets this falls
  // back to the existing `msgVoiceInputUnavailable` copy. On Windows, the
  // action button label and target URI are picked from the typed
  // [unavailableReasonKey] emitted by the active speech service. The caller can
  // pass a [reasonService] (the just-attempted service) to override the
  // default active-service lookup, which avoids stale
  // [unavailableReasonKey] values from a previous successful session.
  void _showVoiceInputUnavailableSnackbar(
    BuildContext context, {
    SpeechInputService? reasonService,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    if (!isWindows) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.msgVoiceInputUnavailable)),
      );
      return;
    }

    final service = reasonService ?? _activeSpeechService;
    final reasonKey = service?.unavailableReasonKey;
    final (String label, Future<bool> Function() action) =
        _windowsActionForReason(reasonKey, l10n);

    final snack = SnackBar(
      content: Text(l10n.msgFailedToStartVoiceInput),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: label,
        onPressed: () => unawaited(action()),
      ),
    );
    messenger.showSnackBar(snack);
  }

  // Map a [SpeechInputService.unavailableReasonKey] to the most relevant
  // Windows settings link. The mapping is intentionally narrow: every key
  // resolves to a single actionable link so the user is never sent to the
  // wrong page.
  (String, Future<bool> Function()) _windowsActionForReason(
    String? reasonKey,
    AppLocalizations l10n,
  ) {
    switch (reasonKey) {
      case 'speechPrivacy':
      case 'noInputDevice':
        return (l10n.speechOpenSpeechSettings, WindowsSettingsLinks.openSpeech);
      case 'deviceBusy':
      case 'unsupportedFormat':
      case 'backendUnavailable':
        return (
          l10n.speechOpenMicrophoneSettings,
          WindowsSettingsLinks.openMicrophonePrivacy,
        );
      case 'microphoneDenied':
      case 'generic':
      case null:
      default:
        return (
          l10n.speechOpenMicrophoneSettings,
          WindowsSettingsLinks.openMicrophonePrivacy,
        );
    }
  }
}
