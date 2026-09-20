// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_error.dart';
import 'package:flutter/foundation.dart';

/// One member of a mutation's `errors` union, read from its JSON form.
///
/// Every mutation has its own generated union class, but the members are the
/// same few types everywhere. Reading them from `toJson()` of the generated
/// object keeps the mapping in one place, and a member this build does not
/// know (it arrives with nothing but `__typename`) needs no special case.
@immutable
class MutationError {
  const MutationError._(this.typename, this._fields);

  factory MutationError.fromJson(Map<String, dynamic> json) => MutationError._(
    json['__typename'] is String ? json['__typename'] as String : 'Unknown',
    json,
  );

  /// The first error of a payload, or null when there is none. The server
  /// reports one error per mutation; should there be more, the first one
  /// decides.
  static MutationError? firstOf(Iterable<Map<String, dynamic>>? errors) {
    if (errors == null || errors.isEmpty) {
      return null;
    }
    return MutationError.fromJson(errors.first);
  }

  final String typename;
  final Map<String, dynamic> _fields;

  /// The server's message key, e.g. `web_api_errors.entity_not_found`.
  String? get message => string('message');

  String? string(String field) =>
      _fields[field] is String ? _fields[field] as String : null;

  int? integer(String field) =>
      _fields[field] is int ? _fields[field] as int : null;

  /// A `DateTime` scalar, as UTC.
  DateTime? instant(String field) {
    final value = _fields[field];
    return switch (value) {
      final DateTime value => value.toUtc(),
      final String value => DateTime.tryParse(value)?.toUtc(),
      _ => null,
    };
  }

  /// `retryAfterSeconds` of a `RateLimitedError`; a minute when it is missing.
  Duration get retryAfter =>
      Duration(seconds: (integer('retryAfterSeconds') ?? 60).clamp(0, 86400));

  /// The generic failure for an error without a typed outcome.
  ApiRejected toRejected() => ApiRejected(
    typename: typename,
    messageKey: message,
    propertyName: string('propertyName'),
    retryAfter: typename == 'RateLimitedError' ? retryAfter : null,
  );
}

/// For a payload that has neither its entity nor an error, where the schema
/// promises one of the two.
ApiServerError emptyPayload(String operationName) =>
    ApiServerError(detail: 'empty payload of $operationName');
