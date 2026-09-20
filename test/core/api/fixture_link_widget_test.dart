// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixture_link.dart';

// In a file of its own: a file with testWidgets has the test binding, and the
// test binding answers every real HTTP request with 400. The tests next door
// talk to the mock server over real HTTP.
void main() {
  testWidgets('a widget reads a repository through a FixtureLink', (
    tester,
  ) async {
    final link = FixtureLink({'MyMobileGames': 'first_page'});
    await tester.pumpWidget(
      ProviderScope(
        overrides: link.overrides,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer(
            builder: (context, ref, _) {
              final page = ref.watch(_pageProvider);
              return Text(switch (page) {
                AsyncData(:final value) =>
                  '${value.games.length} of ${value.totalCount}',
                AsyncError(:final error) => 'error $error',
                _ => 'loading',
              });
            },
          ),
        ),
      ),
    );
    expect(find.text('loading'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
  });
}

final _pageProvider = FutureProvider<GamesPage>(
  (ref) => ref.watch(gamesApiProvider).list(),
);
