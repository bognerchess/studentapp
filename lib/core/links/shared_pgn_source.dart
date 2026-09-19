// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The hand-off from the share extension. The extension writes `shared.pgn`
/// into the App Group container and opens
/// `com.bognerchess.mobile://shared-pgn`; the app then collects the file
/// through this interface.
// ignore: one_member_abstracts
abstract interface class SharedPgnSource {
  /// The bytes of the waiting PGN, or null when there is none. The
  /// implementation removes the file, so a PGN is delivered once. It enforces
  /// the size limit itself as well (the caller checks again).
  Future<Uint8List?> take();
}

/// TODO(WP-24): replace with an implementation that reads and deletes
/// `shared.pgn` in the App Group container (a method channel next to
/// `IncomingLinkHandler.swift`; Dart has no API for
/// `containerURL(forSecurityApplicationGroupIdentifier:)`). Until the share
/// extension exists there is no App Group and nothing to read, so the link is
/// accepted and does nothing.
class NoSharedPgnSource implements SharedPgnSource {
  const NoSharedPgnSource();

  @override
  Future<Uint8List?> take() async => null;
}

final sharedPgnSourceProvider = Provider<SharedPgnSource>(
  (ref) => const NoSharedPgnSource(),
);
