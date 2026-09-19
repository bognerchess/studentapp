// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// A stand-alone harness for looking at the import screen on a device with a
/// PGN already in the field. It is not part of the app: nothing imports it,
/// and it has its own `main`.
///
///     flutter build ios --simulator --debug \
///       --dart-define-from-file=config/fake.json \
///       --dart-define=IMPORT_DEMO=single \
///       -t lib/features/import/dev/import_demo.dart
///
/// `IMPORT_DEMO` is `single` (an annotated game: preview with warnings),
/// `multi` (three games, one of them broken: the chooser) or `error`.
library;

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/import/domain/import_result.dart';
import 'package:bogner_chess/features/import/ui/import_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const String _demo = String.fromEnvironment(
  'IMPORT_DEMO',
  defaultValue: 'single',
);

const String _single = '''
[Event "Vereinsmeisterschaft 2026"]
[Site "Zürich SUI"]
[Date "2026.03.14"]
[Round "5"]
[White "Muster, Anna"]
[Black "Beispiel, Bruno"]
[Result "1/2-1/2"]
[WhiteElo "1874"]
[BlackElo "1902"]

{Meine erste Partie gegen Bruno.}
1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. 0-0 Be7 6. Re1 b5 7. Bb3 d6
8. c3 0-0 9. h3!? (9. d4 Bg4 10. Be3 exd4 11. cxd4 Na5) 9... Nb8 10. d4 Nbd7
11. Nbd2 Bb7 12. Bc2 Re8 13. Nf1 Bf8 14. Ng3 g6 1/2-1/2
''';

const String _multi = '''
[Event "Schulschach-Turnier"]
[Date "2026.05.02"]
[Round "1"]
[White "Carla Probe"]
[Black "David Test"]
[Result "1-0"]

1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# 1-0

[Event "Schulschach-Turnier"]
[Date "2026.05.02"]
[Round "2"]
[White "Emil Exempel"]
[Black "Carla Probe"]
[Result "1-0"]

1. e4 e5 2. Nf3 d6 3. Bc4 Bg4 4. Nc3 g6 5. Nxe5 Bxd1 6. Bxf7+ Ke7 7. Nd5# 1-0

[Event "Schulschach-Turnier"]
[Date "2026.05.02"]
[Round "3"]
[White "Carla Probe"]
[Black "Fiona Muster"]
[Result "0-1"]

1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7 5. e3 O-O 6. Nf3 h6 7. Bh5 b6 0-1
''';

const String _error = '''
[White "Gregor Fehler"]
[Black "Hanna Richtig"]
[Result "0-1"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6
5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. Bd5 Nxd5
9. exd5 Na5 10. Nxe5 dxe5 11. Rxe5 O-O 12. Qh5 Bd6
13. Rh5 g6 0-1
''';

void main() => runApp(const ProviderScope(child: ImportDemoApp()));

class ImportDemoApp extends StatelessWidget {
  const ImportDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Import demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Builder(
        builder: (context) => ImportScreen(
          initialText: switch (_demo) {
            'multi' => _multi,
            'error' => _error,
            _ => _single,
          },
          onContinue: (ImportResult result) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${result.plyCount} plies: ${result.movetext}'),
              ),
            );
          },
        ),
      ),
    );
  }
}
