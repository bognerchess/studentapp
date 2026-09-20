// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// Converters for the custom scalars of the schema, named in `build.yaml` and
/// called by the generated code.
library;

import 'package:bogner_chess/core/game/game_date.dart';

/// `DateTime` scalar: an ISO 8601 instant with an offset. Always UTC on this
/// side; the UI converts to local time when it formats.
///
/// Throws a [FormatException] for anything else, which the executor reports as
/// a malformed response.
DateTime dateTimeFromJson(Object? value) {
  if (value is! String) {
    throw FormatException('DateTime scalar is not a string: $value');
  }
  return DateTime.parse(value).toUtc();
}

String dateTimeToJson(DateTime value) => value.toUtc().toIso8601String();

/// `LocalDate` scalar ("2026-09-19"). The generated code keeps it as a
/// string; a value that is not a calendar date reads as "not known".
GameDate? localDateFromJson(String? value) => GameDate.tryParseIso(value);

String? localDateToJson(GameDate? value) => value?.toIso();
