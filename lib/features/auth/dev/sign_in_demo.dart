// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/auth/fake_auth_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Development entry point: the whole app with fake auth, but starting
/// signed **out**, so that the sign-in screen can be looked at and walked
/// through in the simulator without an identity provider.
///
///     flutter run -t lib/features/auth/dev/sign_in_demo.dart \
///       --dart-define-from-file=config/fake.json
///
/// `--dart-define=SIGN_IN_DEMO=offline` (or `error`) makes every sign-in
/// attempt fail that way; without it, any button signs in after a moment.
/// `--dart-define=SIGN_IN_DEMO_TAP=signin-verify-toggle,signin-register` taps
/// the elements with those semantics identifiers, one per second after start, for screenshots of the states
/// behind a tap where nothing can tap for you (`xcrun simctl` cannot).
///
/// Not reachable from `main.dart`, and `FakeAuthRepository` asserts that it
/// is not running in a release build.
const String _mode = String.fromEnvironment('SIGN_IN_DEMO');
const String _autoTap = String.fromEnvironment('SIGN_IN_DEMO_TAP');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = FakeAuthRepository(
    signedIn: false,
    signInDelay: const Duration(seconds: 2),
    signInError: switch (_mode) {
      'offline' => const AuthException(AuthErrorKind.network, 'demo'),
      'error' => const AuthException(AuthErrorKind.server, 'demo'),
      _ => null,
    },
  );
  runApp(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: const BognerChessApp(),
    ),
  );
  // One identifier or several, comma-separated, tapped a second apart.
  final identifiers = _autoTap.split(',').where((id) => id.isNotEmpty);
  for (final (index, identifier) in identifiers.indexed) {
    Timer(Duration(seconds: index + 1), () => _tap(identifier));
  }
}

/// A synthetic tap in the middle of the widget with semantics [identifier].
void _tap(String identifier) {
  Element? target;
  void visit(Element element) {
    final widget = element.widget;
    if (widget is Semantics && widget.properties.identifier == identifier) {
      target = element;
      return;
    }
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  final box = target?.renderObject;
  if (box is! RenderBox) {
    return;
  }
  final position = box.localToGlobal(box.size.center(Offset.zero));
  GestureBinding.instance
    ..handlePointerEvent(PointerDownEvent(position: position))
    ..handlePointerEvent(PointerUpEvent(position: position));
}
