// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// SHA-256 (FIPS 180-4) for the fixture drift test, so that the test needs
/// neither a new dependency nor a `shasum` binary on the CI machine.
/// `vendored_fixtures_test.dart` checks it against the standard test vectors.
library;

import 'dart:math' as math;

const int _mask = 0xffffffff;

/// The first [count] primes.
List<int> _primes(int count) {
  final primes = <int>[];
  for (var n = 2; primes.length < count; n++) {
    if (primes.every((p) => n % p != 0)) primes.add(n);
  }
  return primes;
}

/// The first 32 bits of the fractional part of [x].
int _fractionBits(double x) => ((x - x.floorToDouble()) * 4294967296.0).floor();

/// Round constants: fractional parts of the cube roots of the first 64 primes.
final List<int> _k = [
  for (final p in _primes(64)) _fractionBits(math.pow(p, 1 / 3).toDouble()),
];

/// Initial hash value: fractional parts of the square roots of the first 8
/// primes.
final List<int> _h0 = [for (final p in _primes(8)) _fractionBits(math.sqrt(p))];

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;

/// The SHA-256 digest of [bytes] as lower-case hex.
String sha256Hex(List<int> bytes) {
  final message = <int>[...bytes, 0x80];
  while (message.length % 64 != 56) {
    message.add(0);
  }
  final bitLength = bytes.length * 8;
  for (var shift = 56; shift >= 0; shift -= 8) {
    message.add((bitLength >> shift) & 0xff);
  }

  final h = List<int>.of(_h0);
  final w = List<int>.filled(64, 0);
  for (var offset = 0; offset < message.length; offset += 64) {
    for (var t = 0; t < 16; t++) {
      final i = offset + 4 * t;
      w[t] =
          (message[i] << 24) |
          (message[i + 1] << 16) |
          (message[i + 2] << 8) |
          message[i + 3];
    }
    for (var t = 16; t < 64; t++) {
      final s0 = _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
      final s1 = _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & _mask;
    }

    var [a, b, c, d, e, f, g, hh] = h;
    for (var t = 0; t < 64; t++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ (~e & _mask & g);
      final t1 = (hh + s1 + ch + _k[t] + w[t]) & _mask;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & _mask;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & _mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _mask;
    }
    final next = [a, b, c, d, e, f, g, hh];
    for (var i = 0; i < 8; i++) {
      h[i] = (h[i] + next[i]) & _mask;
    }
  }
  return [for (final word in h) word.toRadixString(16).padLeft(8, '0')].join();
}
