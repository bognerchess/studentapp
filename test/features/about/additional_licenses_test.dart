// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/features/about/domain/additional_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

String _textOf(LicenseEntry entry) =>
    entry.paragraphs.map((p) => p.text).join('\n');

/// Piece-set names from tool/asset_allowlist.txt: what the built app may
/// contain, and what tool/check_bundled_assets.sh enforces.
List<String> _allowedPieceSets() {
  return File('tool/asset_allowlist.txt')
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();
}

void main() {
  // No binding here on purpose: without one the registry holds only what
  // this test registers, not the NOTICES file of the packages.
  test('registerAdditionalLicenses adds our entries, once', () async {
    registerAdditionalLicenses();
    registerAdditionalLicenses();

    final entries = await LicenseRegistry.licenses.toList();
    final packages = [for (final e in entries) ...e.packages];

    expect(packages, [
      'chessground',
      'Chess pieces: cburnett',
      'Chess pieces: merida',
      'Chess pieces: rhosgfx',
    ]);
  });

  test('each piece set names author, licence and source', () async {
    final entries = await additionalLicenseEntries().toList();
    String entryFor(String package) =>
        _textOf(entries.singleWhere((e) => e.packages.contains(package)));

    final cburnett = entryFor('Chess pieces: cburnett');
    expect(cburnett, contains('Colin M. L. Burnett'));
    expect(cburnett, contains('GPLv2+'));
    expect(cburnett, contains('lila/tree/master/public/piece/cburnett'));

    final merida = entryFor('Chess pieces: merida');
    expect(merida, contains('Armando Hernandez Marroquin'));
    expect(merida, contains('GPLv2+'));
    expect(merida, contains('lila/tree/master/public/piece/merida'));

    final rhosgfx = entryFor('Chess pieces: rhosgfx');
    expect(rhosgfx, contains('RhosGFX'));
    expect(rhosgfx, contains('CC0 1.0'));
    expect(rhosgfx, contains('lila/tree/master/public/piece/rhosgfx'));
  });

  test('the vendored chessground says GPL-3.0, modified, and which commit', () {
    final chessground = additionalLicenses.singleWhere(
      (l) => l.package == 'chessground',
    );

    expect(chessground.text, contains('GPL-3.0'));
    expect(chessground.text, contains('modified copy'));
    expect(chessground.text, contains('not affiliated with'));
  });

  group('in step with the allow-lists', () {
    test('every piece set the bundle may contain has an entry, and only '
        'those', () {
      final registered = [
        for (final l in additionalLicenses)
          if (l.package.startsWith('Chess pieces: '))
            l.package.substring('Chess pieces: '.length),
      ];

      expect(registered, unorderedEquals(_allowedPieceSets()));
    });

    test('authors, sources, version and commit are the ones in NOTICE', () {
      final notice = File('NOTICE').readAsStringSync();
      final facts = RegExp(
        r'Colin M\. L\. Burnett|Armando Hernandez Marroquin|RhosGFX|'
        r'github\.com/[\w./-]+[\w/-]|en\.wikipedia\.org/[\w./:-]+\w|'
        r'rhosgfx\.itch\.io|\b[0-9a-f]{40}\b|\b\d+\.\d+\.\d+\b',
      );

      var checked = 0;
      for (final license in additionalLicenses) {
        for (final match in facts.allMatches(license.text)) {
          expect(
            notice,
            contains(match[0]),
            reason: '"${match[0]}" (${license.package}) is not in NOTICE',
          );
          checked++;
        }
      }
      // 3 authors, 3 + 2 piece-set sources, chessground repo, version, sha.
      expect(checked, greaterThanOrEqualTo(11));
    });
  });
}
