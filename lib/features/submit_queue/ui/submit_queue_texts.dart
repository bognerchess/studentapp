// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/features/submit_queue/domain/draft_meta.dart';
import 'package:bogner_chess/features/submit_queue/domain/submit_models.dart';

/// Words for the codes the queue stores. Each is a full sentence.
String submitErrorText(AppLocalizations l10n, SubmitError error) {
  switch (error.kind) {
    case SubmitErrorKind.network:
      return l10n.submitQueueErrorNetwork;
    case SubmitErrorKind.server:
      return l10n.submitQueueErrorServer;
    case SubmitErrorKind.rateLimited:
      return l10n.submitQueueErrorRateLimited;
    case SubmitErrorKind.unauthenticated:
      return l10n.submitQueueErrorUnauthenticated;
    case SubmitErrorKind.pgnInvalid:
      final moveNumber = error.moveNumber;
      final san = error.san;
      return moveNumber != null && san != null
          ? l10n.submitQueueErrorPgnInvalidAt(moveNumber, san)
          : l10n.submitQueueErrorPgnInvalid;
    case SubmitErrorKind.rejected:
      return l10n.submitQueueErrorRejected;
    case SubmitErrorKind.internal:
      return l10n.submitQueueErrorInternal;
  }
}

/// Why the analysis was not started, as a full sentence. Public: the game
/// detail screen says the same next to its "Analyse" button.
String analysisHoldText(AppLocalizations l10n, AnalysisHold hold) =>
    switch (hold) {
      AnalysisHold.limitReached => l10n.submitQueueHoldLimitReached,
      AnalysisHold.queueFull => l10n.submitQueueHoldQueueFull,
      AnalysisHold.rateLimited => l10n.submitQueueHoldRateLimited,
      AnalysisHold.emailNotVerified => l10n.submitQueueHoldEmailNotVerified,
      AnalysisHold.aiConsentRequired => l10n.submitQueueHoldAiConsentRequired,
      AnalysisHold.requestFailed => l10n.submitQueueHoldRequestFailed,
    };
