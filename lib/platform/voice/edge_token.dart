// The Sec-MS-GEC v2 token of Microsoft Edge's read-aloud service (#541).
//
// Ported from edge-tts 7.3.1 (src/edge_tts/drm.py,
// https://github.com/rany2/edge-tts), Copyright (C) rany2 and contributors,
// licensed under the GNU LGPL v3; this port is distributed with CodeWalk
// under the GNU AGPL v3, which the LGPL v3 permits. The service demands the
// token since October 2026: a SHA-256 resumed from a fixed midstate and a
// CS64 checksum over the rounded Windows file time and the client token.

import 'dart:typed_data';

/// The client token Edge's read-aloud extension sends.
const edgeTrustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';

const _winEpoch = 11644473600;
const _mask = 0xFFFFFFFF;

const _initial = [
  0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A, //
  0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
];
const _midstate = [
  0xFD9FBEA2, 0x91243CE7, 0xBE499094, 0xCD2E1E0A, //
  0x6C006F49, 0x04BD35AB, 0xFEB0A7E4, 0x03EFFBD2,
];
const _schedule = [
  0xEB24BF9E, 0x1558691F, 0xA0C09EE2, 0x0CFA32BA, 0xA622EE8C, //
  0xD1DD9491, 0xC0DD25A0, 0xF9E70AB6, 0xF0C31573, 0x7058CE4E,
  0x7188E606, 0x00E5AB33, 0xD258B060, 0x72766564,
];
const _k = [
  0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5, 0x3956C25B, 0x59F111F1, //
  0x923F82A4, 0xAB1C5ED5, 0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
  0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174, 0xE49B69C1, 0xEFBE4786,
  0x0FC19DC6, 0x240CA1CC, 0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
  0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7, 0xC6E00BF3, 0xD5A79147,
  0x06CA6351, 0x14292967, 0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
  0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85, 0xA2BFE8A1, 0xA81A664B,
  0xC24B8B70, 0xC76C51A3, 0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
  0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5, 0x391C0CB3, 0x4ED8AA4A,
  0x5B9CCA4F, 0x682E6FF3, 0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
  0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
];
const _adjustment = 0xC9DC06A7;
const _sigma0Adjustment = 0x059C0B80;
const _sigma1Adjustment = 0x000B92C0;
const _cs64Coefficients = [
  (0xE82E91B1, 0xB32700D0), (0x44DE24C6, 0x88DFF51D), //
  (0x3BEB65BC, 0x29514038), (0xC89C5933, 0xB328CBDF),
  (0x8D1EC211, 0xD405B4D5), (0x314EF5D5, 0x26E55F3C),
  (0xE92491B1, 0x607801C6), (0xF0A5B9D5, 0x82B2C1FB),
  (0x06064CF3, 0xFA51A3DA), (0xDA79FA60, 0x207CC464),
  (0xBED20560, 0x3C3C74F3), (0x89F9C9F8, 0xD2D14B61),
  (0x35FA38C6, 0xBB04A2C1), (0xCB49E3C6, 0xC5626167),
];
const _cs64Factor = 0x82893933;
const _cs64Adjustment0 = 0xF2F90B1A;
const _cs64Adjustment1 = 0x0B1A0000;

/// The token for [unixSeconds], the service's own clock: the Windows file
/// time rounded down to five minutes, in 100 ns ticks.
String edgeSecMsGec(int unixSeconds) {
  final rounded = (unixSeconds + _winEpoch) ~/ 300 * 300;
  final data = Uint8List.fromList(
    '${rounded * 10000000}$edgeTrustedClientToken'.codeUnits,
  );
  final digest = _sha256(data);
  final (low, high) = _cs64(data, digest);
  final cs64 = ByteData(8)
    ..setUint32(0, low, Endian.little)
    ..setUint32(4, high, Endian.little);
  return '${_hex(cs64.buffer.asUint8List())}-${_hex(digest)}';
}

String _hex(Uint8List bytes) => [
  for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
].join().toUpperCase();

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;
int _sigma0(int x) => _rotr(x, 7) ^ _rotr(x, 18) ^ (x >> 3);
int _sigma1(int x) => _rotr(x, 17) ^ _rotr(x, 19) ^ (x >> 10);
int _rol16(int x) => ((x << 16) | (x >> 16)) & _mask;

List<int> _rounds(List<int> state, List<int> words, int firstRound) {
  var [a, b, c, d, e, f, g, h] = state;
  for (var i = firstRound; i < 64; i++) {
    final k = firstRound == 14 && i == 14 ? _adjustment : _k[i];
    final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
    final ch = g ^ (e & (f ^ g));
    final t1 = (h + s1 + ch + k + words[i]) & _mask;
    final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
    final maj = (a & b) | (c & (a | b));
    final t2 = (s0 + maj) & _mask;
    h = g;
    g = f;
    f = e;
    e = (d + t1) & _mask;
    d = c;
    c = b;
    b = a;
    a = (t1 + t2) & _mask;
  }
  return [a, b, c, d, e, f, g, h];
}

void _expand(List<int> words, int first) {
  for (var i = first; i < 64; i++) {
    words.add(
      (_sigma1(words[i - 2]) +
              words[i - 7] +
              _sigma0(words[i - 15]) +
              words[i - 16]) &
          _mask,
    );
  }
}

