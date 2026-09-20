// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';

/// Why a call to the API did not produce a result. The one error type the API
/// layer lets out: queries throw it, mutations with typed outcomes carry it in
/// their `failed` case.
///
/// Domain outcomes (limit reached, consent required, invalid PGN, ...) are
/// *not* errors. They are cases of the sealed outcome types the repositories
/// return.
///
/// Messages are for logs. They never contain tokens or user content, and they
/// are never shown to the user: the UI picks a localised text by case.
@immutable
sealed class ApiError implements Exception {
  const ApiError();

  /// True when trying the same call again later can succeed without the user
  /// doing anything.
  bool get isRetryable;
}

/// Nobody is signed in, or the server refused the token even after one
/// refresh. No request was sent in the first case.
///
/// The API layer never signs out by itself: when the session really ended,
/// `AuthRepository` has already moved to `SignedOut` and the router follows.
final class ApiUnauthenticated extends ApiError {
  const ApiUnauthenticated();

  @override
  bool get isRetryable => false;

  @override
  bool operator ==(Object other) => other is ApiUnauthenticated;

  @override
  int get hashCode => 0x401;

  @override
  String toString() => 'ApiError.unauthenticated';
}

/// What went wrong below HTTP.
enum ApiNetworkCause {
  /// No connection, DNS failure, connection reset, TLS failure.
  offline,

  /// No answer within the time limit of the call.
  timeout,
}

/// The request did not get an answer. Retryable.
final class ApiNetworkError extends ApiError {
  const ApiNetworkError([this.cause = ApiNetworkCause.offline]);

  final ApiNetworkCause cause;

  @override
  bool get isRetryable => true;

  @override
  bool operator ==(Object other) =>
      other is ApiNetworkError && other.cause == cause;

  @override
  int get hashCode => Object.hash(ApiNetworkError, cause);

  @override
  String toString() => 'ApiError.network(${cause.name})';
}

/// The server answered, but not with a usable GraphQL response: an HTTP status
/// other than 2xx (and other than 401), a body that is not JSON, or data that
/// does not have the shape of the schema this build was generated from.
final class ApiServerError extends ApiError {
  const ApiServerError({this.statusCode, this.detail});

  /// The HTTP status; null when the status was fine and the body was not.
  final int? statusCode;

  /// A short technical description for logs.
  final String? detail;

  /// 5xx, 408 and 429 are worth another try; a malformed body is not.
  @override
  bool get isRetryable {
    final status = statusCode;
    return status != null && (status >= 500 || status == 408 || status == 429);
  }

  @override
  bool operator ==(Object other) =>
      other is ApiServerError &&
      other.statusCode == statusCode &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(ApiServerError, statusCode, detail);

  @override
  String toString() => 'ApiError.server($statusCode, $detail)';
}

/// The response carried top-level GraphQL `errors` (a validation error, a
/// resolver that threw, a cost limit).
final class ApiGraphQLError extends ApiError {
  const ApiGraphQLError(this.messages, {this.codes = const []});

  final List<String> messages;

  /// `extensions.code` of each error that has one.
  final List<String> codes;

  @override
  bool get isRetryable => false;

  @override
  bool operator ==(Object other) =>
      other is ApiGraphQLError &&
      listEquals(other.messages, messages) &&
      listEquals(other.codes, codes);

  @override
  int get hashCode =>
      Object.hash(ApiGraphQLError, Object.hashAll(messages), codes.length);

  @override
  String toString() => 'ApiError.graphql($messages, codes: $codes)';
}

/// A mutation was refused with an error that has no typed outcome of its own:
/// `BusinessError`, `InputValidationError`, `TechnicalError`, a
/// `RateLimitedError` on a mutation without a rate-limit outcome, or a union
/// member this build does not know yet.
final class ApiRejected extends ApiError {
  const ApiRejected({
    required this.typename,
    this.messageKey,
    this.propertyName,
    this.retryAfter,
  });

  /// The GraphQL type of the error, e.g. `BusinessError`.
  final String typename;

  /// The server's message key, e.g. `web_api_errors.entity_not_found`.
  final String? messageKey;

  /// The offending input property of an `InputValidationError`.
  final String? propertyName;

  /// Set for a `RateLimitedError`.
  final Duration? retryAfter;

  @override
  bool get isRetryable =>
      typename == 'TechnicalError' || typename == 'RateLimitedError';

  @override
  bool operator ==(Object other) =>
      other is ApiRejected &&
      other.typename == typename &&
      other.messageKey == messageKey &&
      other.propertyName == propertyName &&
      other.retryAfter == retryAfter;

  @override
  int get hashCode =>
      Object.hash(ApiRejected, typename, messageKey, propertyName, retryAfter);

  @override
  String toString() =>
      'ApiError.rejected($typename, $messageKey'
      '${propertyName == null ? '' : ', property: $propertyName'})';
}
