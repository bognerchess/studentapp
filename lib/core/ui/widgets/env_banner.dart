// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Marks every build that is not production with a corner ribbon showing
/// `ENV_NAME`, so that a screenshot or a tester can never mistake the fake or
/// staging backend for the real one. Production shows nothing.
///
/// It is placed once, in `MaterialApp.builder`.
class EnvBanner extends ConsumerWidget {
  const EnvBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(envProvider);
    if (env.isProd) {
      return child;
    }
    final colors = AppColors.of(context);
    return Banner(
      message: env.envName.toUpperCase(),
      location: BannerLocation.topEnd,
      color: colors.envBanner,
      textStyle: TextStyle(
        color: colors.onEnvBanner,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        height: 1,
      ),
      child: child,
    );
  }
}
