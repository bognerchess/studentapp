// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/core/ui/widgets/draft_badge.dart';
import 'package:bogner_chess/features/legal/domain/legal_documents.dart';
import 'package:bogner_chess/features/legal/ui/legal_document_screen.dart';
import 'package:bogner_chess/features/legal/ui/legal_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/account_harness.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_screen.dart';

Map<String, dynamic> _document(String markdown, {bool isDraft = false}) => {
  'data': {
    'legalDocument': {
      'id': 'legal-terms-en-3',
      'key': 'TERMS',
      'version': 3,
      'language': 'en',
      'title': 'Terms of use',
      'bodyMarkdown': markdown,
      'providerName': null,
      'publishedAt': '2026-09-01T12:00:00.000Z',
      'isDraft': isDraft,
    },
  },
};

void main() {
  testWidgets('the list leads to both texts', (tester) async {
    final h = AccountHarness();
    await pumpScreen(tester, const LegalScreen(), overrides: h.overrides);

    await tester.tap(find.text('Terms of use'));
    await tester.pumpAndSettle();
    expect(navigatedTo(tester), AppRoutes.legalDocument('terms'));
  });

  testWidgets('renders the Markdown with version, date and the draft badge', (
    tester,
  ) async {
    final h = AccountHarness();
    h.api.respond(
      'LegalDocument',
      (_) => _document(
        '# Heading one\n\nA paragraph with **bold** text.\n\n'
        '- first item\n- second item\n\n## Second heading\n\nMore.',
        isDraft: true,
      ),
    );
    await pumpScreen(
      tester,
      const LegalDocumentScreen(page: LegalPage.terms),
      overrides: h.overrides,
    );

    expect(h.api.requestsOf('LegalDocument').single.variables, {
      'key': 'TERMS',
      'language': 'en',
    });
    // The text has a heading of its own, so the title is not printed twice.
    expect(find.text('Terms of use'), findsOneWidget); // the app bar
    expect(find.text('Version 3 · September 1, 2026'), findsOneWidget);
    expect(find.byType(DraftBadge), findsOneWidget);
    expect(find.text('Heading one', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('A paragraph with bold text.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('first item', findRichText: true), findsOneWidget);
    // No Markdown syntax left over.
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.textContaining('# ', findRichText: true), findsNothing);
  });

  testWidgets('a reviewed text has no badge', (tester) async {
    final h = AccountHarness();
    h.api.respond('LegalDocument', (_) => _document('Text.'));
    await pumpScreen(
      tester,
      const LegalDocumentScreen(page: LegalPage.terms),
      overrides: h.overrides,
    );
    expect(find.byType(DraftBadge), findsNothing);
    // No heading in the text: the title stands above it.
    expect(find.text('Terms of use'), findsNWidgets(2));
  });

  testWidgets('links open outside, and only https and mailto', (tester) async {
    final h = AccountHarness();
    h.api.respond(
      'LegalDocument',
      (_) => _document(
        '[website](https://bognerchess.com/privacy)\n\n'
        '[script](javascript:alert(1))\n\n[plain](http://example.test)',
      ),
    );
    await pumpScreen(
      tester,
      const LegalDocumentScreen(page: LegalPage.terms),
      overrides: h.overrides,
    );

    void tapLink(String text) {
      final richText = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == text,
        ),
      );
      TapGestureRecognizer? recognizer;
      richText.text.visitChildren((span) {
        if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
          recognizer = span.recognizer! as TapGestureRecognizer;
          return false;
        }
        return true;
      });
      recognizer?.onTap?.call();
    }

    tapLink('website');
    tapLink('script');
    tapLink('plain');
    await tester.pump();
    expect(h.launched, [Uri.parse('https://bognerchess.com/privacy')]);
  });

  testWidgets('German: the German text', (tester) async {
    final h = AccountHarness()..serveLegalDocumentsByLanguage();
    await pumpScreen(
      tester,
      const LegalDocumentScreen(page: LegalPage.privacy),
      locale: const Locale('de', 'CH'),
      overrides: h.overrides,
    );

    expect(
      h.api.requestsOf('LegalDocument').single.variables['language'],
      'de',
    );
    expect(find.text('Datenschutzerklärung'), findsWidgets);
    expect(find.textContaining('nur auf Englisch'), findsNothing);
    expect(find.textContaining('1. September 2026'), findsOneWidget);
  });

  testWidgets('German: an English-only text says so', (tester) async {
    final h = AccountHarness();
    h.api.respond('LegalDocument', (_) => _document('English only.'));
    await pumpScreen(
      tester,
      const LegalDocumentScreen(page: LegalPage.terms),
      locale: const Locale('de', 'CH'),
      overrides: h.overrides,
    );
    expect(find.textContaining('nur auf Englisch'), findsOneWidget);
  });

  testWidgets('nothing published', (tester) async {
    final h = AccountHarness(scenarios: {'LegalDocument': 'not_found'});
    await pumpScreen(
      tester,
      const LegalDocumentScreen(page: LegalPage.privacy),
      overrides: h.overrides,
    );
    expect(find.text('Not available yet'), findsOneWidget);
  });

  testWidgets('offline: explanation and retry', (tester) async {
    final h = AccountHarness();
    h.api.fail('LegalDocument', const SocketException('offline'));
    await pumpScreen(
      tester,
      const LegalDocumentScreen(page: LegalPage.privacy),
      overrides: h.overrides,
    );
    expect(find.text('You are offline'), findsOneWidget);

    h.api.use('LegalDocument', 'privacy_policy_en');
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('You are offline'), findsNothing);
    expect(find.textContaining('Version 1'), findsOneWidget);
  });

  testWidgets('text scale 1.3 on an iPhone SE, dark', (tester) async {
    final h = AccountHarness();
    h.api.respond(
      'LegalDocument',
      (_) => _document(
        '# A rather long heading that has to wrap on a small screen\n\n'
        '${'Lorem ipsum dolor sit amet. ' * 40}\n\n'
        '| Column | Another column |\n| --- | --- |\n| a | b |\n\n'
        '> A quote.\n\n`code` and\n\n```\na code block\n```',
        isDraft: true,
      ),
    );
    await pumpScreen(
      tester,
      const LegalDocumentScreen(page: LegalPage.terms),
      brightness: Brightness.dark,
      textScale: 1.3,
      screenSize: kIphoneSe,
      overrides: h.overrides,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(LegalDocumentScreen.scrollKey),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
