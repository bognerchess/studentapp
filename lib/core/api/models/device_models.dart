// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';

/// Which APNs gateway a device token belongs to.
enum ApnsEnvironment { sandbox, production }

/// This installation as the server knows it.
@immutable
class RegisteredDevice {
  const RegisteredDevice({
    required this.id,
    required this.deviceId,
    required this.lastSeenAt,
    this.revokedAt,
  });

  final String id;

  /// The installation id the app generated.
  final String deviceId;
  final DateTime lastSeenAt;

  /// Set once the device was unregistered.
  final DateTime? revokedAt;
}

/// One product-analytics event. No personal data in [props].
@immutable
class AnalyticsEvent {
  const AnalyticsEvent({
    required this.name,
    required this.occurredAt,
    this.props,
  });

  /// One of the names in `docs/analytics-events.md`; the server drops others.
  final String name;
  final DateTime occurredAt;

  /// A flat JSON object of at most 2 KB.
  final Map<String, Object?>? props;
}

/// The server's count for one batch. Rejected events are dropped for good:
/// never send them again.
@immutable
class EventBatchResult {
  const EventBatchResult({required this.accepted, required this.rejected});

  final int accepted;
  final int rejected;
}
