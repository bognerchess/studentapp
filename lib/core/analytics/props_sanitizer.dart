// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// At most this many properties per event; the rest is dropped.
const int kMaxEventProps = 12;

/// A string value longer than this is dropped, not cut.
const int kMaxEventPropStringLength = 40;

final RegExp _keyPattern = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
final RegExp _valuePattern = RegExp(r'^[a-z0-9_\-\.]+$');

/// What may leave the device as event properties: numbers, booleans and
/// short enum-like strings (`after_first_submit`, `pgn_paste`, `1.2.0`).
///
/// This is the last line of defence against free text in analytics, such as
/// a player name, a move list or an error message that a caller put into the
/// properties by mistake. Anything that does not fit is **dropped**, never
/// cut or escaped: a cut name is still part of a name. Upper-case letters and
/// spaces are reason enough to drop a value, which keeps full names, sentences
/// and move lists out by construction. A single lower-case word still passes,
/// so callers remain bound by the rule in `docs/analytics-events.md`.
///
/// With [kMaxEventProps] properties of at most 40 + 40 characters the result
/// always fits the server's 2 KB limit.
Map<String, Object> sanitizeEventProps(Map<String, Object?> props) {
  final result = <String, Object>{};
  for (final MapEntry(:key, :value) in props.entries) {
    if (result.length >= kMaxEventProps) {
      break;
    }
    if (!_keyPattern.hasMatch(key)) {
      continue;
    }
    switch (value) {
      case bool():
        result[key] = value;
      case int():
        result[key] = value;
      case double() when value.isFinite:
        result[key] = value;
      case String()
          when value.length <= kMaxEventPropStringLength &&
              _valuePattern.hasMatch(value):
        result[key] = value;
      default:
      // null, NaN, long or free text, lists, maps, objects: dropped.
    }
  }
  return result;
}
