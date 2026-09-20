// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/api/legal_api.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _log = Log('consent');

/// The user's answer to "may the app send usage statistics and crash
/// reports?".
///
/// **Contract for the analytics and the crash-reporting packages**
///
/// - Record, queue or send something only while
///   `ref.read(analyticsConsentProvider) == AnalyticsConsent.granted`.
///   [unknown] and [denied] both mean "no": the default is off (opt-in), and
///   it stays off until the user has said yes on this account.
/// - The value is [unknown] while nobody is signed in and for a moment after
///   a start (until the stored answer has been read). Events of that moment
///   are lost on purpose.
/// - `ref.listen(analyticsConsentProvider, ...)`: on a change away from
///   [granted], drop what is queued (`EventOutboxDao.clear()`) and close the
///   crash reporter; on a change to [granted], start.
/// - Crash reports ride on the same switch. The settings screen labels it
///   "Usage statistics and crash reports", and the consent text of the
///   backend (`ANALYTICS_CONSENT`) has to cover both. Reason: both are
///   optional diagnostics that leave the device, neither is needed for the
///   service, and two switches would ask the same question twice. If legal
///   review wants them apart, add a second provider next to this one; the
///   storage key below is already specific to analytics.
enum AnalyticsConsent {
  /// Not asked yet, not loaded yet, or nobody is signed in. Treat as "no".
  unknown,
  granted,
  denied,
}

/// See [AnalyticsConsent] for the contract.
///
/// The answer belongs to the account, not to the device: it is stored in the
/// owner-scoped key-value table (a sign-out removes it), and recorded on the
/// server with the version of the `ANALYTICS_CONSENT` text. After a sign-in
/// on a device without a stored answer, the server's record is taken over, so
/// nobody is asked twice.
final analyticsConsentProvider =
    NotifierProvider<AnalyticsConsentNotifier, AnalyticsConsent>(
      AnalyticsConsentNotifier.new,
    );

class AnalyticsConsentNotifier extends Notifier<AnalyticsConsent> {
  /// Owner-scoped keys of the `kv` table.
  static const String answerKey = 'consent.analytics';
  static const String pendingKey = 'consent.analytics.pending';
  static const String promptedKey = 'consent.analytics.prompted';

  String? _sub;
  bool _storageWorks = false;
  Future<void> _loaded = Future<void>.value();

  /// Completes when the stored answer (or the server's) has been read.
  Future<void> get loaded => _loaded;

  @override
  AnalyticsConsent build() {
    final auth = ref.watch(authStateProvider);
    _storageWorks = false;
    if (auth is! SignedIn) {
      _sub = null;
      _loaded = Future<void>.value();
      return AnalyticsConsent.unknown;
    }
    _sub = auth.sub;
    _loaded = _load(auth.sub);
    return AnalyticsConsent.unknown;
  }

  Future<void> _load(String sub) async {
    String? stored;
    try {
      final kv = ref.read(appDatabaseProvider).kvDao;
      stored = await kv.get(answerKey, ownerSub: sub);
      _storageWorks = true;
    } on Object catch (error) {
      // Without storage the answer is "no" and nobody is prompted.
      _log.warning('could not read the analytics consent: $error');
      return;
    }
    if (!_isCurrent(sub)) return;
    final answer = _parse(stored);
    if (answer != AnalyticsConsent.unknown) {
      state = answer;
      await syncPending();
      return;
    }
    await _adoptServerRecord(sub);
  }

  /// A new device, or the first start after a sign-out: what did this person
  /// say elsewhere?
  Future<void> _adoptServerRecord(String sub) async {
    final ConsentStatus status;
    try {
      status = await ref
          .read(legalApiProvider)
          .consent(LegalDocumentKey.analyticsConsent);
    } on ApiError catch (error) {
      _log.debug('analytics consent not known to the server yet: $error');
      return;
    }
    if (!_isCurrent(sub) || state != AnalyticsConsent.unknown) return;
    final AnalyticsConsent answer;
    if (status.currentVersion > 0 &&
        status.acceptedVersion == status.currentVersion) {
      answer = AnalyticsConsent.granted;
    } else if (status.withdrawnAt != null) {
      answer = AnalyticsConsent.denied;
    } else {
      // Never answered, or the text changed since: ask (again).
      return;
    }
    state = answer;
    await _store(sub, answerKey, answer.name);
  }

  /// The user's choice, from the first-run prompt or from the settings.
  /// [shownVersion] is the version of the consent text the user saw, when
  /// one was on screen. Never throws; the local answer counts at once, and
  /// the server record is retried on the next start when it fails now.
  Future<void> set({required bool granted, int? shownVersion}) async {
    final sub = _sub;
    if (sub == null) return;
    final next = granted ? AnalyticsConsent.granted : AnalyticsConsent.denied;
    final changed = state != next;
    state = next;
    if (changed) {
      // After the change: with "no" the gate in front of the outbox drops
      // this event too, which is what the user asked for.
      ref.read(analyticsProvider).track(
        AnalyticsEvents.consentAnalyticsChanged,
        {'granted': granted},
      );
    }
    await _store(sub, answerKey, next.name);
    await _store(sub, promptedKey, '1');
    await _store(
      sub,
      pendingKey,
      shownVersion == null ? next.name : '${next.name}:$shownVersion',
    );
    await syncPending();
  }

