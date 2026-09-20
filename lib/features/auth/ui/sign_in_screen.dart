// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/auth/domain/sign_in_idp.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Semantics identifiers of the sign-in screen, for UI tests and the
/// simulator tool.
abstract final class SignInIds {
  static const String primary = 'signin-primary';
  static const String register = 'signin-register';
  static const String apple = 'signin-apple';
  static const String google = 'signin-google';
  static const String verifyToggle = 'signin-verify-toggle';
  static const String verified = 'signin-verified';
  static const String error = 'signin-error';
}

/// `/sign-in`: the only screen a signed-out user sees.
///
/// Every button opens the system browser sheet through
/// `AuthRepository.signIn`. This screen never navigates: once the state is
/// `SignedIn`, the router's redirect leaves for the `from` location.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  AuthErrorKind? _error;
  bool _showVerifyHelp = false;

  Future<void> _signIn({bool register = false, SignInIdp? idp}) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repository = ref.read(authRepositoryProvider);
    AuthErrorKind? error;
    try {
      // Completes normally when the user closes the sheet: cancelling is not
      // an error and shows nothing.
      await repository.signIn(register: register, idpHint: idp?.alias);
    } on AuthException catch (e) {
      error = e.kind;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
      // Registration ends outside the sheet when the e-mail address has to
      // be confirmed first: the link in the mail opens in Safari. Whoever
      // comes back from "Create account" without being signed in gets the
      // explanation and the way on. Not after an error: then no mail was
      // sent, and the message above says what happened.
      if (register && error == null && repository.state is! SignedIn) {
        _showVerifyHelp = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final idps = ref.watch(signInIdpsProvider);
    final onPressed = _busy ? null : _signIn;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.appTitle,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.signInTagline,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_error != null) ...[
                    _ErrorBanner(kind: _error!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  // Apple first: its guidelines want Sign in with Apple at
                  // least as prominent as any other provider.
                  for (final idp in idps) ...[
                    _IdpButton(
                      idp: idp,
                      onPressed: onPressed == null
                          ? null
                          : () => unawaited(onPressed(idp: idp)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (idps.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _OrDivider(label: l10n.signInOr),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _Identified(
                    identifier: SignInIds.primary,
                    child: FilledButton(
                      onPressed: onPressed == null
                          ? null
                          : () => unawaited(onPressed()),
                      child: Text(l10n.signInPrimary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Identified(
                    identifier: SignInIds.register,
                    child: OutlinedButton(
                      onPressed: onPressed == null
                          ? null
                          : () => unawaited(onPressed(register: true)),
                      child: Text(l10n.signInRegister),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_busy)
                    Semantics(
                      liveRegion: true,
                      child: Column(
                        children: [
                          const LinearProgressIndicator(),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.signInBusy,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      l10n.signInSameAccount,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  if (_showVerifyHelp)
                    _VerifyHelp(
                      onSignIn: onPressed == null
                          ? null
                          : () => unawaited(onPressed()),
                    )
                  else
                    _Identified(
                      identifier: SignInIds.verifyToggle,
                      child: TextButton(
                        onPressed: () => setState(() => _showVerifyHelp = true),
                        child: Text(
                          l10n.signInVerifyToggle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Puts [identifier] on the same semantics node as the button below it. A
/// plain `Semantics(identifier:)` around a button makes a parent node of its
/// own, and UI tests would find an element that is not the button.
class _Identified extends StatelessWidget {
  const _Identified({required this.identifier, required this.child});

  final String identifier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(identifier: identifier, child: child),
    );
  }
}

class _IdpButton extends StatelessWidget {
  const _IdpButton({required this.idp, required this.onPressed});

  final SignInIdp idp;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    switch (idp) {
      case SignInIdp.apple:
        // Apple's button colours: black on light backgrounds, white on dark
        // ones. inverseSurface is exactly that pair in both themes.
        return _Identified(
          identifier: SignInIds.apple,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              foregroundColor: scheme.brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
            ),
            onPressed: onPressed,
            icon: const Icon(Icons.apple),
            label: Text(l10n.signInApple),
          ),
        );
      case SignInIdp.google:
        return _Identified(
          identifier: SignInIds.google,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            // A plain letter, not Google's logo: the logo is not ours to
            // bundle.
            icon: const ExcludeSemantics(
              child: Text('G', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            label: Text(l10n.signInGoogle),
          ),
        );
    }
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.kind});

  final AuthErrorKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, title, message) = switch (kind) {
      AuthErrorKind.network => (
        Icons.wifi_off,
        l10n.signInErrorOfflineTitle,
        l10n.signInErrorOfflineMessage,
      ),
      AuthErrorKind.server => (
        Icons.error_outline,
        l10n.signInErrorTitle,
        l10n.signInErrorMessage,
      ),
    };
    return Semantics(
      identifier: SignInIds.error,
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(icon, color: scheme.onErrorContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifyHelp extends StatelessWidget {
  const _VerifyHelp({required this.onSignIn});

  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.signInVerifyTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.signInVerifyBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            _Identified(
              identifier: SignInIds.verified,
              child: FilledButton.tonal(
                onPressed: onSignIn,
                child: Text(
                  l10n.signInVerifyAction,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
