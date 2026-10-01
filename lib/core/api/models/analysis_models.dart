// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parse_result.dart';
import 'package:bogner_chess/core/api/api_error.dart';
import 'package:bogner_chess/core/api/models/stage_models.dart';
import 'package:flutter/foundation.dart';

/// The window of a quota. A value this build does not know reads as [unknown].
enum LimitWindow { day, month, unknown }

/// What one of the analysis commands came to. Everything but
/// [AnalysisRequestFailed] is a decision of the server, not a fault.
sealed class RequestAnalysisOutcome {
  const RequestAnalysisOutcome();
}

/// The server took the request. For `analyseGame` that means the chain is
/// under way; for one of the four stage commands, that the stage run was
/// queued — also when a run of that stage was already going.
final class AnalysisAccepted extends RequestAnalysisOutcome {
  const AnalysisAccepted({this.run, this.workflow});

  /// The run a one-stage command started. Null for `analyseGame`, which
  /// queues whichever stage is next rather than one the caller named.
  final StageRun? run;

  /// The pipeline as the server reports it in the same answer. Null for the
  /// one-stage commands, whose payload carries only the run.
  final AnalysisWorkflow? workflow;

  /// The stage a one-stage command started; null for a chained analysis.
  AnalysisStage? get stage => run?.stage;

  /// Why the chain stops short of the coach, when it does. Quota, consent and
  /// the e-mail check are never errors of `analyseGame`: the engine result is
  /// produced anyway and this says what the user is missing.
  AnalysisTargetReason? get targetReason => workflow?.targetReason;
}

/// A stage was asked for before the stage it builds on was stored, or that
/// input has gone stale. The way forward is to run the earlier stage again,
/// which `nextRunnableStage` names; the app never has to know which one from
/// the error itself.
final class AnalysisPrerequisiteMissing extends RequestAnalysisOutcome {
  const AnalysisPrerequisiteMissing();
}

/// The quota of the [window] is used up. Terminal for the submit queue: the
/// game stays in the library and the limit is shown.
final class AnalysisLimitReached extends RequestAnalysisOutcome {
  const AnalysisLimitReached({
    required this.window,
    required this.limit,
    required this.used,
    required this.resetAt,
  });

  final LimitWindow window;
  final int limit;
  final int used;

  /// When the window starts again (UTC).
  final DateTime resetAt;
}

/// Too many jobs of this user are waiting already.
final class AnalysisQueueFull extends RequestAnalysisOutcome {
  const AnalysisQueueFull(this.maxQueuedJobs);
  final int maxQueuedJobs;
}

final class AnalysisRateLimited extends RequestAnalysisOutcome {
  const AnalysisRateLimited(this.retryAfter);
  final Duration retryAfter;
}

final class AnalysisEmailNotVerified extends RequestAnalysisOutcome {
  const AnalysisEmailNotVerified();
}

/// The user has to accept the AI consent text in [requiredVersion] first.
final class AnalysisAiConsentRequired extends RequestAnalysisOutcome {
  const AnalysisAiConsentRequired(this.requiredVersion);
  final int requiredVersion;
}

final class AnalysisRequestFailed extends RequestAnalysisOutcome {
  const AnalysisRequestFailed(this.error);
  final ApiError error;
}

/// Thumbs up or down on a coach comment.
enum CommentRating { up, down }

/// A finished analysis as it came from the server.
@immutable
class FetchedAnalysis {
  const FetchedAnalysis({
    required this.id,
    required this.gameId,
    required this.schemaVersion,
    required this.schemaMinor,
    required this.createdAt,
    required this.rawJson,
    required this.parsed,
    required this.feedback,
  });

  final String id;
  final String gameId;

  /// Major and minor version of the document, as the server reports them.
  final int schemaVersion;
  final int schemaMinor;
  final DateTime createdAt;

  /// The document, JSON-encoded, exactly as received: what the cache stores
  /// (`cached_analysis.payload`) and what `AnalysisParser.parseString` reads
  /// again after a restart.
  final String rawJson;

  /// [rawJson] run through the tolerant parser: supported, newer major
  /// version (board and moves with an update banner) or invalid.
  final AnalysisParseResult parsed;

  /// The user's own ratings, by comment id.
  final Map<String, CommentRating> feedback;
}

/// How the limits of the account are set. A value this build does not know
/// reads as [unknown]; the numbers are what counts.
enum UsagePolicy { standard, custom, unlimited, unknown }

/// The analysis quota of the user.
@immutable
class AnalysisUsage {
  const AnalysisUsage({
    required this.policy,
    required this.dailyUsed,
    required this.dailyResetAt,
    required this.monthlyUsed,
    required this.monthlyResetAt,
    required this.queuedJobs,
    required this.maxQueuedJobs,
    this.dailyLimit,
    this.monthlyLimit,
  });

  final UsagePolicy policy;

  /// Null means unlimited.
  final int? dailyLimit;
  final int dailyUsed;
  final DateTime dailyResetAt;

  /// Null means unlimited.
  final int? monthlyLimit;
  final int monthlyUsed;
  final DateTime monthlyResetAt;

  /// The user's jobs that are queued or running.
  final int queuedJobs;
  final int maxQueuedJobs;

  /// Analyses left today; null when there is no daily limit.
  int? get dailyRemaining => _remaining(dailyLimit, dailyUsed);

  /// Analyses left this month; null when there is no monthly limit.
  int? get monthlyRemaining => _remaining(monthlyLimit, monthlyUsed);

  /// Whether another request would be refused for quota or queue reasons.
  /// Advisory: the server decides.
  bool get canRequest =>
      (dailyRemaining ?? 1) > 0 &&
      (monthlyRemaining ?? 1) > 0 &&
      queuedJobs < maxQueuedJobs;

  static int? _remaining(int? limit, int used) =>
      limit == null ? null : (limit - used).clamp(0, limit);
}
