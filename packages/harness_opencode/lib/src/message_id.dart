import 'dart:math';

const _alphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
const _time36 = 0x1000000000; // 2^36 ms, the span the time prefix keeps
const _ordinals = 0x1000000000000; // 2^48 values of the 12 hex characters
final _official = RegExp(r'^(?:msg|evt)_([0-9a-f]{12})[0-9A-Za-z]{14}$');

/// The 48-bit time ordinal of an official 2.0.22 `msg_`/`evt_` id: the low 36
/// bits of its creation time in ms, then a 12-bit counter. Null for any other
/// shape, including the longer client ids some captures used.
int? openCodeIdOrdinal(String id) {
  final match = _official.firstMatch(id);
  return match == null ? null : int.parse(match.group(1)!, radix: 16);
}

/// Mints `msg_` ids in the official 2.0.22 ascending format
/// (`schema/identifier.ts`): 12 hex characters of `time * 0x1000 + counter`
/// and 14 base62 characters. Revert compares ids as strings, so a minted id
/// must sort after every server id this client observed: time is the local
/// clock plus the largest observed server offset, and never at or below the
/// highest observed ordinal or the previous mint.
///
/// Keep one instance per server; a fresh instance restarts the counter.
/// Ordering across the 36-bit time wrap (about 2.2 years) is upstream's limit.
final class OpenCodeMessageIds {
  OpenCodeMessageIds({DateTime Function()? now, Random? random})
    : _now = now ?? DateTime.now,
      _random = random ?? Random.secure();

  final DateTime Function() _now;
  final Random _random;
  int? _offsetMs;
  int _floor = -1;
  int _lastTime = -1;
  int _counter = 0;

  /// Largest observed `server created - local received`; transit only makes
  /// a sample late, so a smaller one never lowers it.
  int get offsetMs => _offsetMs ?? 0;

  /// Learns from a server id and, when known, its `created` time with the
  /// local time it was received. Ids of other shapes are ignored.
  void observe(String nativeId, {int? created, DateTime? receivedAt}) {
    final ordinal = openCodeIdOrdinal(nativeId);
    if (ordinal == null) return;
    _floor = max(_floor, ordinal);
    if (created == null || receivedAt == null) return;
    // A sample whose id does not carry its own time is not a server clock.
    if (ordinal ~/ 0x1000 != created % _time36) return;
    final sample = created - receivedAt.millisecondsSinceEpoch;
    _offsetMs = max(_offsetMs ?? sample, sample);
  }

  String mint() {
    final time = _now().millisecondsSinceEpoch + offsetMs;
    if (time != _lastTime) {
      _lastTime = time;
      _counter = 0;
    }
    _counter++;
    // Arithmetic, not bit operations, so it stays exact on the Web too.
    var ordinal = ((time % _time36) * 0x1000 + _counter) % _ordinals;
    if (ordinal <= _floor) ordinal = _floor + 1;
    _floor = ordinal;
    final suffix = String.fromCharCodes([
      for (var i = 0; i < 14; i++)
        _alphabet.codeUnitAt(_random.nextInt(256) % 62),
    ]);
    return 'msg_${ordinal.toRadixString(16).padLeft(12, '0')}$suffix';
  }
}
