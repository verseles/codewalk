import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/voice/speech_dictation.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'composer_input.dart';

/// The composer's mic (#307, native slice): a tap dictates into [text]
/// through the platform's own recognizer, a second tap stops. While it
/// listens the red ball behind the icon (v1's active mic) breathes slowly and
/// swells with the voice. Where the platform has no recognizer it stays off
/// and its tooltip says why.
class ComposerVoiceButton extends StatefulWidget {
  const ComposerVoiceButton({
    super.key,
    required this.text,
    this.enabled = true,
  });

  /// The field the words go into, at its cursor.
  final TextEditingController text;

  /// False while the field takes no edits (a send in flight).
  final bool enabled;

  /// One slow breath while listening, in and out.
  static const breath = Duration(milliseconds: 1800);

  @override
  State<ComposerVoiceButton> createState() => ComposerVoiceButtonState();
}

/// The mic's state; a composer cancels a dictation through it, before it
/// reads the field to send.
class ComposerVoiceButtonState extends State<ComposerVoiceButton>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: ComposerVoiceButton.breath,
  )..addListener(_ease);

  SpeechDictation? _dictation;
  bool _listening = false;

  /// Stopped by the user, waiting for the final words: the ball holds still
  /// and the mic takes no tap until the session ends.
  bool _stopping = false;
  bool _closing = false;

  /// Set once the device said it has no recognizer.
  bool _unavailable = false;

  /// The text around the words: what was before and after the cursor when
  /// the dictation started, and what this button last wrote.
  String _before = '';
  String _after = '';
  String? _written;

  /// The voice level: the latest target (0 to 1) and what is drawn, eased
  /// toward it each frame.
  double _target = 0;
  final _level = ValueNotifier<double>(0);
  double? _floor;
  double? _peak;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dictation = context.read<SpeechDictation?>();
  }

  @override
  void didUpdateWidget(covariant ComposerVoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      oldWidget.text.removeListener(_edited);
      if (_listening) widget.text.addListener(_edited);
    }
    // A field that stops taking edits (a send, the server offline) ends the
    // dictation into it.
    if (oldWidget.enabled && !widget.enabled) cancel();
  }

  /// Ends a dictation at once and drops anything it would still write.
  void cancel() {
    if (!_listening) return;
    _written = null;
    unawaited(_dictation?.cancel());
  }

  @override
  void dispose() {
    _closing = true;
    widget.text.removeListener(_edited);
    if (_listening) unawaited(_dictation?.cancel());
    _breath.dispose();
    _level.dispose();
    super.dispose();
  }

  /// Whether this device can dictate at all.
  bool get _supported => !_unavailable && (_dictation?.supported ?? false);

  bool get _available => _supported && widget.enabled;

  Future<void> _toggle() async {
    final dictation = _dictation;
    if (dictation == null) return;
    if (_listening) {
      unawaited(HapticFeedback.selectionClick());
      setState(() => _stopping = true);
      _breath.stop();
      await dictation.stop();
      return;
    }
    final value = widget.text.value;
    final at = value.selection.isValid
        ? value.selection.end.clamp(0, value.text.length)
        : value.text.length;
    _before = value.text.substring(0, at);
    _after = value.text.substring(at);
    _written = value.text;
    _target = 0;
    _level.value = 0;
    _floor = null;
    _peak = null;
    setState(() => _listening = true);
    widget.text.addListener(_edited);
    if (!MediaQuery.disableAnimationsOf(context)) {
      unawaited(_breath.repeat(reverse: true));
    }
    unawaited(HapticFeedback.selectionClick());
    await dictation.start(onWords: _heard, onLevel: _heardLevel, onEnd: _ended);
  }

  /// The words heard so far take the place of the previous ones, at the
  /// cursor where the dictation started, spaced from the text around them.
  void _heard(String words, bool done) {
    if (!mounted || _written == null) return;
    // A page, sheet or dialog over the composer ends the dictation: nothing
    // is written into a field the user cannot see.
    if (_covered()) {
      cancel();
      return;
    }
    final spoken = words.trim();
    if (spoken.isEmpty) return;
    final lead = _before.isEmpty || RegExp(r'\s$').hasMatch(_before) ? '' : ' ';
    final trail = _after.isEmpty || _after.startsWith(RegExp(r'\s')) ? '' : ' ';
    final head = '$_before$lead$spoken';
    final text = '$head$trail$_after';
    _written = text;
    widget.text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: head.length),
    );
  }

  /// Whether something sits over the composer: a route above its own, or,
  /// since every app route lives in one shell, anything the root navigator
  /// can pop (the model picker, a dialog, a page pushed over the shell).
  bool _covered() {
    if (ModalRoute.isCurrentOf(context) == false) return true;
    final own = Navigator.maybeOf(context);
    final root = Navigator.maybeOf(context, rootNavigator: true);
    return own != null &&
        root != null &&
        !identical(own, root) &&
        root.canPop();
  }

  /// Levels arrive in decibels on a scale each platform sets, so the button
  /// learns the room's quiet and the voice's peak as it listens.
  void _heardLevel(double level) {
    // A silent buffer may report minus infinity; it moves nothing.
    if (!level.isFinite) return;
    final floor = _floor = math.min(_floor ?? level, level);
    // The peak follows the voice up at once and settles back slowly, never
    // closer to the floor than a few decibels, so silence stays still.
    final peak = _peak = math.max(
      floor + 6,
      math.max(level, (_peak ?? level) - 0.05),
    );
    _target = ((level - floor) / (peak - floor)).clamp(0.0, 1.0);
    // With reduced motion the ball stays still; nothing eases it.
  }

  /// Eases the drawn level toward the latest one: quick to rise with the
  /// voice, slower to fall, so the ball moves like breath, not a meter.
  void _ease() {
    final shown = _level.value;
    final rate = _target > shown ? 0.35 : 0.12;
    _level.value = shown + (_target - shown) * rate;
  }

  /// A user's own edit while listening wins: the dictation stops and keeps
  /// their text, as does a send that clears the field.
  void _edited() {
    if (_listening && widget.text.text != _written) {
      _written = null;
      unawaited(_dictation?.cancel());
    }
  }

  void _ended(SpeechDictationEnd end) {
    widget.text.removeListener(_edited);
    // Words after the end, or after the user's own edit, never land.
    _written = null;
    if (_closing) return;
    _breath
      ..stop()
      ..value = 0;
    _target = 0;
    _level.value = 0;
    if (!mounted) return;
    setState(() {
      _listening = false;
      _stopping = false;
      if (end == SpeechDictationEnd.unavailable) _unavailable = true;
    });
    final l10n = context.v2L10n;
    final message = switch (end) {
      SpeechDictationEnd.finished => null,
      SpeechDictationEnd.denied => l10n.composerVoiceDenied,
      SpeechDictationEnd.unavailable => l10n.composerVoiceUnavailable,
      SpeechDictationEnd.failed => l10n.composerVoiceFailed,
    };
    if (message != null) {
      showAppSnackBar(ScaffoldMessenger.maybeOf(context), message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final scheme = Theme.of(context).colorScheme;
    final tappable = _listening ? !_stopping : _available;
    // A mic that is only paused (a send, the server offline) still names
    // itself; only a device without a recognizer says it has none.
    final tooltip = _listening && !_stopping
        ? l10n.composerVoiceStop
        : _supported
        ? l10n.composerVoice
        : l10n.composerVoiceUnavailable;
    return SizedBox.square(
      key: const ValueKey('composer-voice'),
      dimension: composerActionSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (_listening)
            IgnorePointer(
              child: AnimatedBuilder(
                key: const ValueKey('composer-voice-ball'),
                animation: Listenable.merge([_breath, _level]),
                builder: (context, _) {
                  final breath = Curves.easeInOut.transform(_breath.value);
                  final level = _level.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // The halo carries the voice; the ball breathes.
                      Transform.scale(
                        scale: 1 + 0.06 * breath + 0.42 * level,
                        child: _Ball(
                          color: scheme.error.withValues(alpha: 0.22),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.9 + 0.08 * breath + 0.12 * level,
                        child: _Ball(color: scheme.error),
                      ),
                    ],
                  );
                },
              ),
            ),
          IconButton(
            key: const ValueKey('composer-voice-button'),
            tooltip: tooltip,
            onPressed: tappable ? () => unawaited(_toggle()) : null,
            padding: EdgeInsets.zero,
            isSelected: _listening,
            icon: const Icon(Symbols.mic, size: 22),
            selectedIcon: Icon(
              Symbols.mic,
              size: 22,
              fill: 1,
              color: scheme.onError,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ball extends StatelessWidget {
  const _Ball({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 34,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}
