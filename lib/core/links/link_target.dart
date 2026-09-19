// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/router.dart';
import 'package:flutter/foundation.dart';

/// The app's custom URL scheme (Info.plist, `CFBundleURLSchemes`). One scheme
/// serves three callers: deep links into the app, the OIDC redirect, and the
/// hand-off from the share extension.
const String kAppLinkScheme = 'com.bognerchess.mobile';

/// First path segment (or host) of the OIDC redirect,
/// `com.bognerchess.mobile:/oauthredirect`. The auth plugin consumes that URL
/// natively; this layer must never act on it and never log it, because it
/// carries the authorisation code.
const String kOAuthRedirectSegment = 'oauthredirect';

/// Host of the share extension's hand-off URL,
/// `com.bognerchess.mobile://shared-pgn` (WP-24).
const String kSharedPgnHost = 'shared-pgn';

/// Longer URLs are refused unread. Every real link is far shorter.
const int kMaxLinkLength = 2048;

/// What an incoming URL means to the app.
@immutable
sealed class LinkTarget {
  const LinkTarget();
}

/// An in-app location, already normalised for `GoRouter.go`.
final class AppLocationTarget extends LinkTarget {
  const AppLocationTarget(this.location);

  final String location;

  @override
  bool operator ==(Object other) =>
      other is AppLocationTarget && other.location == location;

  @override
  int get hashCode => Object.hash(AppLocationTarget, location);

  @override
  String toString() => 'AppLocationTarget($location)';
}

/// The share extension left a PGN in the App Group container.
final class SharedPgnTarget extends LinkTarget {
  const SharedPgnTarget();

  @override
  bool operator ==(Object other) => other is SharedPgnTarget;

  @override
  int get hashCode => (SharedPgnTarget).hashCode;

  @override
  String toString() => 'SharedPgnTarget';
}

/// Not for this layer, or not acceptable. Nothing happens.
final class IgnoredTarget extends LinkTarget {
  const IgnoredTarget(this.reason);

  final IgnoredLinkReason reason;

  @override
  bool operator ==(Object other) =>
      other is IgnoredTarget && other.reason == reason;

  @override
  int get hashCode => Object.hash(IgnoredTarget, reason);

  @override
  String toString() => 'IgnoredTarget(${reason.name})';
}

enum IgnoredLinkReason {
  /// The OIDC redirect. Expected, and none of our business.
  oauthRedirect,

  /// Not a URL, too long, or with parts no link of ours has (user info, a
  /// port).
  malformed,

  /// `https:`, `file:`, anything that is not the app's scheme. Files never
  /// arrive as URLs: the native side reads them and sends the bytes.
  foreignScheme,

  /// The app's scheme, but no entry of the mapping table matches.
  unknownRoute,
}

// ---------------------------------------------------------------------------
// The mapping table. This is the only place that says which locations the
// outside world may open. A pattern is a list of segments; `null` stands for
// one game id. Sign-in, consent and the metadata form are deliberately not
// here: they are steps of a flow, not places to land on.
// ---------------------------------------------------------------------------

typedef _Build = String Function(List<String> ids);

const List<(List<String?>, _Build)> _linkRoutes = [
  (['games'], _games),
  (['games', null], _game),
  (['games', null, 'review'], _gameReview),
  (['new'], _newGame),
  (['new', 'entry'], _newGameEntry),
  (['new', 'import'], _newGameImport),
  (['settings'], _settings),
];

String _games(List<String> ids) => AppRoutes.games;
String _game(List<String> ids) => AppRoutes.game(ids[0]);
String _gameReview(List<String> ids) => AppRoutes.gameReview(ids[0]);
String _newGame(List<String> ids) => AppRoutes.newGame;
String _newGameEntry(List<String> ids) => AppRoutes.newGameEntry;
String _newGameImport(List<String> ids) => AppRoutes.newGameImport;
String _settings(List<String> ids) => AppRoutes.settings;

