// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/features/about/domain/licence_document.dart';
import 'package:flutter_test/flutter_test.dart';

/// Everything but white space (and, for block quotes, the `>` markers).
String _ink(String text, {bool dropQuoteMarkers = false}) {
  final lines = text.split('\n').map((line) {
    return dropQuoteMarkers ? line.replaceFirst(RegExp(r'^\s*> ?'), '') : line;
  });
  return lines.join().replaceAll(RegExp(r'\s'), '');
}

void main() {
  group('parseTextBlocks', () {
    test('re-flows wrapped running text and keeps the indent', () {
      final blocks = parseTextBlocks(
        '  The GNU General Public License is a free, copyleft license for\n'
        'software and other kinds of works.\n',
      );

      expect(blocks, const [
        TextBlock(
          TextBlockKind.prose,
          'The GNU General Public License is a free, copyleft license for '
          'software and other kinds of works.',
          indent: 2,
        ),
      ]);
    });

    test('blank lines separate blocks, however many', () {
      final blocks = parseTextBlocks('one\n\n\n\ntwo\r\n\r\nthree');

      expect(blocks.map((b) => b.text), ['one', 'two', 'three']);
    });

    test('a deeply indented block is a centred title with its lines', () {
      final blocks = parseTextBlocks(
        '                    GNU GENERAL PUBLIC LICENSE\n'
        '                       Version 3, 29 June 2007\n',
      );

      expect(blocks, const [
        TextBlock(
          TextBlockKind.centered,
          'GNU GENERAL PUBLIC LICENSE\nVersion 3, 29 June 2007',
        ),
      ]);
    });

    test('a short line keeps its break: underlined headings', () {
      final blocks = parseTextBlocks('Piece artwork\n-------------\n');

      expect(blocks.single.kind, TextBlockKind.prose);
      expect(blocks.single.text, 'Piece artwork\n-------------');
    });

    test('list items start a new line, their continuation is joined', () {
      final blocks = parseTextBlocks(
        '- Only files written for this app. They are recognisable by the header\n'
        '  `SPDX-License-Identifier: GPL-3.0-or-later` together with a reference\n'
        '  to this file.\n'
        '- Conveying the app in object form through an app store whose terms would\n'
        '  otherwise conflict with the GPL.\n',
      );

      expect(blocks.single.text.split('\n'), [
        '- Only files written for this app. They are recognisable by the '
            'header `SPDX-License-Identifier: GPL-3.0-or-later` together with '
            'a reference to this file.',
        '- Conveying the app in object form through an app store whose terms '
            'would otherwise conflict with the GPL.',
      ]);
    });

    test('a wrapped line that starts with a number is not a list item', () {
      final blocks = parseTextBlocks(
        '    b) The work must carry prominent notices stating that it is\n'
        '    released under this License and any conditions added under section\n'
        '    7.  This requirement modifies the requirement in section 4.\n',
      );

      expect(blocks.single.text, isNot(contains('\n')));
      expect(blocks.single.indent, 4);
    });

    test('a table keeps its shape', () {
      const table =
          '  Set      | Author              | Licence\n'
          '  ---------+---------------------+--------\n'
          '  cburnett | Colin M. L. Burnett | GPLv2+';
      final blocks = parseTextBlocks('$table\n');

      expect(blocks, const [TextBlock(TextBlockKind.preformatted, table)]);
    });

    test('a Markdown block quote loses its markers, not its words', () {
      final blocks = parseTextBlocks(
        '> **DRAFT. This is a placeholder, not a grant.** The final wording is a\n'
        '> decision of the copyright holder.\n',
      );

      expect(blocks, const [
        TextBlock(
          TextBlockKind.quote,
          '**DRAFT. This is a placeholder, not a grant.** The final wording '
          'is a decision of the copyright holder.',
        ),
      ]);
    });

    test('form feeds of the printed GPL are dropped', () {
      expect(parseTextBlocks('one\n\f\ntwo').map((b) => b.text), [
        'one',
        'two',
      ]);
    });
  });

  group('the real files', () {
    // Tests run from the repository root.
    for (final document in LicenceDocument.values) {
      test('${document.assetKey}: every character survives, in order', () {
        final source = File(document.assetKey).readAsStringSync();
        final blocks = parseTextBlocks(source);

        expect(blocks, isNotEmpty);
        expect(
          _ink(blocks.map((b) => b.text).join('\n')),
          _ink(source, dropQuoteMarkers: true),
        );
      });
    }

    test('the GPL starts with its title and has its seventeen sections', () {
      final blocks = parseTextBlocks(File('LICENSE').readAsStringSync());

      expect(blocks.first.kind, TextBlockKind.centered);
      expect(blocks.first.text, startsWith('GNU GENERAL PUBLIC LICENSE'));
      expect(blocks.where((b) => b.text == '0. Definitions.'), hasLength(1));
      expect(
        blocks.where((b) => b.text.startsWith('17. Interpretation of')),
        hasLength(1),
      );
      expect(
        blocks.where((b) => b.kind == TextBlockKind.preformatted),
        isEmpty,
      );
    });

    test('NOTICE keeps the piece-set table as a table', () {
      final blocks = parseTextBlocks(File('NOTICE').readAsStringSync());
      final table = blocks.singleWhere(
        (b) => b.kind == TextBlockKind.preformatted && b.text.contains('Set '),
      );

      for (final set in ['cburnett', 'merida', 'rhosgfx']) {
        expect(table.text, contains(set));
      }
      expect(table.text.split('\n').length, greaterThanOrEqualTo(5));
    });

    test('the permission file says DRAFT in a quote at the top', () {
      final blocks = parseTextBlocks(
        File('LICENSE-APP-STORE-PERMISSION.md').readAsStringSync(),
      );

      expect(blocks[1].kind, TextBlockKind.quote);
      expect(blocks[1].text, contains('DRAFT'));
    });
  });
}
