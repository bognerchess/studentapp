// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> readArb(String locale) {
  final text = File('lib/core/l10n/app_$locale.arb').readAsStringSync();
  return jsonDecode(text) as Map<String, Object?>;
}

Set<String> messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

void main() {
  test('German has exactly the strings English has', () {
    final en = messageKeys(readArb('en'));
    final de = messageKeys(readArb('de'));
    expect(de.difference(en), isEmpty, reason: 'only in app_de.arb');
    expect(en.difference(de), isEmpty, reason: 'missing in app_de.arb');
  });

  test('no string is empty', () {
    for (final locale in ['en', 'de']) {
      final arb = readArb(locale);
      for (final key in messageKeys(arb)) {
        expect(arb[key], isA<String>(), reason: '$locale: $key');
        expect(
          (arb[key]! as String).trim(),
          isNotEmpty,
          reason: '$locale: $key',
        );
      }
    }
  });

  // The app launches German as `de_CH` (WP-03) and the platform is Swiss.
  // Swiss Standard German writes "ss" where Germany writes "ß", so a single
  // "Weiß" among a dozen "Weiss" is a bug, not a variant. WP-20 and WP-21
  // disagreed about this once; this test is the decision.
  test('German is Swiss German: no ß', () {
    final de = readArb('de');
    for (final key in messageKeys(de)) {
      expect(
        de[key]! as String,
        isNot(contains('ß')),
        reason: '$key: Swiss German writes ss (Weiss, gross, heisst)',
      );
    }
  });

  test('every English string is described for translators', () {
    final en = readArb('en');
    for (final key in messageKeys(en)) {
      final meta = en['@$key'];
      expect(meta, isA<Map<String, Object?>>(), reason: key);
      expect(
        (meta! as Map<String, Object?>)['description'],
        isA<String>(),
        reason: key,
      );
    }
  });
}
