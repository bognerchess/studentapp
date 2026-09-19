// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Keys of the form's controls, for tests and for the simulator tool.
abstract final class MetadataFormKeys {
  static const Key color = ValueKey('metadata-color');
  static const Key outcome = ValueKey('metadata-outcome');
  static const Key opponentName = ValueKey('metadata-opponent-name');
  static const Key opponentRating = ValueKey('metadata-opponent-rating');
  static const Key playerName = ValueKey('metadata-player-name');
  static const Key playerRating = ValueKey('metadata-player-rating');
  static const Key ratingHint = ValueKey('metadata-rating-hint');
  static const Key date = ValueKey('metadata-date');
  static const Key dateClear = ValueKey('metadata-date-clear');
  static const Key event = ValueKey('metadata-event');
  static const Key timeControlDetail = ValueKey('metadata-tc-detail');

  static Key result(GameResult result) =>
      ValueKey('metadata-result-${result.name}');
  static Key timeControl(TimeControlKind kind) =>
      ValueKey('metadata-tc-${kind.name}');
}

/// The game metadata form (PRD IN-2), built for a phone and for speed: two
/// taps (colour, result) and one name finish the usual case.
///
/// It is a plain column, not a route and not a scroll view: put it into a
/// `SingleChildScrollView` or a sheet. It owns its editing state.
/// [initial] is read once, like `TextFormField.initialValue`; give the form a
/// new [key] to load other metadata. Every edit is reported through
/// [onChanged], valid or not; ask `GameMetadata.validate()` whether it can be
/// saved. When the form fills something in on its own at the start (today's
/// date, [defaultPlayerName]), it reports that once, right after the first
/// frame.
class MetadataForm extends StatefulWidget {
  const MetadataForm({
    super.key,
    required this.initial,
    required this.onChanged,
    this.defaultPlayerName,
    this.autofocus = false,
    this.swapSidesOnColorChange = true,
    this.defaultDateToToday = true,
    this.today,
  });

  final GameMetadata initial;
  final ValueChanged<GameMetadata> onChanged;

  /// The user's own name (from the account), filled into the "Your name"
  /// field when [initial] has no name there.
  final String? defaultPlayerName;

  /// Focus the opponent's name right away and bring up the keyboard.
  final bool autofocus;

  /// What "I played Black" does to the names and ratings.
  ///
  /// True, for a game the user entered: what was typed is "me" and "my
  /// opponent", so changing the colour moves both to the other side of the
  /// board. False, for an imported PGN or a stored game: White and Black are
  /// facts, so changing the colour only changes which of them is "me". With
  /// false and no colour yet, the fields are labelled "White" and "Black".
  final bool swapSidesOnColorChange;

  /// Start with today's date when [initial] has none. Right after playing a
  /// game; wrong for an imported PGN whose date is simply unknown.
  final bool defaultDateToToday;

  /// Today, for tests. Defaults to the device's calendar.
  final GameDate? today;

  @override
  State<MetadataForm> createState() => _MetadataFormState();
}

class _MetadataFormState extends State<MetadataForm> {
  final _opponentName = TextEditingController();
  final _opponentRating = TextEditingController();
  final _playerName = TextEditingController();
  final _playerRating = TextEditingController();
  final _event = TextEditingController();
  final _timeControlDetail = TextEditingController();

  final _opponentNameFocus = FocusNode(debugLabel: 'opponent name');
  final _opponentRatingFocus = FocusNode(debugLabel: 'opponent rating');
  final _playerNameFocus = FocusNode(debugLabel: 'player name');
  final _playerRatingFocus = FocusNode(debugLabel: 'player rating');
  final _eventFocus = FocusNode(debugLabel: 'event');
  final _timeControlDetailFocus = FocusNode(debugLabel: 'time control');

  PlayerColor? _color;
  GameResult _result = GameResult.unknown;
  GameDate? _date;
  TimeControlKind? _kind;

  /// Once the user has tapped a time-control chip, typing numbers no longer
  /// changes the chip.
  bool _kindIsUserChoice = false;

