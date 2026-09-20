// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/push/push_platform.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter/foundation.dart';

/// The moment the app asks at. There is one in the MVP: right after the first
/// analysis was requested, when "tell me when it is ready" is a wish the user
/// actually has. Never at the first start.
enum PushAskReason {
  afterFirstSubmit('after_first_submit');

  const PushAskReason(this.wireName);

  /// The value of the `reason` property of `push_permission_result`.
  final String wireName;
}

/// What [decidePushAsk] says.
enum PushAskDecision {
  /// Show the explainer, then the system prompt.
  ask,

  /// Nothing to ask: notifications are allowed.
  alreadyAuthorized,

  /// The user said no to iOS. The system prompt cannot be shown again; the
  /// settings screen offers the way into the Settings app instead.
  denied,

  /// The user said "Not now" to the explainer a short while ago, or twice.
  notNow,
}

/// What [maybeAskForPermission] did.
enum PushAskOutcome { granted, denied, notNow, notAsked }

/// What the app remembers about asking, per installation (`KvDao` without an
/// owner: the permission belongs to the device, not to an account).
@immutable
class PushAskRecord {
  const PushAskRecord({
    this.systemAnswer,
    this.notNowCount = 0,
    this.lastNotNowAt,
  });

  /// `granted` or `denied` once the system prompt was answered.
  final String? systemAnswer;

  /// How often the explainer was closed with "Not now".
  final int notNowCount;
  final DateTime? lastNotNowAt;
}

/// "Not now" is not "never": the explainer may come back once, after
/// [kPushAskAgainAfter], at the next occasion. A second "Not now" is final.
const Duration kPushAskAgainAfter = Duration(days: 14);
const int kPushMaxNotNow = 2;

/// The whole permission policy. Pure.
PushAskDecision decidePushAsk({
  required PushPermissionStatus status,
  required PushAskRecord record,
  required DateTime now,
}) {
  switch (status) {
    case PushPermissionStatus.authorized:
      return PushAskDecision.alreadyAuthorized;
    case PushPermissionStatus.denied:
      return PushAskDecision.denied;
    case PushPermissionStatus.notDetermined:
      // Should iOS ever report "not determined" after an answer (a restored
      // backup): its prompt decides, ours stays out of the way.
      if (record.systemAnswer == 'denied') {
        return PushAskDecision.denied;
      }
      if (record.notNowCount >= kPushMaxNotNow) {
        return PushAskDecision.notNow;
      }
      final last = record.lastNotNowAt;
      if (last != null && now.difference(last) < kPushAskAgainAfter) {
        return PushAskDecision.notNow;
      }
      return PushAskDecision.ask;
  }
}

/// [PushAskRecord] in the key-value table.
class PushAskStore {
  PushAskStore(this._kv);

  final KvDao _kv;

  static const _systemAnswerKey = 'push.system_answer';
  static const _notNowCountKey = 'push.not_now_count';
  static const _lastNotNowKey = 'push.last_not_now_at';

  Future<PushAskRecord> read() async {
    final count = await _kv.get(_notNowCountKey);
    final last = await _kv.get(_lastNotNowKey);
    return PushAskRecord(
      systemAnswer: await _kv.get(_systemAnswerKey),
      notNowCount: int.tryParse(count ?? '') ?? 0,
      lastNotNowAt: last == null ? null : DateTime.tryParse(last),
    );
  }

  Future<void> recordSystemAnswer({required bool granted}) =>
      _kv.set(_systemAnswerKey, granted ? 'granted' : 'denied');

  Future<void> recordNotNow(DateTime now) async {
    final record = await read();
    await _kv.set(_notNowCountKey, '${record.notNowCount + 1}');
    await _kv.set(_lastNotNowKey, now.toUtc().toIso8601String());
  }
}
