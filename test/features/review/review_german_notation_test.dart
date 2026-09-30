// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'pump_review.dart';

/// Puts English SAN in the ply-10 comment of the short game, the way the
/// backend sends it: the wire is English whatever the reader's language is.
void _englishSan(Map<String, dynamic> json) {
  final comment = (json['comments'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((comment) => comment['ply'] == 10);
  comment['title'] = 'Nf3 war besser';
  comment['text'] =
      'Nach Nf3 steht die Dame gut, und der Bauer auf f7 bleibt schwach. '
      'Der Springer gehört nicht an den Rand.';
  comment['moves_mentioned'] = ['Nf3'];
}

void main() {
  group('German notation', () {
    testWidgets('a German comment shows the German piece letters', (
      tester,
    ) async {
      await pumpReview(
        tester,
        fixture: kShortGame,
        patch: _englishSan,
        locale: const Locale('de'),
      );
      tester.reviewController.goTo(10);
      await tester.pumpAndSettle();

      // Title and text: Nf3 -> Sf3.
      expect(find.text('Sf3 war besser'), findsOneWidget);
      expect(
        find.textContaining('Nach Sf3 steht die Dame gut', findRichText: true),
        findsOneWidget,
      );
      // The German words and the square keep their letters.
      expect(
        find.textContaining(
          'der Bauer auf f7 bleibt schwach',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Der Springer gehört', findRichText: true),
        findsOneWidget,
      );
      // The line the comment offers: Nxe4 -> Sxe4.
      expect(find.textContaining('Sxe4', findRichText: true), findsWidgets);
      // Nothing on screen is still English notation.
      expect(find.textContaining('Nf3', findRichText: true), findsNothing);
      expect(find.textContaining('Nxe4', findRichText: true), findsNothing);
    });

    testWidgets('the English reader sees the wire notation unchanged', (
      tester,
    ) async {
      await pumpReview(tester, fixture: kShortGame, patch: _englishSan);
      tester.reviewController.goTo(10);
      await tester.pumpAndSettle();

      expect(find.text('Nf3 war besser'), findsOneWidget);
      expect(
        find.textContaining('Nach Nf3 steht die Dame gut', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Sf3', findRichText: true), findsNothing);
    });
  });
}
