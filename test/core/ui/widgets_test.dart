// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/core/ui/widgets/empty_state.dart';
import 'package:bogner_chess/core/ui/widgets/error_retry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The smallest host a shared widget needs: theme and localisations.
Widget host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    theme: AppTheme.light(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: child,
  );
}

void main() {
  testWidgets('EmptyState shows its text and runs its action', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      host(
        AppScaffold(
          title: 'Title',
          body: EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing here',
            message: 'Add something.',
            actionLabel: 'Add',
            onAction: () => tapped++,
          ),
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Add something.'), findsOneWidget);
    await tester.tap(find.text('Add'));
    expect(tapped, 1);
  });

  testWidgets('EmptyState without an action shows no button', (tester) async {
    await tester.pumpWidget(
      host(const EmptyState(icon: Icons.inbox_outlined, title: 'Nothing')),
    );

    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('ErrorRetry defaults to the generic text and retries', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      host(Scaffold(body: ErrorRetry(onRetry: () => retried++))),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });

  testWidgets('ErrorRetry is German in German, and takes custom text', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Scaffold(body: ErrorRetry(message: 'Eigene Meldung')),
        locale: const Locale('de'),
      ),
    );

    expect(find.text('Etwas ist schiefgelaufen'), findsOneWidget);
    expect(find.text('Eigene Meldung'), findsOneWidget);
    // No callback, no button.
    expect(find.text('Erneut versuchen'), findsNothing);
  });

  test('light and dark themes are Material 3 with the app colours', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.useMaterial3, isTrue);
      expect(theme.extension<AppColors>(), isNotNull);
    }
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(
      AppColors.light.lerp(AppColors.dark, 1).success,
      AppColors.dark.success,
    );
  });
}
