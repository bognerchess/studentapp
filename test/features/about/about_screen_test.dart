// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/links/link_launcher.dart';
import 'package:bogner_chess/features/about/domain/additional_licenses.dart';
import 'package:bogner_chess/features/about/ui/about_screen.dart';
import 'package:bogner_chess/features/about/ui/licence_text_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

/// Records what the screen asked to open, instead of opening it.
class _FakeLauncher {
  _FakeLauncher({this.result = true, this.error});

  final bool result;
  final Exception? error;
  final List<Uri> opened = [];

  Future<bool> call(Uri uri) async {
    opened.add(uri);
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

/// Pumps the whole app, as `pumpApp` does, and opens the about screen. The
/// difference is the link launcher, which `pumpApp` cannot override.
Future<void> _pumpAbout(
  WidgetTester tester, {
  LinkLauncher? launcher,
  AppInfo? appInfo = const AppInfo(version: '1.2.3', buildNumber: '45'),
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size screen = kIphone17Pro,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = screen * 3;
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  // No fake asset bundle: `flutter test` serves the assets that pubspec.yaml
  // declares, so a legal text missing from `assets:` fails these tests.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        envProvider.overrideWithValue(testEnv()),
        appInfoProvider.overrideWith((ref) async {
          if (appInfo == null) {
            throw StateError('no platform');
          }
          return appInfo;
        }),
        ...backendOverrides(),
        linkLauncherProvider.overrideWithValue(
          launcher ?? _FakeLauncher().call,
        ),
      ],
      child: const BognerChessApp(),
    ),
  );
  await tester.pumpAndSettle();
  routerOf(tester).go(AppRoutes.settingsAbout);
  await tester.pumpAndSettle();
}

Finder get _aboutList => find.descendant(
  of: find.byKey(AboutScreen.listKey),
  matching: find.byType(Scrollable),
);

