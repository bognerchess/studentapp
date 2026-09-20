// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_error.dart';
import 'package:flutter/foundation.dart';

/// A value this build does not know reads as [unknown].
enum AccountDeletionStatus { pending, completed, blocked, failed, unknown }

@immutable
class AccountDeletionInfo {
  const AccountDeletionInfo({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.completedAt,
  });

  final String id;

  /// [AccountDeletionStatus.pending] means the personal data is gone and an
  /// external step is still being retried. For the app both pending and
  /// completed mean: sign out, the account is gone.
  final AccountDeletionStatus status;
  final DateTime requestedAt;
  final DateTime? completedAt;
}

/// What `AccountApi.deleteMyAccount` came to.
sealed class DeleteAccountOutcome {
  const DeleteAccountOutcome();
}

final class AccountDeletionRequested extends DeleteAccountOutcome {
  const AccountDeletionRequested(this.deletion);
  final AccountDeletionInfo deletion;
}

/// The account cannot be deleted from the app, e.g. because it still owns a
/// club. [reason] is a machine-readable key.
final class AccountDeletionBlocked extends DeleteAccountOutcome {
  const AccountDeletionBlocked(this.reason);
  final String reason;
}

final class AccountDeletionFailed extends DeleteAccountOutcome {
  const AccountDeletionFailed(this.error);
  final ApiError error;
}
