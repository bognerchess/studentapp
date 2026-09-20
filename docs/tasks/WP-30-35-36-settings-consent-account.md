---
id: WP-30-35-36
title: Settings, consents, legal documents, account deletion and the board theme picker
status: review
size: L
depends_on: [WP-03, WP-04, WP-10-12, WP-13, WP-25, WP-31]
blocked_by_human: []   # nothing blocks the code; the texts listed under "Texts that need legal review" wait for H7
branch: mobile/WP-30
pr:
---

## Scope

PRD features PL-2 (privacy policy, terms, analytics consent, one-time AI consent), the deletion part of AC-1 (App Store 5.1.1(v)) and the settings half of LIM-2.

- `lib/core/consent/consent_state.dart`: `analyticsConsentProvider` (opt-in, per account, stored in the owner-scoped `kv` table, recorded on the server, retried on the next start) and `aiConsentStatusProvider` (accept, withdraw, re-prompt on a new version).
- `lib/core/chess/board_theme_preference.dart`: `boardThemeProvider` (piece set and colours, a device preference) and `boardSquareColorsOf`.
- `lib/core/ui/widgets/app_markdown.dart` (the only importer of `flutter_markdown_plus`), `draft_badge.dart`; `lib/core/links/link_launcher.dart` (moved from the about feature).
- `lib/features/consent/ui/`: `AiConsentScreen` (full screen, `/consent/ai`), `AnalyticsConsentSheet`, `FirstRunConsentPrompt`.
- `lib/features/legal/`: `legalDocumentProvider`, `LegalPage`, `LegalScreen` (`/settings/legal`), `LegalDocumentScreen` (new root route `/legal/:doc`).
- `lib/features/settings/`: `SettingsScreen` (account, quota, board, entry, data, legal, version), `SettingsUsage`, `SettingsBoard`, `updateRequiredProvider` and `UpdateRequiredGate`.
- `lib/features/account/`: `AccountScreen` (identity, sign-out), `DeleteAccountScreen` (explanation, type-to-confirm, blocked and failed states), `AccountDeletedNotice`, `accountDeletionProvider`.
- `lib/dev/settings_demo.dart`: development entry point for screenshots.

## Out of scope

Library, game detail, analysis status and the usage feature (A); new-game flow and submit queue (B); push, analytics delivery and crash reporting (D). The analytics *state* is here, the outbox and the gate in front of it are D's.

## Contracts

**Consumes:** `LegalApi`, `AccountApi`, `UsageApi`, `ConfigApi` (WP-10/12); `AuthRepository.signOut`, `authStateProvider` (WP-25); `AppDatabase.wipeAll`, `KvDao` (WP-13); `BoardView`, `BoardTheme` (WP-04); `entryAutoQueenProvider` (WP-20); `analyticsProvider`, `AnalyticsEvents`.
**Produces:** the providers under *Handoff notes*; `AppRoutes.legalDocument(slug)`; `AppMarkdown`; `pumpApp(firstRunPrompts:)`; `test/helpers/account_harness.dart`.

## Steps

1. Dependency (`flutter_markdown_plus`), move of `linkLauncherProvider` to core.
2. Core providers: consent state, board theme.
3. Screens: consent, legal, settings, account; the three app-level wrappers in `app.dart`.
4. Strings (119 keys, en + de), router (one root route).
5. Tests, simulator check, evidence.

## Acceptance commands

```bash
tool/check.sh
flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
```

## Evidence

**Gate** (2026-09-20, macOS, Flutter 3.47.5)

```
$ tool/check.sh
==> 1/7 dependencies … 2/7 format … 3/7 analyze: No issues found! … 4/7 check_headers: ok … 5/7 check_layers: ok
==> 6/7 codegen is clean … codegen: clean
==> 7/7 tests: flutter test --exclude-tags golden
00:31 +1501: All tests passed!
OK in 55s
```

1501 = 1400 before this branch + 101 new:

