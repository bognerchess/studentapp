// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

/// Marks a text from the backend that has had no legal review yet
/// (`LegalDocument.isDraft`), so that nobody mistakes a placeholder for the
/// real thing on a test build.
class DraftBadge extends StatelessWidget {
  const DraftBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Semantics(
      container: true,
      label: l10n.legalDraftHint,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.warning,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.edit_note, size: 20, color: colors.onWarning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${l10n.legalDraftLabel}  ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      TextSpan(text: l10n.legalDraftHint),
                    ],
                  ),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onWarning),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
