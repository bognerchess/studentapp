// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:math' as math;

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/core/ui/widgets/error_retry.dart';
import 'package:bogner_chess/features/about/domain/licence_document.dart';
import 'package:material_ui/material_ui.dart';

/// Shows one of the bundled legal texts in full: scrollable, selectable (so
/// that a passage can be copied), in a monospace face like the file itself.
///
/// The texts are English only, as published; translations of the GPL are not
/// legally valid, so the screen does not pretend to have one.
class LicenceTextScreen extends StatefulWidget {
  const LicenceTextScreen({
    super.key,
    required this.title,
    required this.document,
    this.warning,
  });

  final String title;
  final LicenceDocument document;

  /// Shown above the text in a warning box, for a text that is not in force.
  final String? warning;

  static const Key listKey = ValueKey('licence-text-list');
  static const Key warningKey = ValueKey('licence-text-warning');

  @override
  State<LicenceTextScreen> createState() => _LicenceTextScreenState();
}

class _LicenceTextScreenState extends State<LicenceTextScreen> {
  Future<List<TextBlock>>? _blocks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _blocks ??= _load();
  }

  Future<List<TextBlock>> _load() async {
    final bundle = DefaultAssetBundle.of(context);
    // Not cached: nobody reads the GPL twice in a session, so the bundle
    // need not hold on to it for the life of the process. (It also keeps
    // widget tests independent: a cached future belongs to the zone of the
    // test that created it and never completes in the next one.)
    final text = await bundle.loadString(
      widget.document.assetKey,
      cache: false,
    );
    return parseTextBlocks(text);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title,
      body: FutureBuilder<List<TextBlock>>(
        future: _blocks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorRetry(
              message: context.l10n.aboutDocumentLoadFailed,
              onRetry: () => setState(() => _blocks = _load()),
            );
          }
          final blocks = snapshot.data;
          if (blocks == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _BlockList(blocks: blocks, warning: widget.warning);
        },
      ),
    );
  }
}

class _BlockList extends StatelessWidget {
  const _BlockList({required this.blocks, required this.warning});

  final List<TextBlock> blocks;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Menlo and Courier New come with iOS; nothing is bundled.
    final mono = TextStyle(
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['Courier New', 'Courier', 'monospace'],
      fontSize: 13,
      height: 1.45,
      color: theme.colorScheme.onSurface,
    );
    final leading = warning == null ? 0 : 1;

    return SelectionArea(
      child: Scrollbar(
        child: ListView.builder(
          key: LicenceTextScreen.listKey,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.md,
          ),
          itemCount: blocks.length + leading,
          itemBuilder: (context, index) {
            if (index < leading) {
              return _WarningBox(text: warning!);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _BlockView(block: blocks[index - leading], style: mono),
            );
          },
        ),
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block, required this.style});

  final TextBlock block;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (block.kind) {
      case TextBlockKind.prose:
        return Padding(
          // Half a character per column keeps nested lists apart without
          // giving away a third of a phone's width.
          padding: EdgeInsets.only(left: math.min(block.indent * 4.0, 32)),
          child: Text(block.text, style: style),
        );
      case TextBlockKind.centered:
        return Text(
          block.text,
          style: style.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        );
      case TextBlockKind.quote:
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: theme.colorScheme.outline, width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Text(block.text, style: style),
          ),
        );
      case TextBlockKind.preformatted:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(block.text, style: style, softWrap: false),
        );
    }
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        key: LicenceTextScreen.warningKey,
        decoration: BoxDecoration(
          color: colors.warning,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.onWarning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onWarning,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
