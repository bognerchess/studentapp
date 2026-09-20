// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/api_error.dart';
import 'package:bogner_chess/core/api/generated/operations/account.graphql.dart';
import 'package:bogner_chess/core/api/generated/schema.graphql.dart';
import 'package:bogner_chess/core/api/mappers/enum_mappers.dart';
import 'package:bogner_chess/core/api/mappers/mutation_error.dart';
import 'package:bogner_chess/core/api/models/account_models.dart';

export 'package:bogner_chess/core/api/api_error.dart';
export 'package:bogner_chess/core/api/models/account_models.dart';

/// The user's account.
class AccountApi {
  AccountApi(this._executor);

  final ApiExecutor _executor;

  /// The phrase the server insists on. The UI asks the user to confirm in its
  /// own words; this is not shown.
  static const String _confirmation = 'DELETE';

  /// In-app account deletion (App Store guideline 5.1.1(v)). Not reversible.
  /// After [AccountDeletionRequested] the caller signs out. Never throws.
  Future<DeleteAccountOutcome> deleteMyAccount() async {
    final Mutation$DeleteMyAccount data;
    try {
      data = await _executor.mutate(
        document: documentNodeMutationDeleteMyAccount,
        operationName: 'DeleteMyAccount',
        variables: Variables$Mutation$DeleteMyAccount(
          input: Input$DeleteMyAccountInput(confirmation: _confirmation),
        ).toJson(),
        parse: Mutation$DeleteMyAccount.fromJson,
      );
    } on ApiError catch (e) {
      return AccountDeletionFailed(e);
    }
    final payload = data.deleteMyAccount;
    final error = MutationError.firstOf(payload.errors?.map((e) => e.toJson()));
    if (error != null) {
      final reason = error.string('reason');
      return error.typename == 'AccountDeletionBlockedError' && reason != null
          ? AccountDeletionBlocked(reason)
          : AccountDeletionFailed(error.toRejected());
    }
    final deletion = payload.accountDeletion;
    if (deletion == null) {
      return AccountDeletionFailed(emptyPayload('DeleteMyAccount'));
    }
    return AccountDeletionRequested(
      AccountDeletionInfo(
        id: deletion.id,
        status: accountDeletionStatusOf(deletion.status),
        requestedAt: deletion.requestedAt,
        completedAt: deletion.completedAt,
      ),
    );
  }
}
