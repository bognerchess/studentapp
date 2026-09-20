// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/generated/operations/config.graphql.dart';
import 'package:bogner_chess/core/api/models/config_models.dart';

export 'package:bogner_chess/core/api/api_error.dart';
export 'package:bogner_chess/core/api/models/config_models.dart';

/// Remote configuration.
class ConfigApi {
  ConfigApi(this._executor);

  final ApiExecutor _executor;

  /// Throws an `ApiError`.
  Future<MobileConfig> mobileConfig() async {
    final data = await _executor.query(
      document: documentNodeQueryMobileConfig,
      operationName: 'MobileConfig',
      parse: Query$MobileConfig.fromJson,
    );
    final config = data.mobileConfig;
    return MobileConfig(
      minSupportedAppVersion: config.minSupportedAppVersion,
      maxAnalysisSchemaVersion: config.maxAnalysisSchemaVersion,
      supportedCoachLanguages: List.unmodifiable(
        config.supportedCoachLanguages.map((code) => code.toLowerCase()),
      ),
      // A nonsensical value must not turn the poller into a busy loop.
      jobPollInterval: Duration(
        seconds: config.jobPollIntervalSeconds.clamp(1, 300),
      ),
      featureFlags: Map.unmodifiable({
        for (final flag in config.featureFlags) flag.key: flag.enabled,
      }),
      currentAiConsentVersion: config.currentAiConsentVersion,
    );
  }
}