  GameDate get _today => widget.today ?? GameDate.today();

  /// While the colour is unknown the "player" fields hold White.
  PlayerColor get _playerSide => _color ?? PlayerColor.white;

  /// An imported game before the user has said which side they were: there
  /// is no "you" yet, so the fields are named after the colours.
  bool get _labelByColor => _color == null && !widget.swapSidesOnColorChange;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _color = initial.playerColor;
    _result = initial.result;
    _date = initial.playedDate ?? (widget.defaultDateToToday ? _today : null);
    _kind = initial.timeControl?.kind;
    _kindIsUserChoice = _kind != null;
    _event.text = initial.eventName ?? '';
    _timeControlDetail.text = initial.timeControl?.detail ?? '';
    _loadSides(initial);

    _fillInDefaultPlayerName();

    // Ratings complain only after the field is left: "15" on the way to
    // "1500" is not a mistake.
    _opponentRatingFocus.addListener(_rebuild);
    _playerRatingFocus.addListener(_rebuild);

    final current = _current();
    if (current != initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onChanged(current);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _opponentName,
      _opponentRating,
      _playerName,
      _playerRating,
      _event,
      _timeControlDetail,
    ]) {
      controller.dispose();
    }
    for (final node in [
      _opponentNameFocus,
      _opponentRatingFocus,
      _playerNameFocus,
      _playerRatingFocus,
      _eventFocus,
      _timeControlDetailFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// Fills the name and rating fields from [metadata], with [_playerSide] as
  /// the user.
  void _loadSides(GameMetadata metadata) {
    final playerIsWhite = _playerSide == PlayerColor.white;
    final (playerName, opponentName) = playerIsWhite
        ? (metadata.whiteName, metadata.blackName)
        : (metadata.blackName, metadata.whiteName);
    final (playerRating, opponentRating) = playerIsWhite
        ? (metadata.whiteRating, metadata.blackRating)
        : (metadata.blackRating, metadata.whiteRating);
    _playerName.text = playerName ?? '';
    _opponentName.text = opponentName ?? '';
    _playerRating.text = playerRating?.toString() ?? '';
    _opponentRating.text = opponentRating?.toString() ?? '';
  }

  /// Not while the fields are "White" and "Black": nobody knows yet which of
  /// them the user is.
  void _fillInDefaultPlayerName() {
    final defaultName = widget.defaultPlayerName?.trim() ?? '';
    if (_playerName.text.isEmpty && defaultName.isNotEmpty && !_labelByColor) {
      _playerName.text = defaultName;
    }
  }

  /// The metadata as the form shows it now.
  GameMetadata _current() {
    final detail = _timeControlDetail.text.trim();
    final kind = _kind ?? TimeControl.kindForDetail(detail);
    return GameMetadata.forPlayer(
      playerColor: _playerSide,
      playerName: _playerName.text,
      opponentName: _opponentName.text,
      playerRating: int.tryParse(_playerRating.text),
      opponentRating: int.tryParse(_opponentRating.text),
      result: _result,
      playedDate: _date,
      eventName: _event.text,
      timeControl: kind == null && detail.isEmpty
          ? null
          : TimeControl(kind ?? TimeControlKind.other, detail: detail),
    ).copyWith(playerColor: _color);
  }

  void _changed([VoidCallback? change]) {
    setState(change ?? () {});
    widget.onChanged(_current());
  }

  void _onColor(Set<PlayerColor> selection) {
    // Tapping the selected segment would clear it. The colour is required,
    // so there is no way back to "nothing".
    final next = selection.firstOrNull;
    if (next == null || next == _color) {
      return;
    }
    if (widget.swapSidesOnColorChange) {
      // The fields are "me" and "my opponent" and stay as they are; they
      // land on the other side of the board.
      _changed(() => _color = next);
    } else {
      // White and Black are facts; show the other one as "me".
      final facts = _current();
      _changed(() {
        _color = next;
        _loadSides(facts);
        _fillInDefaultPlayerName();
      });
    }
  }

  void _onResult(GameResult result) {
    // Tapping the selected chip again takes the result back.
    _changed(() => _result = _result == result ? GameResult.unknown : result);
  }

  void _onKind(TimeControlKind kind) {
    _changed(() {
      if (_kind == kind) {
        _kindIsUserChoice = false;
        _kind = TimeControl.kindForDetail(_timeControlDetail.text);
      } else {
        _kindIsUserChoice = true;
        _kind = kind;
      }
    });
  }

  void _onTimeControlDetail(String text) {
    _changed(() {
      if (!_kindIsUserChoice) {
        _kind = TimeControl.kindForDetail(text);
      }
    });
  }

  Future<void> _pickDate() async {
    final today = _today;
    final shown = _date ?? today;
    final latest = shown.isAfter(today) ? shown : today;
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: shown.toLocalDateTime(),
      firstDate: DateTime(1850),
      lastDate: latest.toLocalDateTime(),
    );
    if (picked != null && mounted) {
      _changed(() => _date = GameDate.fromDateTime(picked));
    }
  }

  /// Where "next" on the keyboard goes: down the form, but past a name that
  /// is already there (the user's own, normally).
  void _focusAfter(FocusNode node) {
    final order = [
      _opponentNameFocus,
      _opponentRatingFocus,
      _playerNameFocus,
      _playerRatingFocus,
      _eventFocus,
      _timeControlDetailFocus,
    ];
    if (_labelByColor) {
      // White (the "player" fields) comes first in this layout.
      order
        ..remove(_opponentNameFocus)
        ..remove(_opponentRatingFocus)
        ..insertAll(2, [_opponentNameFocus, _opponentRatingFocus]);
    }
    var index = order.indexOf(node) + 1;
    if (index < order.length &&
        order[index] == _playerNameFocus &&
        _playerName.text.trim().isNotEmpty &&
        !_labelByColor) {
      index++;
    }
    if (index < order.length) {
      order[index].requestFocus();
    } else {
      node.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validation = _current().validate(today: _today);

    final playerRow = _NameAndRating(
      nameKey: MetadataFormKeys.playerName,
      ratingKey: MetadataFormKeys.playerRating,
      nameLabel: _labelByColor
          ? l10n.metadataColorWhite
          : l10n.metadataPlayerName,
      ratingSemanticLabel: _labelByColor
          ? l10n.metadataWhiteRatingA11y
          : l10n.metadataPlayerRatingA11y,
      name: _playerName,
      rating: _playerRating,
      nameFocus: _playerNameFocus,
      ratingFocus: _playerRatingFocus,
      autofillOwnName: !_labelByColor,
      onChanged: (_) => _changed(),
      onNext: _focusAfter,
    );
    final opponentRow = _NameAndRating(
      nameKey: MetadataFormKeys.opponentName,
      ratingKey: MetadataFormKeys.opponentRating,
      nameLabel: _labelByColor
          ? l10n.metadataColorBlack
          : l10n.metadataOpponentName,
      ratingSemanticLabel: _labelByColor
          ? l10n.metadataBlackRatingA11y
          : l10n.metadataOpponentRatingA11y,
      name: _opponentName,
      rating: _opponentRating,
      nameFocus: _opponentNameFocus,
      ratingFocus: _opponentRatingFocus,
      autofocus: widget.autofocus,
      onChanged: (_) => _changed(),
      onNext: _focusAfter,
    );
    const gap = SizedBox(height: AppSpacing.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.metadataColorLabel),
        _ColorControl(color: _color, onChanged: _onColor),
        gap,
        _SectionLabel(l10n.metadataResultLabel),
        _ResultChips(result: _result, onSelected: _onResult),
        _OutcomeLine(outcome: _current().playerOutcome),
        gap,
        _SectionLabel(l10n.metadataPlayersLabel),
        // Room for the label that floats on the field's top border.
        const SizedBox(height: AppSpacing.sm),
        // The opponent is what has to be typed, so it comes first; the
        // user's own row is filled in already. White before Black when
        // there is no "you" yet.
        if (_labelByColor) ...[
          playerRow,
          gap,
          opponentRow,
        ] else ...[
          opponentRow,
          gap,
          playerRow,
          if (_playerRating.text.isEmpty)
            Padding(
              key: MetadataFormKeys.ratingHint,
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: const _RatingHint(),
            ),
        ],
        gap,
        _DateField(
          date: _date,
          isInvalid:
              validation.problemOf(MetadataField.playedDate) ==
              MetadataProblem.invalid,
          onTap: _pickDate,
          onClear: () => _changed(() => _date = null),
        ),
        gap,
        TextField(
          key: MetadataFormKeys.event,
          controller: _event,
          focusNode: _eventFocus,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: l10n.metadataEventLabel,
            hintText: l10n.metadataEventHint,
          ),
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            LengthLimitingTextInputFormatter(GameMetadata.maxEventLength),
          ],
          onChanged: (_) => _changed(),
          onSubmitted: (_) => _focusAfter(_eventFocus),
        ),
        gap,
        _SectionLabel(l10n.metadataTimeControlLabel),
        _TimeControlChips(kind: _kind, onSelected: _onKind),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: MetadataFormKeys.timeControlDetail,
          controller: _timeControlDetail,
          focusNode: _timeControlDetailFocus,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: l10n.metadataTimeControlDetail,
            hintText: l10n.metadataTimeControlDetailHint,
          ),
          // Digits with "+" on the first keyboard page, and a return key,
          // which the plain number pad does not have.
          keyboardType: TextInputType.datetime,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            LengthLimitingTextInputFormatter(TimeControl.maxDetailLength),
          ],
          onChanged: _onTimeControlDetail,
          onSubmitted: (_) => _focusAfter(_timeControlDetailFocus),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ColorControl extends StatelessWidget {
  const _ColorControl({required this.color, required this.onChanged});

  final PlayerColor? color;
  final ValueChanged<Set<PlayerColor>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<PlayerColor>(
      key: MetadataFormKeys.color,
      segments: [
        ButtonSegment(
          value: PlayerColor.white,
          icon: const _PieceDot(PlayerColor.white),
          label: Text(l10n.metadataColorWhite),
        ),
        ButtonSegment(
          value: PlayerColor.black,
          icon: const _PieceDot(PlayerColor.black),
          label: Text(l10n.metadataColorBlack),
        ),
      ],
      selected: {?color},
      emptySelectionAllowed: true,
      // The check mark would replace the piece-colour icon.
      showSelectedIcon: false,
      onSelectionChanged: onChanged,
    );
  }
}

