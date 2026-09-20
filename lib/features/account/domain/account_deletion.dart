// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/api/account_api.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:bogner_chess/core/api/account_api.dart'
    show ApiError, ApiNetworkError;

const _log = Log('account');

/// Where a person whose account cannot be deleted from the app turns to.
// TODO(confirm): the support address, before the first public build.
const String kSupportEmail = 'support@bognerchess.com';

/// What the user has to type before the delete button works. Not localised:
/// it is the token the backend expects, and one word to type is the same
/// effort in every language. The instruction around it is localised.
const String kDeleteConfirmationWord = 'DELETE';

/// The reasons the backend gives for refusing a deletion. Anything else
/// (a reason this build does not know) reads as [other].
enum DeletionBlockReason {
  kidAccount('kid_account'),
  hasDependents('has_dependents'),
  activeMembership('active_membership'),
  openInvoices('open_invoices'),
  other('');

  const DeletionBlockReason(this.wire);

  final String wire;

  static DeletionBlockReason of(String reason) => values.firstWhere(
    (value) => value.wire == reason.toLowerCase(),
    orElse: () => other,
  );
}

@immutable
sealed class AccountDeletionState {
  const AccountDeletionState();
}

final class DeletionIdle extends AccountDeletionState {
  const DeletionIdle();
}

final class DeletionInProgress extends AccountDeletionState {
  const DeletionInProgress();
}

/// The server refused; nothing was deleted.
final class DeletionBlocked extends AccountDeletionState {
  const DeletionBlocked(this.reason);
  final DeletionBlockReason reason;
}

/// The request did not get through, or the server could not do it; nothing
/// was deleted as far as the app knows. The user may try again.
final class DeletionFailed extends AccountDeletionState {
  const DeletionFailed(this.error);
  final ApiError error;
}

/// True from the moment the server accepted the deletion until the user has
/// read the confirmation. `AccountDeletedNotice` shows a full-screen message
/// above everything while it is true, so the confirmation survives the
/// redirect to the sign-in screen that the sign-out causes underneath.
final accountDeletedNoticeProvider =
    NotifierProvider<AccountDeletedNoticeNotifier, bool>(
      AccountDeletedNoticeNotifier.new,
    );

class AccountDeletedNoticeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void dismiss() => state = false;
}

/// In-app account deletion (App Store guideline 5.1.1(v)).
final accountDeletionProvider =
    NotifierProvider.autoDispose<
      AccountDeletionController,
      AccountDeletionState
    >(AccountDeletionController.new);

class AccountDeletionController extends Notifier<AccountDeletionState> {
  @override
  AccountDeletionState build() => const DeletionIdle();

  /// Back to the explanation, from the blocked state.
  void reset() => state = const DeletionIdle();

  /// Asks the server to delete the account. When it agrees: everything this
  /// app stored is removed (drafts too, for every account on the device,
  /// because nothing of a deleted person should stay), the session ends
  /// locally, and the confirmation is shown. The server has already ended
  /// the sessions of a deleted account, so a failing revocation call during
  /// the sign-out means nothing.
  Future<void> delete() async {
    if (state is DeletionInProgress) return;
    state = const DeletionInProgress();

    // Everything needed later is read now: the sign-out at the end removes
    // the screen, and with it this controller.
    final api = ref.read(accountApiProvider);
    final database = ref.read(appDatabaseProvider);
    final auth = ref.read(authRepositoryProvider);
    final analytics = ref.read(analyticsProvider);
    final notice = ref.read(accountDeletedNoticeProvider.notifier);

    final outcome = await api.deleteMyAccount();
    switch (outcome) {
      case AccountDeletionRequested():
        // Before the consent state goes away with the account.
        analytics.track(AnalyticsEvents.accountDeleted);
        notice.show();
        try {
          await database.wipeAll();
        } on Object catch (error) {
          _log.warning('local wipe after account deletion failed: $error');
        }
        await auth.signOut();
        if (ref.mounted) state = const DeletionIdle();
      case AccountDeletionBlocked(:final reason):
        if (ref.mounted) {
          state = DeletionBlocked(DeletionBlockReason.of(reason));
        }
      case AccountDeletionFailed(:final error):
        if (ref.mounted) state = DeletionFailed(error);
    }
  }
}
