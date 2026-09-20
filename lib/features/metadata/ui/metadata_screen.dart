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

/// A button of [MetadataScreen]'s bottom bar that does something other than
/// popping the route. While [onPressed] runs, the buttons are disabled and
/// this one shows a progress ring.
@immutable
class MetadataAction {
  const MetadataAction({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function(GameMetadata metadata) onPressed;
}

/// The metadata form as a full screen with a Save button. Save pops the
/// route with the edited [GameMetadata]; back pops with null. Save is enabled
/// once `validate()` has nothing to complain about.
///
/// A host that wants to go on from here instead (the new-game flow: "Save &
/// analyse" and "Save only") passes [primaryAction] and, for a second button,
/// [secondaryAction]; the screen then never pops by itself.
class MetadataScreen extends StatefulWidget {
  const MetadataScreen({
    super.key,
    this.args = const MetadataScreenArgs(),
    this.today,
    this.primaryAction,
    this.secondaryAction,
  });

  static const Key saveKey = ValueKey('metadata-save');
  static const Key secondaryKey = ValueKey('metadata-save-secondary');
  static const Key saveHintKey = ValueKey('metadata-save-hint');

  final MetadataScreenArgs args;

  /// Replaces what the filled button does and says. Null: "Save", pops.
  final MetadataAction? primaryAction;

  /// A second, outlined button under the first one.
  final MetadataAction? secondaryAction;

  /// Today, for tests.
  final GameDate? today;

  @override
  State<MetadataScreen> createState() => _MetadataScreenState();
}

class _MetadataScreenState extends State<MetadataScreen> {
  late GameMetadata _metadata = widget.args.initial;

  /// The action that is running, if any: true for the primary one. (Not the
  /// action object: the host may build a new one with every rebuild.)
  bool? _running;

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop<GameMetadata>(_metadata);
  }

  Future<void> _run(MetadataAction action, {required bool primary}) async {
    if (_running != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _running = primary);
    try {
      await action.onPressed(_metadata);
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Widget _label(MetadataAction action, {required bool primary}) {
    if (_running != primary) return Text(action.label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(action.label)),
      ],
    );
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
    final primary = widget.primaryAction;
    final secondary = widget.secondaryAction;
    final enabled = validation.isValid && _running == null;

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
              onPressed: !enabled
                  ? null
                  : primary == null
                  ? _save
                  : () => _run(primary, primary: true),
              child: primary == null
                  ? Text(l10n.metadataSave)
                  : _label(primary, primary: true),
            ),
            if (secondary != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                key: MetadataScreen.secondaryKey,
                onPressed: enabled
                    ? () => _run(secondary, primary: false)
                    : null,
                child: _label(secondary, primary: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