/// The list builds its rows lazily, so a row further down has to be scrolled
/// to before it exists.
Future<void> _tapRow(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(find.byKey(key), 100, scrollable: _aboutList);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// The vertical list of a licence text. `.first`, because a table inside it
/// is a (horizontal) scrollable of its own.
Finder get _licenceList => find
    .descendant(
      of: find.byKey(LicenceTextScreen.listKey),
      matching: find.byType(Scrollable),
    )
    .first;

/// `tester.pageBack()` only knows the English tooltip.
Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

void main() {
  group('about screen', () {
    testWidgets('shows name, version and build, and the five rows', (
      tester,
    ) async {
      await _pumpAbout(tester);

      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.text('Bogner Chess'), findsOneWidget);
      expect(find.text('Version 1.2.3 (45)'), findsOneWidget);
      expect(find.textContaining('learn from your own games'), findsOneWidget);
      // The list builds lazily; with the wide test font the lower rows start
      // below the fold.
      for (final row in [
        'Source code for this build',
        'GNU General Public License v3',
        'Additional permission for app stores',
        'Draft, not in force yet',
        'Third-party notices',
        'Open-source licences',
      ]) {
        await tester.scrollUntilVisible(
          find.text(row),
          100,
          scrollable: _aboutList,
        );
        expect(find.text(row), findsOneWidget);
      }
      // The tab bar stays: this is a page inside the settings tab.
      expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);
    });

    testWidgets('says that it is not affiliated with Lichess', (tester) async {
      await _pumpAbout(tester);

      expect(
        find.textContaining('not affiliated with or endorsed by Lichess'),
        findsOneWidget,
      );
    });

    testWidgets('shows the legal notice the GPL asks for', (tester) async {
      await _pumpAbout(tester);

      await tester.scrollUntilVisible(
        find.textContaining('Copyright © 2026 Bogner Chess'),
        200,
        scrollable: _aboutList,
      );
      expect(find.textContaining('no warranty'), findsOneWidget);
      expect(find.textContaining('version 3 or any later'), findsOneWidget);
    });

    testWidgets('the source row shows and opens the tag of this build', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      await _pumpAbout(tester, launcher: launcher.call);

      const url = 'https://github.com/bognerchess/studentapp/tree/v1.2.3+45';
      expect(find.text(url), findsOneWidget);

      await _tapRow(tester, AboutScreen.sourceLinkKey);

      expect(launcher.opened, [Uri.parse(url)]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a link that cannot be opened says so', (tester) async {
      final launcher = _FakeLauncher(result: false);
      await _pumpAbout(tester, launcher: launcher.call);

      await _tapRow(tester, AboutScreen.sourceLinkKey);

      expect(launcher.opened, hasLength(1));
      expect(find.text('The link could not be opened.'), findsOneWidget);
    });

    testWidgets('a launcher that throws is handled the same way', (
      tester,
    ) async {
      final launcher = _FakeLauncher(
        error: PlatformException(code: 'channel-error'),
      );
      await _pumpAbout(tester, launcher: launcher.call);

      await _tapRow(tester, AboutScreen.sourceLinkKey);

      expect(find.text('The link could not be opened.'), findsOneWidget);
    });

    testWidgets('without app info: no version, link to the repository', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      await _pumpAbout(tester, launcher: launcher.call, appInfo: null);

      expect(find.textContaining('Version'), findsNothing);
      await _tapRow(tester, AboutScreen.sourceLinkKey);
      expect(launcher.opened, [
        Uri.parse('https://github.com/bognerchess/studentapp'),
      ]);
    });
  });

  group('licence texts', () {
    testWidgets('the GPL opens in full, scrolls, and can be selected', (
      tester,
    ) async {
      await _pumpAbout(tester);
      await _tapRow(tester, AboutScreen.gplKey);

      expect(find.byType(LicenceTextScreen), findsOneWidget);
      expect(find.textContaining('GNU GENERAL PUBLIC LICENSE'), findsOneWidget);
      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byKey(LicenceTextScreen.warningKey), findsNothing);

      // It scrolls: the title leaves, and the last section can be reached.
      await tester.scrollUntilVisible(
        find.textContaining('END OF TERMS AND CONDITIONS'),
        600,
        scrollable: _licenceList,
        maxScrolls: 400,
      );
      expect(find.textContaining('GNU GENERAL PUBLIC LICENSE'), findsNothing);
      expect(
        tester.state<ScrollableState>(_licenceList).position.pixels,
        greaterThan(1000),
      );

      // Monospace, as the task asks.
      final text = tester.widget<Text>(
        find.textContaining('END OF TERMS AND CONDITIONS'),
      );
      expect(text.style?.fontFamily, 'Menlo');

      // Back leads to the about screen, still inside the settings tab.
      await _back(tester);
      expect(find.byType(AboutScreen), findsOneWidget);
      expect(locationOf(tester), AppRoutes.settingsAbout);
    });

    testWidgets('the additional permission is marked as a draft', (
      tester,
    ) async {
      await _pumpAbout(tester);
      await _tapRow(tester, AboutScreen.appStorePermissionKey);

      expect(find.byKey(LicenceTextScreen.warningKey), findsOneWidget);
      expect(find.textContaining('This text is a draft'), findsOneWidget);
      // The file's own words, too.
      expect(
        find.textContaining('DRAFT. This is a placeholder, not a grant.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.textContaining('As an additional permission under section 7'),
        300,
        scrollable: _licenceList,
      );
    });

    testWidgets('NOTICE shows the three piece sets and their licences', (
      tester,
    ) async {
      await _pumpAbout(tester);
      await _tapRow(tester, AboutScreen.noticeKey);

      final table = find.textContaining('Colin M. L. Burnett');
      await tester.scrollUntilVisible(table, 300, scrollable: _licenceList);

      final text = tester.widget<Text>(table).data!;
      for (final expected in [
        'cburnett',
        'merida',
        'rhosgfx',
        'Armando Hernandez Marroquin',
        'GPLv2+',
        'CC0 1.0',
      ]) {
        expect(text, contains(expected));
      }
      // A table does not wrap; it scrolls sideways instead.
      expect(tester.widget<Text>(table).softWrap, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the active tab pops the text and the about screen', (
      tester,
    ) async {
      await _pumpAbout(tester);
      await _tapRow(tester, AboutScreen.gplKey);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(LicenceTextScreen), findsNothing);
      expect(locationOf(tester), AppRoutes.settings);
    });
  });

  group('open-source licences', () {
    setUp(() {
      // Only our entries: the packages' NOTICES file is real I/O, which a
      // widget test cannot wait for.
      LicenseRegistry.reset();
      LicenseRegistry.addLicense(additionalLicenseEntries);
    });
    tearDown(LicenseRegistry.reset);

    testWidgets('lists the piece sets and the vendored chessground', (
      tester,
    ) async {
      await _pumpAbout(tester);
      await _tapRow(tester, AboutScreen.openSourceLicencesKey);

      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('Version 1.2.3 (45)'), findsOneWidget);
      expect(find.text('chessground'), findsOneWidget);
      expect(find.text('Chess pieces: cburnett'), findsOneWidget);
      expect(find.text('Chess pieces: merida'), findsOneWidget);
      expect(find.text('Chess pieces: rhosgfx'), findsOneWidget);

      await tester.tap(find.text('Chess pieces: rhosgfx'));
      await tester.pumpAndSettle();
      expect(find.textContaining('CC0 1.0 Universal'), findsOneWidget);
    });

    testWidgets('is in the app theme and in German', (tester) async {
      await _pumpAbout(
        tester,
        locale: const Locale('de'),
        brightness: Brightness.dark,
      );
      await _tapRow(tester, AboutScreen.openSourceLicencesKey);

      expect(find.text('Lizenzen'), findsOneWidget);
      final theme = Theme.of(tester.element(find.byType(LicensePage)));
      expect(theme.brightness, Brightness.dark);
    });
  });

  group('German, large type, dark', () {
    testWidgets('the about screen is German', (tester) async {
      await _pumpAbout(tester, locale: const Locale('de', 'CH'));

      expect(find.text('Über die App und Lizenzen'), findsOneWidget);
      expect(
        find.textContaining('in keiner Verbindung zu Lichess'),
        findsOneWidget,
      );
      expect(find.textContaining('not affiliated'), findsNothing);
      for (final row in [
        'Quellcode dieses Builds',
        'Vollständiger Lizenztext, auf Englisch',
        'Zusätzliche Erlaubnis für App-Stores',
        'Entwurf, noch nicht in Kraft',
        'Hinweise zu Drittkomponenten',
        'Open-Source-Lizenzen',
      ]) {
        await tester.scrollUntilVisible(
          find.text(row),
          100,
          scrollable: _aboutList,
        );
        expect(find.text(row), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.textContaining('keinerlei Gewährleistung'),
        100,
        scrollable: _aboutList,
      );
      expect(find.text('Source code for this build'), findsNothing);
    });

    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final brightness in Brightness.values) {
        testWidgets('text scale 1.3 on 375 x 667 does not overflow '
            '($locale, ${brightness.name})', (tester) async {
          await _pumpAbout(
            tester,
            locale: locale,
            brightness: brightness,
            textScale: 1.3,
            screen: kIphoneSe,
          );
          expect(tester.takeException(), isNull);
          expect(
            Theme.of(tester.element(find.byType(AboutScreen))).brightness,
            brightness,
          );

          // Every row is reachable, and every text screen lays out.
          for (final key in [
            AboutScreen.gplKey,
            AboutScreen.appStorePermissionKey,
            AboutScreen.noticeKey,
          ]) {
            await _tapRow(tester, key);
            expect(find.byType(LicenceTextScreen), findsOneWidget);
            await tester.drag(_licenceList, const Offset(0, -2000));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await _back(tester);
          }
          await tester.scrollUntilVisible(
            find.byKey(AboutScreen.openSourceLicencesKey),
            200,
            scrollable: _aboutList,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
