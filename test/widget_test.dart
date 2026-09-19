// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the placeholder home screen shows the app name', (tester) async {
    await tester.pumpWidget(const BognerChessApp());

    expect(find.text('Bogner Chess'), findsOneWidget);
  });
}
