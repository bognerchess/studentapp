// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/generated/operations/analysis.graphql.dart';
import 'package:bogner_chess/core/api/mappers/enum_mappers.dart';
import 'package:bogner_chess/core/api/models/analysis_models.dart';

export 'package:bogner_chess/core/api/api_error.dart';
export 'package:bogner_chess/core/api/models/analysis_models.dart'
    show AnalysisUsage, UsagePolicy;

/// The analysis quota.
class UsageApi {
  UsageApi(this._executor);

  final ApiExecutor _executor;

  /// Limits, usage and reset instants. Throws an `ApiError`.
  Future<AnalysisUsage> usage() async {
    final data = await _executor.query(
      document: documentNodeQueryMyAnalysisUsage,
      operationName: 'MyAnalysisUsage',
      parse: Query$MyAnalysisUsage.fromJson,
    );
    final usage = data.myAnalysisUsage;
    return AnalysisUsage(
      policy: usagePolicyOf(usage.policy),
      dailyLimit: usage.dailyLimit,
      dailyUsed: usage.dailyUsed,
      dailyResetAt: usage.dailyResetAt,
      monthlyLimit: usage.monthlyLimit,
      monthlyUsed: usage.monthlyUsed,
      monthlyResetAt: usage.monthlyResetAt,
      queuedJobs: usage.queuedJobs,
      maxQueuedJobs: usage.maxQueuedJobs,
    );
  }
}