  /// Whether the first-run prompt should open now. True at most once per
  /// account and device: asking marks the prompt as shown. False while the
  /// answer is known, while nobody is signed in, and when the flag cannot be
  /// stored (better never than on every start).
  Future<bool> takeFirstRunPrompt() async {
    await _loaded;
    final sub = _sub;
    if (sub == null || !_storageWorks || state != AnalyticsConsent.unknown) {
      return false;
    }
    try {
      final kv = ref.read(appDatabaseProvider).kvDao;
      if (await kv.get(promptedKey, ownerSub: sub) != null) return false;
      await kv.set(promptedKey, '1', ownerSub: sub);
    } on Object catch (error) {
      _log.warning('could not store the prompt flag: $error');
      return false;
    }
    return _isCurrent(sub) && state == AnalyticsConsent.unknown;
  }

  /// Sends an answer the server has not got yet. Called after every change
  /// and once per start; safe to call at any time.
  Future<void> syncPending() async {
    final sub = _sub;
    if (sub == null) return;
    try {
      final kv = ref.read(appDatabaseProvider).kvDao;
      final pending = await kv.get(pendingKey, ownerSub: sub);
      if (pending == null) return;
      final parts = pending.split(':');
      final accepted = parts.first == AnalyticsConsent.granted.name;
      final legal = ref.read(legalApiProvider);
      var version = parts.length > 1 ? int.tryParse(parts[1]) : null;
      version ??= (await legal.consent(LegalDocumentKey.analyticsConsent))
          .currentVersion;
      if (version <= 0) {
        // No text is published, so there is nothing to record against.
        return;
      }
      await legal.recordConsent(
        key: LegalDocumentKey.analyticsConsent,
        version: version,
        accepted: accepted,
      );
      // Only when the answer did not change while the request was under way.
      if (await kv.get(pendingKey, ownerSub: sub) == pending) {
        await kv.remove(pendingKey, ownerSub: sub);
      }
    } on ApiError catch (error) {
      if (error is ApiRejected) {
        // The server will not take this record (an unpublished version, for
        // example). Asking again with the same data cannot help.
        _log.warning('analytics consent record rejected: $error');
        await _remove(sub, pendingKey);
      } else {
        _log.info('analytics consent not recorded yet, will retry: $error');
      }
    } on Object catch (error) {
      _log.warning('analytics consent sync failed: $error');
    }
  }

  bool _isCurrent(String sub) => ref.mounted && _sub == sub;

  Future<void> _store(String sub, String key, String value) async {
    try {
      await ref.read(appDatabaseProvider).kvDao.set(key, value, ownerSub: sub);
    } on Object catch (error) {
      _log.warning('could not store $key: $error');
    }
  }

  Future<void> _remove(String sub, String key) async {
    try {
      await ref.read(appDatabaseProvider).kvDao.remove(key, ownerSub: sub);
    } on Object catch (error) {
      _log.warning('could not remove $key: $error');
    }
  }

  static AnalyticsConsent _parse(String? stored) => switch (stored) {
    'granted' => AnalyticsConsent.granted,
    'denied' => AnalyticsConsent.denied,
    _ => AnalyticsConsent.unknown,
  };
}

/// Whether the AI consent text still has to be accepted: `value.required` is
/// true until the user accepted `value.currentVersion`, so a new version of
/// the text asks again. Analysis requests are refused by the server while it
/// is true; whoever submits a game opens `AppRoutes.consentAi` first
/// (`final agreed = await context.push<bool>(AppRoutes.consentAi)`).
///
/// An error state means "could not ask" (offline); the submit flow may then
/// simply try the request, the server answers `AnalysisAiConsentRequired`.
final aiConsentStatusProvider =
    AsyncNotifierProvider<AiConsentStatusNotifier, ConsentStatus>(
      AiConsentStatusNotifier.new,
      // No silent retries: the screens that need it have a retry button, and
      // the submit flow may go ahead without it (see above).
      retry: (_, _) => null,
    );

class AiConsentStatusNotifier extends AsyncNotifier<ConsentStatus> {
  @override
  Future<ConsentStatus> build() {
    // Per account: a change of user asks the server again.
    ref.watch(authStateProvider);
    return ref.watch(legalApiProvider).aiConsent();
  }

  /// Records the acceptance of [version] (the version of the text that was
  /// on screen). Throws an `ApiError`: consent cannot be given offline,
  /// because the server has to know before it sends a game to the provider.
  Future<ConsentStatus> accept(int version) async {
    final status = await ref
        .read(legalApiProvider)
        .recordAiConsent(version: version);
    if (ref.mounted) {
      state = AsyncData(status);
    }
    ref.read(analyticsProvider).track(AnalyticsEvents.consentAiAccepted, {
      'version': version,
    });
    return status;
  }

  /// Withdraws the consent (as easy as giving it, GDPR article 7(3)): the
  /// server refuses new analyses until the user agrees again. Existing
  /// analyses stay. Throws an `ApiError`.
  Future<void> withdraw(int version) async {
    final legal = ref.read(legalApiProvider);
    await legal.recordConsent(
      key: LegalDocumentKey.aiConsent,
      version: version,
      accepted: false,
    );
    final status = await legal.aiConsent();
    if (ref.mounted) {
      state = AsyncData(status);
    }
  }
}
