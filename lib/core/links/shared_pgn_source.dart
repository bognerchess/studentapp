// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The hand-off from the share extension (`ios/ShareExtension`). The
/// extension writes `shared.pgn` into the App Group container and tries to
/// open `com.bognerchess.mobile://shared-pgn`; the app collects the file
/// through this interface when that link arrives, when it starts and whenever
/// it comes to the foreground (iOS does not promise that an extension may
/// open its app, so the link is a shortcut and not the mechanism).
// ignore: one_member_abstracts
abstract interface class SharedPgnSource {
  /// The bytes of the waiting PGN, or null when there is none. The
  /// implementation removes the file, so a PGN is delivered once. It enforces
  /// the size limit itself as well (the caller checks again).
  Future<Uint8List?> take();
}

/// Nothing ever waits. For platforms without the share extension and for
/// tests.
class NoSharedPgnSource implements SharedPgnSource {
  const NoSharedPgnSource();

  @override
  Future<Uint8List?> take() async => null;
}

/// The method channel served by `ios/Runner/SharedPgnInbox.swift`.
///
/// `take` answers with the bytes of `shared.pgn` in the App Group container
/// or with null, and the file is gone afterwards in both cases. Dart passes
/// no argument: there is no path or name it could choose. The native side
/// stops reading one byte after the size limit, so a file that is too large
/// arrives as exactly that many bytes and the caller's own size check refuses
/// it with the usual message.
class PlatformSharedPgnSource implements SharedPgnSource {
  const PlatformSharedPgnSource();

  static const String channelName = 'com.bognerchess.mobile/shared_pgn';
  static const String takeMethod = 'take';
  static const MethodChannel _channel = MethodChannel(channelName);
  static const _log = Log('links.shared');

  @override
  Future<Uint8List?> take() async {
    try {
      return await _channel.invokeMethod<Uint8List>(takeMethod);
    } on MissingPluginException {
      // No native side: a platform without the extension, or a widget test.
      return null;
    } on PlatformException catch (error) {
      // The code only ("noContainer": the App Group is missing from the
      // signature). Never a path.
      _log.warning('shared PGN not available: ${error.code}');
      return null;
    }
  }
}

final sharedPgnSourceProvider = Provider<SharedPgnSource>(
  (ref) => const PlatformSharedPgnSource(),
);