/// What a game id in a link may look like: UUIDs, numbers and base64-style
/// ids all fit. No slash, no backslash, no percent sign, no whitespace, and
/// (checked separately) not made of dots only. The router percent-encodes the
/// id again when it builds the location.
final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_.~=+:-]{1,128}$');
final RegExp _dotsOnly = RegExp(r'^\.+$');

/// Classifies a URL that reached the app from outside. Pure and total: it
/// never throws, whatever the input.
///
/// Accepted forms of an app link, all meaning the same location:
///
/// * `com.bognerchess.mobile://games/<id>/review` (the first segment sits in
///   the host position, which is why go_router cannot read it unaided),
/// * `com.bognerchess.mobile:///games/<id>/review` and
///   `com.bognerchess.mobile:/games/<id>/review`,
/// * `/games/<id>/review` without a scheme, for callers inside the app such
///   as a push payload (WP-32).
///
/// Query and fragment are dropped: no location of the mapping table takes
/// parameters.
LinkTarget classifyLink(String raw) {
  if (raw.isEmpty || raw.length > kMaxLinkLength) {
    return const IgnoredTarget(IgnoredLinkReason.malformed);
  }
  final uri = Uri.tryParse(raw);
  if (uri == null) {
    return const IgnoredTarget(IgnoredLinkReason.malformed);
  }
  return classifyUri(uri);
}

/// [classifyLink] for an already parsed URI.
LinkTarget classifyUri(Uri uri) {
  if (uri.hasScheme) {
    if (uri.scheme != kAppLinkScheme) {
      return const IgnoredTarget(IgnoredLinkReason.foreignScheme);
    }
  } else if (uri.hasAuthority || !uri.path.startsWith('/')) {
    // "//host/path" or a relative path: not an in-app location.
    return const IgnoredTarget(IgnoredLinkReason.malformed);
  }
  if (uri.userInfo.isNotEmpty || uri.hasPort) {
    return const IgnoredTarget(IgnoredLinkReason.malformed);
  }

  final List<String> segments;
  try {
    // pathSegments percent-decodes and throws on a broken escape.
    segments = [if (uri.host.isNotEmpty) uri.host, ...uri.pathSegments];
  } on Object {
    return const IgnoredTarget(IgnoredLinkReason.malformed);
  }
  // A trailing slash gives one empty segment at the end. Tolerate that one.
  if (segments.isNotEmpty && segments.last.isEmpty) {
    segments.removeLast();
  }
  if (segments.isEmpty) {
    return const IgnoredTarget(IgnoredLinkReason.unknownRoute);
  }

  final first = segments.first.toLowerCase();
  if (first == kOAuthRedirectSegment) {
    return const IgnoredTarget(IgnoredLinkReason.oauthRedirect);
  }
  if (first == kSharedPgnHost) {
    return segments.length == 1
        ? const SharedPgnTarget()
        : const IgnoredTarget(IgnoredLinkReason.unknownRoute);
  }

  for (final (pattern, build) in _linkRoutes) {
    final ids = _match(pattern, segments);
    if (ids != null) {
      return AppLocationTarget(build(ids));
    }
  }
  return const IgnoredTarget(IgnoredLinkReason.unknownRoute);
}

/// The ids when [segments] fits [pattern], else null. Literal segments match
/// without regard to case only in the host position, where the URI parser has
/// already lowercased them; everything else is exact.
List<String>? _match(List<String?> pattern, List<String> segments) {
  if (pattern.length != segments.length) {
    return null;
  }
  final ids = <String>[];
  for (var i = 0; i < pattern.length; i++) {
    final expected = pattern[i];
    final actual = segments[i];
    if (expected != null) {
      if (expected != actual) return null;
    } else {
      if (!_idPattern.hasMatch(actual) || _dotsOnly.hasMatch(actual)) {
        return null;
      }
      ids.add(actual);
    }
  }
  return ids;
}
