// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/features/metadata/ui/metadata_form.dart';
import 'package:material_ui/material_ui.dart';

/// What [MetadataScreen] is opened with. Travels as go_router's `extra`:
/// `context.push<GameMetadata>(AppRoutes.newGameMetadata, extra: args)`.
@immutable
class MetadataScreenArgs {
  const MetadataScreenArgs({
    this.initial = const GameMetadata(),
    this.defaultPlayerName,
    this.swapSidesOnColorChange = true,
    this.defaultDateToToday = true,
    this.autofocus = false,
  });

  /// For a game that came with its own facts (an imported PGN, a stored
  /// game): White and Black stay where they are and an unknown date stays
  /// unknown.
  const MetadataScreenArgs.existingGame({
    required this.initial,
    this.defaultPlayerName,
  }) : swapSidesOnColorChange = false,
       defaultDateToToday = false,
       autofocus = false;

  final GameMetadata initial;

  /// See [MetadataForm.defaultPlayerName].
  final String? defaultPlayerName;

  /// See [MetadataForm.swapSidesOnColorChange].
  final bool swapSidesOnColorChange;

  /// See [MetadataForm.defaultDateToToday].
  final bool defaultDateToToday;

  /// See [MetadataForm.autofocus].
  final bool autofocus;
}

/// The metadata form as a full screen with a Save button. Save pops the
/// route with the edited [GameMetadata]; back pops with null. Save is enabled
/// once `validate()` has nothing to complain about.
class MetadataScreen extends StatefulWidget {
  const MetadataScreen({
    super.key,
    this.args = const MetadataScreenArgs(),
    this.today,
  });

  static const Key saveKey = ValueKey('metadata-save');
  static const Key saveHintKey = ValueKey('metadata-save-hint');

  final MetadataScreenArgs args;

  /// Today, for tests.
  final GameDate? today;

  @override
  State<MetadataScreen> createState() => _MetadataScreenState();
}

class _MetadataScreenState extends State<MetadataScreen> {
  late GameMetadata _metadata = widget.args.initial;

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop<GameMetadata>(_metadata);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final args = widget.args;
    final validation = _metadata.validate(today: widget.today);
    final saveHint = validation.isValid
        ? null
        : validation.missing.contains(MetadataField.playerColor)
        ? l10n.metadataSaveNeedsColor
        : l10n.metadataSaveNeedsFix;

    return AppScaffold(
      title: l10n.metadataTitle,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.page),
        child: MetadataForm(
          initial: args.initial,
          defaultPlayerName: args.defaultPlayerName,
          swapSidesOnColorChange: args.swapSidesOnColorChange,
          defaultDateToToday: args.defaultDateToToday,
          autofocus: args.autofocus,
          today: widget.today,
          onChanged: (metadata) => setState(() => _metadata = metadata),
        ),
      ),
      // The line tells the form, which scrolls underneath, from the bar.
      bottomBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (saveHint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  saveHint,
                  key: MetadataScreen.saveHintKey,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            FilledButton(
              key: MetadataScreen.saveKey,
              onPressed: validation.isValid ? _save : null,
              child: Text(l10n.metadataSave),
            ),
          ],
        ),
      ),
    );
  }
}