| File | Tests |
| --- | --- |
| `test/core/consent/consent_state_test.dart` (default off, persistence, server record, offline retry, rejected record, other device, sign-out, no storage; AI status, version bump, accept, withdraw) | 14 |
| `test/core/chess/board_theme_preference_test.dart` | 5 |
| `test/features/consent/ai_consent_screen_test.dart` (content, agree, not now, offline, save failure, draft in prod, nothing published, withdraw, deep link, de + 1.3 + SE in light and dark) | 11 |
| `test/features/consent/first_run_consent_prompt_test.dart` (asks once, allow, decline, swipe away, offline wording and later record, other device, privacy link above the sheet, not over sign-in, de + 1.3 + SE) | 9 |
| `test/features/settings/settings_screen_test.dart` (sections, usage: limits, limit reached, unlimited, offline and retry, refresh on return; theme preview and persistence, entry board uses it; auto-queen; analytics switch; AI consent states; navigation; de + 1.3 + SE in light and dark) | 16 |
| `test/features/settings/update_required_test.dart` (version comparison, gate, store link, fail open and re-check on resume, signed out) | 15 |
| `test/features/account/account_screen_test.dart` (identity, unverified e-mail, sign-out confirm and cancel, drafts kept; deletion: explanation, type-to-confirm, accepted with local wipe and final screen, completed, blocked for each reason and the mock's unknown one, offline and retry, three server failures, failing wipe, de + 1.3 + SE in light and dark) | 22 |
| `test/features/legal/legal_document_screen_test.dart` (list, Markdown, draft badge, link schemes, German and English-only note, not published, offline, unknown slug, 1.3 + SE + dark) | 9 |

**iOS build**

```
$ flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
Xcode build done.                                           27.7s
✓ Built build/ios/iphonesimulator/Runner.app
$ tool/check_bundled_assets.sh
check_bundled_assets: ok
```

No change under `ios/`: the new package is Dart only.

**Simulator** (own device "BC-WP-30", iPhone 17 Pro, iOS 26.5, mock server on 5299, `-t lib/dev/settings_demo.dart`; device deleted and server stopped afterwards). Screenshots in `docs/tasks/evidence/`, each in `-en` and `-de`:

| File | What |
| --- | --- |
| `WP-30-consent-*.png`, `WP-30-consent-bottom-de.png` | AI consent screen with the DRAFT badge; the lower part with the backend text |
| `WP-30-analytics-sheet-*.png` | first-run analytics question (backend text) |
| `WP-30-settings-*.png` | settings, top: account, quota, board |
| `WP-30-board-picker-*.png` | board picker with Merida and blue (set through launch arguments, which also proves the persistence path) |
| `WP-30-account-*.png` | account screen |
| `WP-30-delete-confirm-*.png` | deletion screen with the word typed |
| `WP-30-delete-blocked-*.png` | after `POST /__scenario deletion_blocked` |
| `WP-30-account-deleted-*.png` | final confirmation after an accepted deletion |
| `WP-30-legal-*.png` | legal viewer (privacy policy) |

Changes made after looking at the first round: four colour chips wrapped to a second line, so colours became four swatches with names; the preview lost its coordinates and shrank; the sections "Privacy" and "Privacy and terms" sat next to each other, the first is now "Your data"; on the consent screen the plain-language boxes moved above the legal text; the legal viewer printed the title three times when the text opens with its own heading.

Not done: the `inspect` pass of the simulator tool (it asks for a permission per device, which this non-interactive session could not give). Semantics are covered by widget tests (headers, live regions, the selected state of the colour options, merged rows).

## Handoff notes

### Providers

**`analyticsConsentProvider`** (`lib/core/consent/consent_state.dart`), `NotifierProvider<AnalyticsConsentNotifier, AnalyticsConsent>`, values `unknown | granted | denied`. The contract for WP-33/34 is the doc comment of `AnalyticsConsent`; in short:

- Record, queue or send only while the value is `granted`. `unknown` (not asked, not loaded yet, nobody signed in) and `denied` both mean no. Default is off.
- `ref.listen` it: away from `granted` → `EventOutboxDao.clear()` and stop the crash reporter; to `granted` → start.
- **Crash reports ride on the same switch** ("Usage statistics and crash reports"). Both are optional diagnostics leaving the device; two switches would ask one question twice. If legal review wants them apart, add a second provider; the storage keys are already specific to analytics. The backend's `ANALYTICS_CONSENT` text has to mention crash reports then (the mock's does not; the app's footnote does).
- The answer belongs to the account: owner-scoped `kv` keys `consent.analytics`, `.pending`, `.prompted` (a sign-out removes them through `wipeOwner`). Without a local answer the server's record is adopted (accepted current version → granted, `withdrawnAt` → denied), so nobody is asked twice on a second device.
- `set(granted:, shownVersion:)` stores, tracks `consent_analytics_changed {granted}`, and records with `LegalApi.recordConsent(ANALYTICS_CONSENT, version, accepted)`. A failed record stays in `.pending` and is retried at the next start; an `ApiRejected` record is dropped. The event is tracked *after* the state change, so a "no" is dropped by D's gate as well, which is what the user asked for.
- `takeFirstRunPrompt()` is true once per account and device, and never when storage does not work.

**`aiConsentStatusProvider`**, `AsyncNotifierProvider<…, ConsentStatus>`: `value.required` is true until the current version is accepted (so a version bump re-prompts). `notifier.accept(version)` (throws `ApiError`, tracks `consent_ai_accepted {version}`), `notifier.withdraw(version)`. No silent retries. For B: `final agreed = await context.push<bool>(AppRoutes.consentAi);` pops true only after the server recorded it. An error state means "could not ask": just send the request, the server answers `AnalysisAiConsentRequired`.

**`boardThemeProvider`** (`lib/core/chess/board_theme_preference.dart`), `NotifierProvider<BoardThemeNotifier, BoardTheme>`: `BoardView(theme: ref.watch(boardThemeProvider))`. Preferences keys `board.pieceSet`, `board.colors`. It warms the image cache itself. `BoardThumbnail` in the library (A) should read it too.

**`updateRequiredProvider`** (`features/settings/domain/update_required.dart`): fails open (signed out, offline, unknown version), re-checked on resume. It fetches `mobileConfig` itself and does not cache it; whoever introduces a shared `mobileConfigProvider` should make this one read it. `kAppStoreUrl` is a placeholder (`TODO(launch)`).

**`accountDeletedNoticeProvider`**: the final confirmation is an overlay in `MaterialApp.builder`, because the sign-out redirects to `/sign-in` underneath and would take any pushed route with it.

### Edits in other packages' files

| File | Edit |
| --- | --- |
| `lib/app.dart` | three imports; `builder` nests `UpdateRequiredGate`, `AccountDeletedNotice`, `FirstRunConsentPrompt` around `IncomingLinkNotices`. D's and A's wrappers go next to them. |
| `lib/router.dart` | append-only: `AppRoutes.legalDocument(slug)`, `legalDocParam`, `AppRouteNames.legalDocument`, one root `GoRoute` `/legal/:doc`, three imports. |
| `lib/features/entry/ui/entry_screen.dart` | one import, one line: `theme: ref.watch(boardThemeProvider)`. |
| `lib/features/review/ui/review_screen.dart` | one import, `theme: _boardTheme` → `theme: ref.watch(boardThemeProvider)`. Its `initState` still precaches the default set, which is harmless. |
| `lib/features/about/…`, `test/features/about/about_screen_test.dart` | import of the moved `link_launcher.dart`. |
| `test/helpers/pump_app.dart` | new parameter `firstRunPrompts` (default false) that switches the one-time analytics sheet off. **`pump_review.dart`, `pump_entry.dart` and the two other helpers that pump `BognerChessApp` themselves were not touched**; they have no working database, so the sheet never opens there, but a helper that gains an in-memory database needs `firstRunConsentPromptEnabledProvider.overrideWithValue(false)`. |
| `test/app_shell_test.dart` | `ensureVisible` before tapping "About and licences" (the settings are longer than the screen now). |
| `test/l10n_and_scaling_test.dart` | two locations appended. |
| `test/flutter_test_config.dart` (new) | `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true`: every pumped app now reads the consent state from a database object of its own, which printed drift's warning with a stack trace about 150 times per run. The first golden font goes into the same file. |
| `docs/dependencies.md`, `pubspec.yaml`, `pubspec.lock` | `flutter_markdown_plus` 1.0.12 (BSD-3-Clause, Dart only) and `markdown` 7.3.1. |

### Decisions

- **Analytics prompt: a sheet on the first signed-in start, over one of the three tabs only**, dismissible without an answer (stays off), never again afterwards; the switch is in the settings. Opt-in, no pre-ticked anything, the privacy policy one tap away, and the backend text's version is recorded.
- **AI consent cannot be given offline** and a **draft text is not offered on a prod build** ("not available yet"): nobody should consent to a placeholder. On other builds it is shown with a DRAFT badge. This blocks all analyses on prod until the backend serves a reviewed text; that is deliberate, and it means H7 must be done before launch.
- **Withdrawal of the AI consent** is on the consent screen when it is opened from the settings (`recordConsent(AI_CONSENT, accepted: false)`); the mock supports it. Confirm that the real backend accepts that key in `recordConsent`.
- The consent screen shows the app's own "what is sent / never sent" boxes *above* the backend text, so the facts are visible without scrolling and the legal wording follows. The agree button does not wait for a scroll to the end.
- **Type-to-confirm accepts `delete` in any case**; the instruction is localised, the word is not. `AccountApi` sends `DELETE` itself.
- After an accepted deletion: `account_deleted` is tracked first, then the notice, `wipeAll()` (drafts of every account on the device), `signOut()`. A failing wipe does not stop the sign-out.
- Block reasons `kid_account`, `has_dependents`, `active_membership`, `open_invoices` have their own texts; anything else (the mock says `owns_club`) gets a generic one. All lead to `kSupportEmail` (`support@bognerchess.com`, **TODO confirm**).
- The settings are a `SingleChildScrollView`, not a lazy list, so every row exists for tests and the screen-reader rotor. The quota is asked again whenever the tab is re-entered.
- `AppMarkdown` follows only `https` and `mailto` links and loads no images.
- The legal documents need a signed-in user (the API needs a token), so they cannot be linked from the sign-in screen yet. If the store listing's privacy URL is not enough, the backend needs a public endpoint.
- The usage row is local (`settingsUsageProvider` + `SettingsUsage`); the coordinator can swap in A's `usage_summary.dart`, but note that `settings/ui` may not import `usage/ui` under the layer rule, so it would have to move to core or be passed in.

### Texts that need legal review (H7)

All in `app_en.arb` / `app_de.arb`: the `consentAiSent*` and `consentAiNotSent*` lists (they state what the PRD's data-minimisation rule promises; the backend must really strip names, event, place and date), `consentAiProvider`, `consentAiOfflineMessage`, `consentAnalytics*` and `settingsAnalytics*` (including that crash reports are covered), every `accountDelete*` string (what is deleted, what is kept "as long as the law requires", irreversibility, the block reasons), `accountDeletedMessage`, `accountSameAccount`. Backend texts: the mock's AI consent text says player names go to "our analysis service", which reads oddly next to the app's "never sent" list; the real text should make the difference between the platform and the AI provider obvious.

### Found on the way

- `test/features/review/review_screen_golden_test.dart` fails on the base commit already (it pumps `envName: 'prod'` with fake auth, which `authRepositoryProvider` refuses since WP-25). The gate excludes goldens, so it is green; `tool/golden.sh` is not. Not touched.
- **The scratchpad directory is shared between the parallel agents.** I kept my simulator's UDID in a file called `udid` there; another agent wrote a file of the same name at 04:56, and my clean-up command then read *their* UDID: `xcrun simctl shutdown` and `delete` ran against device `DB07762A-B606-42B7-84C8-5972A245D7DF`, which was not mine. It no longer exists. `BC-WP-26` and `BC-WP-32` were not touched; my own `BC-WP-30` was deleted afterwards by its explicit UDID. Whoever owned `DB07762A…` has to create the device again.
- All agents were given port 5299. My server held the port; if another agent's app talked to it, my `deletion_blocked` scenario and two account deletions (which reset the mock's data) happened under them. It is stopped now.
