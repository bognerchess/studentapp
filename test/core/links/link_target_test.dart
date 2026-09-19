// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/links/link_target.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_test/flutter_test.dart';

const _s = kAppLinkScheme;

LinkTarget _location(String location) => AppLocationTarget(location);
LinkTarget _ignored(IgnoredLinkReason reason) => IgnoredTarget(reason);

void main() {
  group('app links', () {
    final accepted = <String, String>{
      '$_s://games': AppRoutes.games,
      '$_s://games/': AppRoutes.games,
      '$_s://games/abc': AppRoutes.game('abc'),
      '$_s://games/abc/review': AppRoutes.gameReview('abc'),
      '$_s://games/abc/review/': AppRoutes.gameReview('abc'),
      '$_s://new': AppRoutes.newGame,
      '$_s://new/entry': AppRoutes.newGameEntry,
      '$_s://new/import': AppRoutes.newGameImport,
      '$_s://settings': AppRoutes.settings,
      // The same location in the other spellings.
      '$_s:///games/abc/review': AppRoutes.gameReview('abc'),
      '$_s:/games/abc/review': AppRoutes.gameReview('abc'),
      '/games/abc/review': AppRoutes.gameReview('abc'),
      // Scheme and host are case-insensitive by the URI rules.
      'COM.BognerChess.Mobile://GAMES/abc/review': AppRoutes.gameReview('abc'),
      // Ids: a UUID, a number, a base64-style id. The case of an id is kept.
      '$_s://games/0b9f6c1e-7a52-4c55-9a5e-1f2f6f3f9a10/review':
          AppRoutes.gameReview('0b9f6c1e-7a52-4c55-9a5e-1f2f6f3f9a10'),
      '$_s://games/42': AppRoutes.game('42'),
      '$_s://games/R2FtZToxMjM=/review': AppRoutes.gameReview('R2FtZToxMjM='),
      '$_s://games/AbC': AppRoutes.game('AbC'),
      // Query and fragment are dropped.
      '$_s://games/abc/review?utm=x&from=https://evil.example#frag':
          AppRoutes.gameReview('abc'),
    };
    accepted.forEach((link, location) {
      test('$link -> $location', () {
        expect(classifyLink(link), _location(location));
      });
    });

    test('the id is percent-encoded again when the location is built', () {
      // "+" and "=" and ":" are legal in an id and must survive go_router's
      // decoding of the path.
      final target = classifyLink('$_s://games/a+b:c=/review');
      expect(target, isA<AppLocationTarget>());
      final location = (target as AppLocationTarget).location;
      expect(location, '/games/a%2Bb%3Ac%3D/review');
      expect(Uri.parse(location).pathSegments[1], 'a+b:c=');
    });
  });

  group('the OIDC redirect is ignored', () {
    for (final link in [
      '$_s:/oauthredirect',
      '$_s:/oauthredirect?code=SplxlOBeZQQYbYS6WxSbIA&state=af0ifjsldkj',
      '$_s://oauthredirect?code=abc&state=def',
      '$_s:///oauthredirect?code=abc',
      '$_s:/OAuthRedirect?code=abc',
      '$_s:/oauthredirect/extra?code=abc',
      '$_s:/oauthredirect?error=access_denied',
    ]) {
      test(link, () {
        expect(classifyLink(link), _ignored(IgnoredLinkReason.oauthRedirect));
      });
    }

    test('a target never prints the URL', () {
      final target = classifyLink('$_s:/oauthredirect?code=SECRET');
      expect(target.toString(), isNot(contains('SECRET')));
    });
  });

  group('the share extension hand-off', () {
    test('shared-pgn', () {
      expect(classifyLink('$_s://shared-pgn'), const SharedPgnTarget());
      expect(classifyLink('$_s://shared-pgn/'), const SharedPgnTarget());
      // Whatever the extension may append later is not a file name for us.
      expect(classifyLink('$_s://shared-pgn?x=1'), const SharedPgnTarget());
    });

    test('shared-pgn takes no path: nobody names a file through a link', () {
      for (final link in [
        '$_s://shared-pgn/other.pgn',
        '$_s://shared-pgn/..%2F..%2FLibrary%2FPreferences%2Fx.plist',
      ]) {
        expect(
          classifyLink(link),
          _ignored(IgnoredLinkReason.unknownRoute),
          reason: link,
        );
      }
    });
  });

  group('hostile and broken input', () {
    final unknown = [
      // Not in the table, on purpose.
      '$_s://sign-in',
      '$_s://sign-in?from=https://evil.example',
      '$_s://consent/ai',
      '$_s://new/metadata',
      '$_s://settings/account',
      '$_s://nowhere',
      '$_s://games/abc/review/extra',
      '$_s://games/abc/delete',
      '$_s://',
      '$_s:',
      '$_s:///',
      '/',
      '/unknown',
      // Path traversal, plain and encoded, in the id position.
      '$_s://games/%2E%2E%2Fsettings/review',
      '$_s://games/..%2F..%2Fsettings',
      '$_s://games/abc%2Freview',
      '$_s://games/abc%5C..%5Csettings',
      '$_s://games/%00/review',
      '$_s://games/a%20b/review',
      '$_s://games/a%25b/review',
      '$_s://games/%E2%80%AE/review',
      "$_s://games/'%20OR%201=1/review",
      '$_s://games/<script>/review',
      '$_s://games//review',
      // The URI parser escapes a stray percent sign; the id pattern refuses it.
      '$_s://games/%zz',
      '$_s://games/%',
      // An id longer than any real one.
      '$_s://games/${'a' * 129}',
    ];
    for (final link in unknown) {
      test('unknown route: $link', () {
        expect(classifyLink(link), _ignored(IgnoredLinkReason.unknownRoute));
      });
    }

    test('dot segments are resolved by the URI parser, never passed on', () {
      // "games/../settings" collapses before we look at it. What is left
      // either is in the table or is not; ".." never reaches the router.
      for (final link in [
        '$_s://games/../settings',
        '$_s://games/%2e%2e/review',
        '$_s://games/%2E%2E/%2e%2e/settings',
        '$_s://games/abc/../../../../etc/passwd',
        '$_s:///games/../../etc/passwd',
        '/games/../../etc/passwd',
      ]) {
        final target = classifyLink(link);
        if (target is AppLocationTarget) {
          expect(target.location, isNot(contains('..')), reason: link);
          expect(target.location, isNot(contains('etc')), reason: link);
        } else {
          expect(target, isA<IgnoredTarget>(), reason: link);
        }
      }
    });

    final foreign = [
      'https://bognerchess.com/games/abc/review',
      'http://localhost/games/abc',
      'file:///private/var/mobile/game.pgn',
      'file:///etc/passwd',
      'javascript:alert(1)',
      'data:text/plain,1.e4',
      'tel:+41000000000',
      'com.bognerchess.mobile.evil://games/abc',
      'com.bognerchess://games/abc',
    ];
    for (final link in foreign) {
      test('foreign scheme: $link', () {
        expect(classifyLink(link), _ignored(IgnoredLinkReason.foreignScheme));
      });
    }

    final malformed = [
      '',
      'games/abc/review',
      '//games/abc/review',
      '//evil.example/games/abc',
      '$_s://user:secret@games/abc',
      '$_s://games:8080/abc',
      'http://[::1',
      '$_s://games/${'a' * kMaxLinkLength}',
    ];
    for (final link in malformed) {
      final label = link.length > 60 ? '${link.substring(0, 60)}…' : link;
      test('malformed: "$label"', () {
        expect(classifyLink(link), _ignored(IgnoredLinkReason.malformed));
      });
    }

    test('never throws, whatever comes in', () {
      const fragments = [
        _s, ':', '/', '//', '///', '..', '%', '%2', '%2e', '%00', '?', '#', //
        '@', '[', ']', ' ', '\n', '\u0000', '\u202e', 'games', 'review',
        'shared-pgn', 'oauthredirect', 'file', 'é', '🙂', r'\',
      ];
      var count = 0;
      for (final a in fragments) {
        for (final b in fragments) {
          for (final c in fragments) {
            expect(() => classifyLink('$a$b$c'), returnsNormally);
            count++;
          }
        }
      }
      expect(count, greaterThan(15000));
    });

    test('every accepted location is one the router knows', () {
      for (final link in [
        '$_s://games',
        '$_s://games/x',
        '$_s://games/x/review',
        '$_s://new',
        '$_s://new/entry',
        '$_s://new/import',
        '$_s://settings',
      ]) {
        final location = (classifyLink(link) as AppLocationTarget).location;
        expect(location, startsWith('/'));
        expect(location, isNot(startsWith('//')));
        expect(Uri.parse(location).hasScheme, isFalse);
      }
    });
  });
}
