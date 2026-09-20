// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

@Tags(['golden'])
library;

import 'dart:io';

import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import 'pump_review.dart';

/// The one golden of the review screen: the whole screen on a blunder, with
/// the coach comment, arrows, glyph, graph and controls. macOS only
/// (`tool/golden.sh`).
///
/// The test font would draw every letter as a box, and nobody can judge a
/// screen of boxes. The repository bundles no font, so the test takes Roboto
/// and the Material icons from the Flutter SDK that runs it
/// (`bin/cache/artifacts/material_fonts`, Apache-2.0, pinned by the Flutter
/// version in `pubspec.yaml`). Nothing is copied into the repository. Without
/// that directory the test is skipped rather than compared against boxes.
void main() {
  final fonts = Directory(
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
  );

  Future<void> loadFont(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = await File('${fonts.path}/$file').readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  testWidgets(
    'coach comment on a blunder, iPhone 17 Pro, English, light',
    skip: !fonts.existsSync(),
    (tester) async {
      await tester.runAsync(() async {
        await loadFont('Roboto', [
          'Roboto-Regular.ttf',
          'Roboto-Medium.ttf',
          'Roboto-Bold.ttf',
        ]);
        await loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
        // Piece images are decoded by the engine, which needs real async.
        await precacheBoardTheme(const BoardTheme(), devicePixelRatio: 3);
      });

      // The environment ribbon has a font of its own; `prod` has no ribbon.
      await pumpReview(
        tester,
        fixture: kShortGame,
        env: testEnv(envName: 'prod'),
      );
      tester.reviewController.goTo(16);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/review_screen_blunder.png'),
      );
    },
  );
}