/// A white or a black disc. Not an icon: an icon takes the text colour, and
/// in the dark theme that would paint the black piece white.
class _PieceDot extends StatelessWidget {
  const _PieceDot(this.color);

  final PlayerColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color == PlayerColor.white
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF000000),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1.5,
        ),
      ),
    );
  }
}

class _ResultChips extends StatelessWidget {
  const _ResultChips({required this.result, required this.onSelected});

  final GameResult result;
  final ValueChanged<GameResult> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chips = [
      (GameResult.whiteWins, '1-0', l10n.metadataResultWhiteWinsA11y),
      (GameResult.draw, '½-½', l10n.metadataResultDrawA11y),
      (GameResult.blackWins, '0-1', l10n.metadataResultBlackWinsA11y),
      (GameResult.unknown, l10n.metadataResultUnknown, null),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final (value, label, semanticsLabel) in chips)
          ChoiceChip(
            key: MetadataFormKeys.result(value),
            label: Text(label, semanticsLabel: semanticsLabel),
            selected: result == value,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}

/// "You won." under the chips: 1-0 and 0-1 are easy to mix up when you had
/// Black.
class _OutcomeLine extends StatelessWidget {
  const _OutcomeLine({required this.outcome});

  final PlayerOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final text = switch (outcome) {
      null => null,
      PlayerOutcome.win => l10n.metadataOutcomeWin,
      PlayerOutcome.loss => l10n.metadataOutcomeLoss,
      PlayerOutcome.draw => l10n.metadataOutcomeDraw,
    };
    if (text == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        key: MetadataFormKeys.outcome,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A name with the rating next to it, which is how players think of it
/// ("Müller, 1840").
class _NameAndRating extends StatelessWidget {
  const _NameAndRating({
    required this.nameKey,
    required this.ratingKey,
    required this.nameLabel,
    required this.ratingSemanticLabel,
    required this.name,
    required this.rating,
    required this.nameFocus,
    required this.ratingFocus,
    required this.onChanged,
    required this.onNext,
    this.autofocus = false,
    this.autofillOwnName = false,
  });

  final Key nameKey;
  final Key ratingKey;
  final String nameLabel;
  final String ratingSemanticLabel;
  final TextEditingController name;
  final TextEditingController rating;
  final FocusNode nameFocus;
  final FocusNode ratingFocus;
  final ValueChanged<String> onChanged;
  final ValueChanged<FocusNode> onNext;
  final bool autofocus;
  final bool autofillOwnName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = int.tryParse(rating.text);
    // Too high is wrong at once; too low only once the field is left.
    final showRatingError =
        value != null &&
        (value > GameMetadata.maxRating ||
            (value < GameMetadata.minRating && !ratingFocus.hasFocus));
    // Wide enough for "Rating" and four digits at any text size.
    final ratingWidth = MediaQuery.textScalerOf(context).scale(84) + 12;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: nameKey,
            controller: name,
            focusNode: nameFocus,
            autofocus: autofocus,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: nameLabel,
            ),
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            autofillHints: autofillOwnName ? const [AutofillHints.name] : null,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              LengthLimitingTextInputFormatter(GameMetadata.maxNameLength),
            ],
            onChanged: onChanged,
            onSubmitted: (_) => onNext(nameFocus),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: ratingWidth,
          child: Semantics(
            label: ratingSemanticLabel,
            child: TextField(
              key: ratingKey,
              controller: rating,
              focusNode: ratingFocus,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: l10n.metadataRatingLabel,
                errorText: showRatingError
                    ? l10n.metadataRatingError(
                        GameMetadata.minRating,
                        GameMetadata.maxRating,
                      )
                    : null,
              ),
              // Not TextInputType.number: the iOS number pad has no return
              // key, and "next" is what makes this form fast.
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              onChanged: onChanged,
              onSubmitted: (_) => onNext(ratingFocus),
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingHint extends StatelessWidget {
  const _RatingHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(Icons.lightbulb_outline, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            context.l10n.metadataRatingHint,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.isInvalid,
    required this.onTap,
    required this.onClear,
  });

  final GameDate? date;
  final bool isInvalid;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final date = this.date;
    final text = date == null
        ? l10n.metadataDateUnknown
        : MaterialLocalizations.of(context)
              .formatShortDate(date.toLocalDateTime());

    return InkWell(
      key: MetadataFormKeys.date,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: l10n.metadataDateLabel,
          errorText: isInvalid ? l10n.metadataDateFuture : null,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: date == null
              ? null
              : IconButton(
                  key: MetadataFormKeys.dateClear,
                  icon: const Icon(Icons.close),
                  tooltip: l10n.metadataDateClear,
                  onPressed: onClear,
                ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: date == null ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
      ),
    );
  }
}

class _TimeControlChips extends StatelessWidget {
  const _TimeControlChips({required this.kind, required this.onSelected});

  final TimeControlKind? kind;
  final ValueChanged<TimeControlKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String label(TimeControlKind kind) => switch (kind) {
      TimeControlKind.classical => l10n.metadataTimeControlClassical,
      TimeControlKind.rapid => l10n.metadataTimeControlRapid,
      TimeControlKind.blitz => l10n.metadataTimeControlBlitz,
      TimeControlKind.bullet => l10n.metadataTimeControlBullet,
      TimeControlKind.other => l10n.metadataTimeControlOther,
    };
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final value in TimeControlKind.values)
          ChoiceChip(
            key: MetadataFormKeys.timeControl(value),
            label: Text(label(value)),
            selected: kind == value,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}
