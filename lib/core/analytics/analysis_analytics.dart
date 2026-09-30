// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/api/models/stage_models.dart';

/// The staged analysis pipeline's events, in one place.
///
/// Three callers start a stage (the game screen, its coach button and the
/// submit queue) and the tracker starts the rest; keeping the property names
/// and the `analysis_requested` rule here is what stops the four from
/// drifting apart. `docs/analytics-events.md` is the catalogue.
extension AnalysisStageAnalytics on Analytics {
  /// The server accepted a stage command. [source] is what asked for it:
  /// `game_detail`, `game_detail_coach`, `submit_queue` or `chain`.
  ///
  /// An accepted base evaluation is also `analysis_requested`, the PRD's
  /// "time to first analysis" clock: on the staged pipeline that first stage
  /// *is* the analysis being asked for, and only one place should decide that.
  void stageStarted(AnalysisStage stage, {required String source}) {
    track(AnalyticsEvents.analysisStageStarted, {
      'stage': ?_wire(stage),
      'source': source,
    });
    if (stage == AnalysisStage.baseEvaluation) {
      track(AnalyticsEvents.analysisRequested, {'source': source});
    }
  }

  /// A stage is stored. [took] is from the request to the finish, which is
  /// what the user waited.
  void stageReady(AnalysisStage stage, {Duration? took}) {
    track(AnalyticsEvents.analysisStageReady, {
      'stage': ?_wire(stage),
      'duration_s': ?took?.inSeconds,
    });
  }

  /// A stage stopped. [code] is the server's failure code, which is an
  /// enum-like string and never a message.
  void stageFailed(AnalysisStage stage, {String? code}) {
    track(AnalyticsEvents.analysisStageFailed, {
      'stage': ?_wire(stage),
      'code': ?code,
    });
  }

  /// The metered stage was asked for and accepted. [language] is the coach
  /// language the server was given.
  void coachRequested(String language) {
    track(AnalyticsEvents.coachRequested, {'language': language});
  }
}

/// The stage as a property value: the wire name in lower case
/// (`base_evaluation`). Null for a stage this build does not know, which the
/// caller then leaves out — `props_sanitizer` would drop it anyway.
String? _wire(AnalysisStage stage) => stage.wire?.toLowerCase();
