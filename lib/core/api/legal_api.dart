// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/generated/operations/fragments.graphql.dart';
import 'package:bogner_chess/core/api/generated/operations/legal.graphql.dart';
import 'package:bogner_chess/core/api/generated/schema.graphql.dart';
import 'package:bogner_chess/core/api/mappers/enum_mappers.dart';
import 'package:bogner_chess/core/api/mappers/mutation_error.dart';
import 'package:bogner_chess/core/api/models/legal_models.dart';

export 'package:bogner_chess/core/api/api_error.dart';
export 'package:bogner_chess/core/api/models/legal_models.dart';

/// Legal texts and the user's consents.
class LegalApi {
  LegalApi(this._executor);

  final ApiExecutor _executor;

  /// The current version of a legal text in [language] ("de"), or in English
  /// when that translation does not exist; null when nothing is published.
  /// Throws an `ApiError`.
  Future<LegalDocument?> document(
    LegalDocumentKey key, {
    String language = 'en',
  }) async {
    final data = await _executor.query(
      document: documentNodeQueryLegalDocument,
      operationName: 'LegalDocument',
      variables: Variables$Query$LegalDocument(
        key: legalDocumentKeyToWire(key),
        language: language.toLowerCase(),
      ).toJson(),
      parse: Query$LegalDocument.fromJson,
    );
    final document = data.legalDocument;
    if (document == null) {
      return null;
    }
    return LegalDocument(
      id: document.id,
      key: legalDocumentKeyOf(document.key),
      version: document.version,
      language: document.language,
      title: document.title,
      bodyMarkdown: document.bodyMarkdown,
      providerName: document.providerName,
      publishedAt: document.publishedAt,
      isDraft: document.isDraft,
    );
  }

  /// Whether the user still has to accept the AI consent text. Analysis
  /// requests are refused while `required` is true. Throws an `ApiError`.
  Future<ConsentStatus> aiConsent() async {
    final data = await _executor.query(
      document: documentNodeQueryMyAiConsent,
      operationName: 'MyAiConsent',
      parse: Query$MyAiConsent.fromJson,
    );
    return _aiStatusOf(data.myAiConsent);
  }

  /// The consent state for any legal text, e.g. analytics on a new device.
  /// Throws an `ApiError`.
  Future<ConsentStatus> consent(LegalDocumentKey key) async {
    final data = await _executor.query(
      document: documentNodeQueryMyConsent,
      operationName: 'MyConsent',
      variables: Variables$Query$MyConsent(key: legalDocumentKeyToWire(key))
          .toJson(),
      parse: Query$MyConsent.fromJson,
    );
    return _statusOf(data.myConsent);
  }

  /// Records that the user accepted the AI consent text in [version]
  /// (`ConsentStatus.currentVersion`). Throws an `ApiError`; a version that
  /// is not published is an `ApiRejected` for the property `Version`.
  Future<ConsentStatus> recordAiConsent({
    required int version,
    String? deviceId,
  }) async {
    final data = await _executor.mutate(
      document: documentNodeMutationRecordAiConsent,
      operationName: 'RecordAiConsent',
      variables: Variables$Mutation$RecordAiConsent(
        input: Input$RecordAiConsentInput(version: version, deviceId: deviceId),
      ).toJson(),
      parse: Mutation$RecordAiConsent.fromJson,
    );
    final payload = data.recordAiConsent;
    final error = MutationError.firstOf(payload.errors?.map((e) => e.toJson()));
    if (error != null) {
      throw error.toRejected();
    }
    final status = payload.aiConsentStatus;
    if (status == null) {
      throw emptyPayload('RecordAiConsent');
    }
    return _aiStatusOf(status);
  }

  /// Records an acceptance, or with [accepted] false a withdrawal or refusal,
  /// of the text the user was shown in [version]. Throws an `ApiError`.
  Future<ConsentStatus> recordConsent({
    required LegalDocumentKey key,
    required int version,
    required bool accepted,
    String? deviceId,
  }) async {
    final data = await _executor.mutate(
      document: documentNodeMutationRecordConsent,
      operationName: 'RecordConsent',
      variables: Variables$Mutation$RecordConsent(
        input: Input$RecordConsentInput(
          key: legalDocumentKeyToWire(key),
          version: version,
          accepted: accepted,
          deviceId: deviceId,
        ),
      ).toJson(),
      parse: Mutation$RecordConsent.fromJson,
    );
    final payload = data.recordConsent;
    final error = MutationError.firstOf(payload.errors?.map((e) => e.toJson()));
    if (error != null) {
      throw error.toRejected();
    }
    final status = payload.consentStatus;
    if (status == null) {
      throw emptyPayload('RecordConsent');
    }
    return _statusOf(status);
  }

  static ConsentStatus _aiStatusOf(Fragment$AiConsentFields status) =>
      ConsentStatus(
        key: LegalDocumentKey.aiConsent,
        currentVersion: status.currentVersion,
        acceptedVersion: status.acceptedVersion,
        required: status.required,
      );

  static ConsentStatus _statusOf(Fragment$ConsentFields status) =>
      ConsentStatus(
        key: legalDocumentKeyOf(status.key),
        currentVersion: status.currentVersion,
        acceptedVersion: status.acceptedVersion,
        required: status.required,
        withdrawnAt: status.withdrawnAt,
      );
}