int _be(Uint8List data, int start, int end) {
  var value = 0;
  for (var i = start; i < end; i++) {
    value = (value << 8) | data[i];
  }
  return value;
}

/// The state after the fixed prefix and the token's first seven bytes.
List<int> _init(Uint8List head) {
  final words = [...List.filled(14, 0), _be(head, 0, 3), _be(head, 3, 7)];
  for (var index = 16; index < 30; index++) {
    var value = _schedule[index - 16];
    if (index - 2 >= 14) {
      final s = _sigma1(words[index - 2]);
      value += index == 16 ? s ^ _sigma1Adjustment : s;
    }
    if (index - 7 >= 14) value += words[index - 7];
    if (index - 15 >= 14) {
      final s = _sigma0(words[index - 15]);
      value += index == 29 ? s ^ _sigma0Adjustment : s;
    }
    words.add(value & _mask);
  }
  words.add(
    (_sigma1(words[28]) +
            words[23] +
            _sigma0(words[15]) +
            words[14] +
            _adjustment -
            _k[14]) &
        _mask,
  );
  _expand(words, 31);
  final working = _rounds(_midstate, words, 14);
  return [for (var i = 0; i < 8; i++) (_initial[i] + working[i]) & _mask];
}

Uint8List _sha256(Uint8List data) {
  final length = 57 + data.length;
  final tail = BytesBuilder()
    ..add(data.sublist(7))
    ..addByte(0x80)
    ..add(List.filled((55 - length) % 64, 0));
  final bits = ByteData(8)..setUint64(0, length * 8);
  tail.add(bits.buffer.asUint8List());
  final padded = tail.takeBytes();
  var state = _init(data.sublist(0, 7));
  for (var offset = 0; offset < padded.length; offset += 64) {
    final words = [
      for (var i = 0; i < 16; i++)
        _be(padded, offset + i * 4, offset + i * 4 + 4),
    ];
    _expand(words, 16);
    final working = _rounds(state, words, 0);
    state = [for (var i = 0; i < 8; i++) (state[i] + working[i]) & _mask];
  }
  final out = ByteData(32);
  for (var i = 0; i < 8; i++) {
    out.setUint32(i * 4, state[i]);
  }
  return out.buffer.asUint8List();
}

(int, int) _cs64(Uint8List data, Uint8List digest) {
  final view = ByteData.sublistView(digest);
  final keyA = view.getUint32(0, Endian.little) | 1;
  final keyB = view.getUint32(4, Endian.little) | 1;
  final factors = [(keyA * _cs64Factor) & _mask, (keyB * _cs64Factor) & _mask];
  final terms = [
    for (var i = 0; i < _cs64Coefficients.length; i++)
      (_cs64Coefficients[i].$1 * factors[i % 2]) & _mask,
  ];
  final offsets = [for (final (_, offset) in _cs64Coefficients) offset];
  // Little-endian words of a zero byte and the data, an even count.
  final source = [0, ...data];
  while (source.length % 4 != 0) {
    source.add(0);
  }
  final bytes = ByteData.sublistView(Uint8List.fromList(source));
  final words = [
    for (var i = 0; i < source.length; i += 4)
      bytes.getUint32(i, Endian.little),
  ];
  if (words.length.isOdd) words.add(0);
  for (var index = 0; index < words.length; index++) {
    final word = words[index];
    var term = word * (index.isEven ? keyA : keyB);
    var offset = _rol16(word) * (index.isEven ? 0xEF0569FB : 0xC31713DB);
    if (index == 0) {
      term += _cs64Adjustment0 * factors[0];
      offset += _cs64Adjustment1;
    }
    terms.add(term & _mask);
    offsets.add(offset & _mask);
  }
  var swapAcc = 0;
  var swapLast = 0;
  var state = 0;
  var acc = 0;
  for (var index = 0; index < terms.length; index += 2) {
    final x = terms[index];
    final y = terms[index + 1];
    var t = _rol16((offsets[index] + x) & _mask);
    var q = (t * 0x76F50F34) & _mask;
    swapAcc += (_rol16(q) * 0xC3EFEA97 + q) & _mask;
    t = _rol16((offsets[index + 1] + y) & _mask);
    q = (t * 0x1881CE3C) & _mask;
    swapLast = (_rol16(q) * 0x35BD1EC9 + q) & _mask;
    swapAcc = (swapAcc + swapLast) & _mask;
    state = (state * keyA + x) & _mask;
    state = (_rol16(state) * 0xCF98B111) & _mask;
    state = (_rol16(state) * 0x87085B9F) & _mask;
    state = (_rol16(state) * 0x12CEB96D) & _mask;
    state = (_rol16(state) * 0x257E1D83) & _mask;
    acc += state;
    t = (state * keyB + y) & _mask;
    t = (_rol16(t) * 0xA27416F5) & _mask;
    t = (_rol16(t) * 0xD38396FF) & _mask;
    state = (_rol16((_rol16(t) * 0x7C932B89) & _mask) * 0xBFA49F69) & _mask;
    acc = (acc + state) & _mask;
  }
  return (swapLast ^ state, swapAcc ^ acc);
}
