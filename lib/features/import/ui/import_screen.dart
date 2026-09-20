// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:isolate';

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/pgn/pgn_import.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/features/import/data/pgn_file_picker.dart';
import 'package:bogner_chess/features/import/domain/import_result.dart';
import 'package:bogner_chess/features/import/domain/pending_import.dart';
import 'package:bogner_chess/features/import/ui/import_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Texts up to this length are checked on the UI thread while the user types;
/// longer ones (whole tournament files) go to an isolate.
const int kImportIsolateThreshold = 64 * 1024;

/// How long the field has to be quiet before typed text is checked.
const Duration kImportDebounce = Duration(milliseconds: 300);

/// Import a game from PGN: paste, open a file, or type. The text is checked
/// as it changes. One valid game leads to a preview, several games to a list
/// to choose from, a problem to a panel that says what is wrong and where.
///
/// "Continue" hands an [ImportResult] to [onContinue], or, without a
/// callback, pops the route with it, so `await context.push<ImportResult>()`
/// works too.
///
/// Text from outside the app comes in through [initialText] or through
/// `pendingImportProvider`.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, this.initialText, this.onContinue});

  /// PGN to show and check right away.
  final String? initialText;

  final ValueChanged<ImportResult>? onContinue;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  String _checkedText = '';
  int _generation = 0;
  bool _mounting = true;

  bool _checking = false;
  PgnImportResult? _result;

  /// Where the text in the field came from, for [ImportResult.origin].
  ImportOrigin _origin = ImportOrigin.text;

  /// The game the detail area shows. Null while the list is shown.
  int? _selected;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialText;
    if (initial != null) _load(initial);
    _controller.addListener(_onTextChanged);
    _mounting = false;
    // Riverpod does not allow changing a provider while the tree is built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePending());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _takePending() {
    if (!mounted) return;
    final text = ref.read(pendingImportProvider.notifier).take();
    if (text != null) _load(text, origin: ImportOrigin.external);
  }

  /// Text that arrives in one piece: checked at once, keyboard away.
  void _load(String text, {ImportOrigin origin = ImportOrigin.text}) {
    _origin = origin;
    _focus.unfocus();
    _checkedText = text;
    _controller.text = text;
    unawaited(_check());
  }

  void _onTextChanged() {
    // The listener also fires when only the cursor moves.
    if (_controller.text == _checkedText) return;
    _origin = ImportOrigin.text;
    _checkedText = _controller.text;
    _debounce?.cancel();
    _debounce = Timer(kImportDebounce, () => unawaited(_check()));
  }

  Future<void> _check() async {
    _debounce?.cancel();
    final text = _controller.text;
    final generation = ++_generation;
    if (text.length <= kImportIsolateThreshold) {
      _show(parsePgnText(text));
      return;
    }
    _update(() => _checking = true);
    final result = await _parseInBackground(text);
    if (!mounted || generation != _generation) return;
    _show(result);
  }

  void _show(PgnImportResult result) {
    _update(() {
      _checking = false;
      _result = result;
      _selected = result.games.length == 1 ? 0 : null;
    });
  }

  void _update(VoidCallback change) {
    if (_mounting) {
      change();
    } else if (mounted) {
      setState(change);
    }
  }

  Future<void> _paste() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importClipboardEmpty)),
      );
      return;
    }
    _load(text);
  }

  Future<void> _openFile() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final pick = await ref.read(pgnFilePickerProvider).pick();
    if (!mounted) return;
    switch (pick) {
      case PgnFilePicked(:final text):
        _load(text, origin: ImportOrigin.file);
      case PgnFileCancelled():
        break;
      case PgnFileTooLarge():
        // Nothing was read. Say so instead of showing the previous game.
        _debounce?.cancel();
        _checkedText = '';
        _controller.clear();
        _generation++;
        _show(
          const PgnImportResult.failure(
            PgnImportError(PgnImportErrorCode.tooLarge, limit: kPgnMaxChars),
          ),
        );
      case PgnFileUnreadable():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.importFileUnreadable)),
        );
    }
  }

  void _clear() {
    _controller.clear();
    unawaited(_check());
  }

  void _continue(PgnImportedGame game) {
    final result = ImportResult.fromGame(game, origin: _origin);
    final onContinue = widget.onContinue;
    if (onContinue != null) {
      onContinue(result);
    } else {
      unawaited(Navigator.of(context).maybePop(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    // A second "Open in…" while the screen is already showing.
    ref.listen(pendingImportProvider, (previous, next) {
      if (next != null) scheduleMicrotask(_takePending);
    });

    final l10n = context.l10n;
    final games = _result?.games ?? const <PgnGameResult>[];
    final selected = _selected == null ? null : games[_selected!];

    return AppScaffold(
      title: l10n.importTitle,
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.sm,
        ),
        child: FilledButton(
          key: const ValueKey('import-continue'),
          onPressed: selected is PgnImportedGame
              ? () => _continue(selected)
              : null,
          child: Text(l10n.importContinue),
        ),
      ),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.page,
              AppSpacing.page,
              AppSpacing.md,
            ),
            sliver: SliverList.list(
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.tonalIcon(
                      key: const ValueKey('import-paste'),
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste),
                      label: Text(l10n.importPasteButton),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('import-open-file'),
                      onPressed: _openFile,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(l10n.importOpenFileButton),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _PgnField(
                  controller: _controller,
                  focusNode: _focus,
                  onClear: _clear,
                ),
              ],
            ),
          ),
          ..._status(context, games, selected),
          const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.lg)),
        ],
      ),
    );
  }

  List<Widget> _status(
    BuildContext context,
    List<PgnGameResult> games,
    PgnGameResult? selected,
  ) {
    final l10n = context.l10n;
    Widget padded(Widget child) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      sliver: SliverToBoxAdapter(child: child),
    );

    if (_checking) return [padded(const ImportChecking())];

    final result = _result;
    if (result == null || result.error?.code == PgnImportErrorCode.empty) {
      return [padded(const ImportHint())];
    }
    if (result.error case final error?) {
      return [
        padded(
          ImportErrorPanel(title: l10n.importErrorTitleText, error: error),
        ),
      ];
    }

    if (selected == null) {
      return [
        padded(ImportChooserHeader(count: games.length)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          sliver: SliverList.builder(
            itemCount: games.length,
            itemBuilder: (context, index) => ImportGameRow(
              key: ValueKey('import-game-$index'),
              game: games[index],
              onTap: () => setState(() => _selected = index),
            ),
          ),
        ),
      ];
    }

    return [
      if (games.length > 1)
        padded(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('import-choose-another'),
              onPressed: () => setState(() => _selected = null),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.importChooseAnother),
            ),
          ),
        ),
      padded(switch (selected) {
        PgnImportedGame() => ImportPreviewCard(game: selected),
        PgnRejectedGame(:final error) => ImportErrorPanel(
          title: l10n.importErrorTitleGame,
          error: error,
          players: selected.headers.isEmpty
              ? null
              : importPlayersOf(l10n, selected),
        ),
      }),
    ];
  }
}

Future<PgnImportResult> _parseInBackground(String text) =>
    Isolate.run(() => parsePgnText(text));

class _PgnField extends StatelessWidget {
  const _PgnField({
    required this.controller,
    required this.focusNode,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Stack(
      children: [
        TextField(
          key: const ValueKey('import-field'),
          controller: controller,
          focusNode: focusNode,
          // Small enough that the result below stays on the first screen.
          minLines: 4,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          enableSuggestions: false,
          // iOS would turn "--" and the quotes of the tags into typography.
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          decoration: InputDecoration(
            labelText: l10n.importFieldLabel,
            hintText: l10n.importFieldHint,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
              AppSpacing.md,
            ),
          ),
        ),
        PositionedDirectional(
          top: AppSpacing.xs,
          end: AppSpacing.xs,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    key: const ValueKey('import-clear'),
                    onPressed: onClear,
                    tooltip: l10n.importClear,
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
      ],
    );
  }
}
