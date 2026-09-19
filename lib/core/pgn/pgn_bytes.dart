// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

/// Turns the bytes of a PGN file into text.
///
/// PGN is ASCII by its standard, UTF-8 in every current export, and Latin-1
/// in files from older database programs, where it shows in names such as
/// "Müller". So: UTF-16 when there is a byte order mark for it, UTF-8 when
/// the bytes are valid UTF-8, and Latin-1 otherwise, which cannot fail.
String decodePgnBytes(List<int> bytes) {
  if (bytes.length >= 2) {
    final (a, b) = (bytes[0], bytes[1]);
    if (a == 0xFF && b == 0xFE) return _utf16(bytes, littleEndian: true);
    if (a == 0xFE && b == 0xFF) return _utf16(bytes, littleEndian: false);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

String _utf16(List<int> bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 2; i + 1 < bytes.length; i += 2) {
    final (first, second) = (bytes[i], bytes[i + 1]);
    units.add(littleEndian ? first | second << 8 : first << 8 | second);
  }
  return String.fromCharCodes(units);
}
