# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Bogner Chess for iOS: a Flutter app, GPL-3.0-or-later, public source. It is a **thin client** of the bognerchess.com platform. Players enter or import a game, submit it for asynchronous analysis, and review the result with AI coach comments. There is no engine on the device, no LLM call from the device, no secret or API key in the app, and no product logic that belongs on the server (limits, classification and coach text all come from the backend).

Planning documents live in the private hub next to this repo: `../product-hub/docs/mobile-mvp/` (`01-implementation-plan.md`, `03-design-flutter-client.md`). This repository is public, so keep backend internals out of it. Work packages live in `docs/tasks/`.

## Licence rules (these are not optional)

- **Never copy code from `../student`** or any other bognerchess repository. They are proprietary. You may use facts about the API and ideas about the UX, nothing else.
- Code adapted from `lichess-org/mobile` or `lichess-org/flutter-chessground` is allowed (GPL-3.0) **only** with a header `Adapted from <repo>/<path>@<commit sha>`, the original copyright kept, and an entry in `NOTICE`. Those files stay `GPL-3.0` and do not carry the app-store permission.
- Every file written for this app starts with `// SPDX-License-Identifier: GPL-3.0-or-later` and refers to `LICENSE-APP-STORE-PERMISSION.md`.
- No new dependency without a row in `docs/dependencies.md` (version, licence, why). Accepted: MIT, BSD, Apache-2.0, GPL-compatible. **Never Firebase, never a closed-source SDK.**
- No Lichess name or logo anywhere. Piece sets and fonts only from the allow-list in `NOTICE`; board themes are code-defined colour schemes, never image boards. `tool/check_bundled_assets.sh` checks the built app, because the upstream `chessground` package bundles about 40 piece sets with mixed licences. That is why this app depends on a trimmed copy vendored in `third_party/chessground/` (see `BOGNER_CHANGES.md` there; `third_party/sync_chessground.py` redoes the trim for a new upstream version).

## Architecture rules

- Feature-first layout: `lib/core/{api,auth,storage,chess,analytics,crash,push,l10n,ui}` and `lib/features/<feature>/{data,domain,ui}`.
- Only `lib/core/chess` imports `chessground`. Only `lib/core/api` imports `graphql`. UI code never sees generated GraphQL types; `data/*_mapper.dart` converts them to domain models. `tool/check.sh` enforces these.
- `chessground` is on the v10 API (`ChessboardController`, `GameData`). Read `third_party/chessground/MIGRATION.md`; do not write against the pre-v10 API from memory.
- The analysis document is versioned JSON (`schema_version`, `schema_minor`). Ignore unknown fields, enum values and comment types; on a higher major version show board and moves with an "update the app" banner. Replay engine lines with `dartchess` and silently drop anything illegal.
- Persistence is drift (drafts, cached games and analyses, pending jobs, event and feedback outboxes). The GraphQL cache stays in memory.
- Token refresh is single-flight: refresh tokens rotate, and concurrent refreshes end in `invalid_grant`.
- Every request carries `Authorization: Bearer`, `X-Tenant-Slug` and `GraphQL-preflight: 1`.
- Configuration comes from `--dart-define-from-file=config/<env>.json`. Config files are committed and contain no secrets.
- UI code imports `package:material_ui/material_ui.dart`, not `package:flutter/material.dart` (`go_router` 18 only recognises that package's `MaterialApp`).
- Every user-facing string goes into both ARB files. German is mandatory, not a follow-up.

## Commands

```bash
tool/check.sh     # the gate, identical to CI: format, analyze, headers, layers, codegen-clean, tests (--fast skips codegen and tests; --format rewrites)
tool/gen.sh       # after changing .graphql, drift tables, freezed models or ARB files
dart run tool/mock_server/main.dart --port 5299   # mock GraphQL API for config/fake.json; --help lists options and scenarios
flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
flutter test integration_test -d "iPhone 17 Pro" --dart-define-from-file=config/fake.json
```

(These exist once WP-00, WP-02 and WP-11 are done.)

## Workflow

- One work package per branch and PR. Claim it by setting `status: in-progress` and the branch name in the task file in your first commit. Do not edit `docs/tasks/INDEX.md` on a work-package branch; the coordinator updates it at merge time, because parallel branches conflict there. Never commit to `main`.
- Stay inside your work package's feature directory. Edits to `router.dart` and the ARB files are append-only, to keep parallel branches mergeable.
- Update goldens only on purpose, in their own commit, with before and after in the PR. Goldens run on macOS only.
- **Never type credentials**, never sign in to a real account, never touch signing identities or App Store Connect. Set `blocked_by_human` with the gate id and stop.

## Definition of done

`tool/check.sh` is green. The acceptance commands from the task file were run and their output is pasted into it. For any UI work the app was built with the fake config, launched in the iOS Simulator and checked through the simulator tool (`inspect` works because `BoardView` exposes 64 labelled squares), with German and English screenshots attached. Handoff notes are written and the status is `review`. No unrelated refactors.
