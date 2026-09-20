// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/generated/operations/devices.graphql.dart';
import 'package:bogner_chess/core/api/generated/schema.graphql.dart';
import 'package:bogner_chess/core/api/mappers/mutation_error.dart';
import 'package:bogner_chess/core/api/models/device_models.dart';

export 'package:bogner_chess/core/api/api_error.dart';
export 'package:bogner_chess/core/api/models/device_models.dart'
    show AnalyticsEvent, EventBatchResult;

/// First-party product analytics.
class EventsApi {
  EventsApi(this._executor);

  final ApiExecutor _executor;

  /// The server refuses a call with more events.
  static const int maxBatchSize = 50;

  /// Sends one batch of at most [maxBatchSize] events (an [ArgumentError]
  /// otherwise; an empty batch is answered without a request).
  ///
  /// Events counted as rejected are dropped for good: remove the whole batch
  /// from the outbox after a result. Throws an `ApiError`; keep the batch
  /// when it is retryable.
  Future<EventBatchResult> track({
    required String deviceId,
    required String sessionId,
    required List<AnalyticsEvent> events,
    String? appVersion,
  }) async {
    if (events.length > maxBatchSize) {
      throw ArgumentError.value(
        events.length,
        'events',
        'at most $maxBatchSize events per call',
      );
    }
    if (events.isEmpty) {
      return const EventBatchResult(accepted: 0, rejected: 0);
    }
    final data = await _executor.mutate(
      document: documentNodeMutationTrackMobileEvents,
      operationName: 'TrackMobileEvents',
      variables: Variables$Mutation$TrackMobileEvents(
        input: Input$TrackMobileEventsInput(
          deviceId: deviceId,
          sessionId: sessionId,
          appVersion: appVersion,
          events: [
            for (final event in events)
              Input$MobileEventInput(
                name: event.name,
                occurredAt: event.occurredAt,
                props: event.props,
              ),
          ],
        ),
      ).toJson(),
      parse: Mutation$TrackMobileEvents.fromJson,
    );
    final payload = data.trackMobileEvents;
    final error = MutationError.firstOf(payload.errors?.map((e) => e.toJson()));
    if (error != null) {
      throw error.toRejected();
    }
    final batch = payload.eventBatch;
    if (batch == null) {
      throw emptyPayload('TrackMobileEvents');
    }
    return EventBatchResult(accepted: batch.accepted, rejected: batch.rejected);
  }
}
