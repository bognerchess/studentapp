// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/metadata/ui/metadata_screen.dart';
import 'package:material_ui/material_ui.dart';

/// A development entry point that shows nothing but the metadata screen, for
/// looking at it in the simulator before a flow leads to it:
///
///     flutter build ios --simulator --debug \
///       --dart-define-from-file=config/fake.json \
///       -t lib/features/metadata/dev/metadata_demo.dart
///
/// `--dart-define=METADATA_DEMO=filled` starts with an imported game instead
/// of an empty form, `METADATA_DEMO=autofocus` with the keyboard up. Not part
/// of the app: nothing imports this file.
void main() => runApp(const MetadataDemoApp());

const String _variant = String.fromEnvironment('METADATA_DEMO');

class MetadataDemoApp extends StatelessWidget {
  const MetadataDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: MetadataScreen(
        args: _variant == 'filled'
            ? MetadataScreenArgs.existingGame(
                initial: GameMetadata.fromPgnHeaders(const {
                  'Event': 'Zürcher Mannschaftsmeisterschaft',
                  'Date': '2026.09.12',
                  'White': 'Beispiel, Bettina',
                  'Black': 'Muster, Max',
                  'Result': '0-1',
                  'WhiteElo': '1840',
                  'BlackElo': '1712',
                  'TimeControl': '5400+30',
                }, playerName: 'Max Muster'),
              )
            : const MetadataScreenArgs(
                defaultPlayerName: 'Max Muster',
                autofocus: _variant == 'autofocus',
              ),
      ),
    );
  }
}
