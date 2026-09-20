// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/links/incoming_link.dart';
import 'package:bogner_chess/core/links/incoming_link_notices.dart';
import 'package:bogner_chess/core/links/link_target.dart';
import 'package:bogner_chess/core/links/shared_pgn_source.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/pgn/pgn_bytes.dart';
import 'package:bogner_chess/core/pgn/pgn_import.dart';
import 'package:bogner_chess/features/import/domain/pending_import.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The largest document the app takes in, in bytes. The native reader has the
/// same limit and stops reading there; this is the second check.
const int kIncomingFileMaxBytes = kPgnMaxChars;

final incomingLinkServiceProvider = Provider<IncomingLinkService>((ref) {
  final service = IncomingLinkService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Turns what arrives from outside the app into navigation.
///
/// * A document ("Open in Bogner Chess" for a `.pgn` file) is decoded, offered
///   to the import screen and the import screen is opened.
/// * A link of the app's scheme is normalised through the mapping table in
///   `link_target.dart` and opened.
/// * The OIDC redirect is ignored; the auth plugin consumes it natively.
/// * `…://shared-pgn` collects the PGN the share extension left behind. So do
///   [start] and every return to the foreground, because iOS does not promise
///   that a share extension may open its app: when it may not, the extension
///   tells the user to open the app, and the PGN must be found without a link.
///
/// Signed out, nothing special happens here: the router sends every location
/// to the sign-in screen with `from=<location>` and continues there after
/// signing in, and the pending PGN waits in `pendingImportProvider` until the
/// import screen takes it.
///
/// `main.dart` calls [start] once, before the first frame. `GoRouter.go`
/// works before the router's widgets exist, so a cold start needs no special
/// path.
class IncomingLinkService {
  IncomingLinkService(this._ref);

  final Ref _ref;
  StreamSubscription<IncomingLink>? _subscription;
  AppLifecycleListener? _lifecycle;

  static const _log = Log('links');

  void start() {
    if (_subscription != null) return;
    _subscription = _ref
        .read(incomingLinkSourceProvider)
        .links
        .listen(
          (link) => unawaited(handle(link)),
          onError: (Object error, StackTrace stack) {
            // The app works without incoming links; the stream stays open.
            _log.warning('link stream failed: ${error.runtimeType}');
          },
        );
    // A PGN shared while the app was not running, or while it was in the
    // background. When the extension's link arrives as well, the second
    // `take` finds nothing: the native side removes the file with the read.
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(collectSharedPgn()),
    );
    unawaited(collectSharedPgn());
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// Imports the PGN the share extension left in the App Group container, if
  /// there is one. Returns whether there was. Never throws.
  Future<bool> collectSharedPgn() async {
    try {
      final bytes = await _ref.read(sharedPgnSourceProvider).take();
      if (bytes == null || _subscription == null) return false;
      _importBytes(bytes);
      return true;
    } on Object catch (error, stack) {
      _log.error(
        'could not collect a shared PGN',
        error: error.runtimeType,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Handles one link. Never throws.
  @visibleForTesting
  Future<void> handle(IncomingLink link) async {
    try {
      switch (link) {
        case IncomingUrl(:final url):
          await _handleTarget(classifyLink(url));
        case IncomingFile(:final bytes):
          _importBytes(bytes);
        case IncomingFileFailure(:final reason):
          _notify(switch (reason) {
            IncomingFileFailureReason.tooLarge =>
              IncomingLinkNotice.fileTooLarge,
            IncomingFileFailureReason.unreadable =>
              IncomingLinkNotice.fileUnreadable,
          });
      }
    } on Object catch (error, stack) {
      // Input from outside must not be able to take the app down. No content
      // and no URL in the log.
      _log.error(
        'could not handle an incoming link',
        error: error.runtimeType,
        stackTrace: stack,
      );
    }
  }

  /// Opens [location] if the mapping table allows it, exactly as a link from
  /// outside would. For callers inside the app that get a location from
  /// somewhere they do not control, such as a push payload (WP-32). Returns
  /// whether it navigated.
  bool openLocation(String location) {
    final target = classifyLink(location);
    if (target is! AppLocationTarget) {
      _log.info('refused a location: $target');
      return false;
    }
    _ref.read(routerProvider).go(target.location);
    return true;
  }

  Future<void> _handleTarget(LinkTarget target) async {
    switch (target) {
      case AppLocationTarget(:final location):
        // Only the route pattern, not the id.
        _log.info('opening a link');
        _ref.read(routerProvider).go(location);
      case SharedPgnTarget():
        if (!await collectSharedPgn()) {
          // Usual: the foreground check was quicker than the link.
          _log.info('shared-pgn link without a waiting PGN');
        }
      case IgnoredTarget(:final reason):
        if (reason != IgnoredLinkReason.oauthRedirect) {
          _log.info('ignored a link: ${reason.name}');
        }
    }
  }

  void _importBytes(Uint8List bytes) {
    if (bytes.length > kIncomingFileMaxBytes) {
      _notify(IncomingLinkNotice.fileTooLarge);
      return;
    }
    if (bytes.isEmpty || !_looksLikeText(bytes)) {
      _notify(IncomingLinkNotice.fileUnreadable);
      return;
    }
    final text = decodePgnBytes(bytes);
    _log.info('document received (${bytes.length} bytes)');
    // Whether it is a legal game is for the import screen to say: it shows
    // what is wrong and where, which a message from here could not.
    _ref.read(pendingImportProvider.notifier).offer(text);
    _ref.read(routerProvider).go(AppRoutes.newGameImport);
  }

  void _notify(IncomingLinkNotice notice) {
    _log.info('document refused: ${notice.name}');
    _ref.read(incomingLinkNoticeProvider.notifier).post(notice);
  }

  /// A PGN is text. A NUL byte says binary (an image or an archive with a
  /// `.pgn` name), unless the file is UTF-16, which `decodePgnBytes` detects
  /// by its byte order mark.
  static bool _looksLikeText(Uint8List bytes) {
    if (bytes.length >= 2) {
      final (a, b) = (bytes[0], bytes[1]);
      if ((a == 0xFF && b == 0xFE) || (a == 0xFE && b == 0xFF)) return true;
    }
    return !bytes.contains(0);
  }
}
