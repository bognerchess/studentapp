// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'analysis_fixtures.dart';
import 'sha256.dart';

void main() {
  group('sha256Hex', () {
    test('matches the FIPS 180-4 test vectors', () {
      expect(
        sha256Hex(const []),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        sha256Hex(ascii.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      // Two blocks.
      expect(
        sha256Hex(
          ascii.encode(
            'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
          ),
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });
  });

  group('vendored contract files', () {
    // `<sha256>  <path as in the contract repository>`; the files are vendored
    // flat, so only the base name of the path counts.
    final sums = <String, String>{
      for (final line in File('$vendoredDir/SHA256SUMS').readAsLinesSync())
        if (line.trim().isNotEmpty)
          line.trim().split(RegExp(r'\s+')).last.split('/').last: line
              .trim()
              .split(RegExp(r'\s+'))
              .first,
    };

    // What this app vendors. `SHA256SUMS` pins more than that: the contract
    // repository also publishes its job API there (`job-api.v1.json`), which
    // is between that service and the backend and has no business here.
    final vendored = {'game-analysis.v1.schema.json', ...officialFixtures};

    test('SHA256SUMS pins the schema and the three fixtures', () {
      expect(sums.keys, containsAll(vendored));
    });

    test('every vendored file has the pinned sha256 (drift detection)', () {
      for (final name in vendored) {
        final expected = sums[name];
        final actual = sha256Hex(File('$vendoredDir/$name').readAsBytesSync());
        expect(
          actual,
          expected,
          reason:
              '$vendoredDir/$name differs from SHA256SUMS. Vendored files are '
              'never edited here; re-vendor them as described in '
              'test/fixtures/analysis/README.md.',
        );
      }
    });

    test('the directory holds nothing but the vendored files', () {
      final names = {
        for (final entity in Directory(vendoredDir).listSync())
          entity.uri.pathSegments.last,
      };
      expect(names, {...vendored, 'SHA256SUMS'});
    });
  });
}
