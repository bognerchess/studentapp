# studentapp — work packages

Scope, dependencies and acceptance for every WP are in `../product-hub/docs/mobile-mvp/03-design-flutter-client.md` (section 5) and `01-implementation-plan.md`; the cross-repo status table and the human gates are in `04-work-package-index.md` there. Create a task file from `TEMPLATE.md` when you start a WP that has none yet.

| ID | Title | Size | Depends on | Status | Task file |
| --- | --- | --- | --- | --- | --- |
| WP-00 | Toolchain and scaffold | M | H0, H1 | review | [WP-00](WP-00-toolchain-and-scaffold.md) |
| WP-01 | iOS project hardening | M | WP-00 | review | [WP-01](WP-01-ios-project-hardening.md) |
| WP-02 | CI and check script | S | WP-00 | review | [WP-02](WP-02-ci-and-check-script.md) |
| WP-03 | App shell | M | WP-00 | review | [WP-03](WP-03-app-shell.md) |
| WP-04 | Vendored chessground, asset allow-list, `BoardView` | M | WP-00 | review | [WP-04](WP-04-chessground-and-boardview.md) |
| WP-10 | Schema, operations, codegen, fixtures | M | WP-02, backend C-03 | review | [WP-10-12](WP-10-12-api-foundation.md) |
| WP-11 | shelf mock server + scenarios | M | WP-10 | review | [WP-10-12](WP-10-12-api-foundation.md) |
| WP-12 | API client layer | M | WP-10 | review | [WP-10-12](WP-10-12-api-foundation.md) |
| WP-13 | drift database | M | WP-02 | review | [WP-13](WP-13-drift-database.md) |
| WP-14 | Analysis document model + mapper | M | chess-ai C-01 | review | [WP-14](WP-14-analysis-document-model.md) |
| WP-20 | Board entry (IN-1) | L | WP-04, WP-13 | review | [WP-20](WP-20-board-entry.md) |
| WP-21 | Metadata form (IN-2) | S | WP-03 | review | [WP-21](WP-21-metadata-form.md) |
| WP-22 | PGN paste, file picker, multi-game chooser (IN-3) | M | WP-04 | review | [WP-22](WP-22-pgn-import.md) |
| WP-23 | "Open in" document types (IN-3) | M | WP-22, WP-01 | review | [WP-23](WP-23-open-in-and-deep-links.md) |
| WP-24 | Share Extension + App Group (IN-3) | M | WP-23 (device signing: H5) | review | [WP-24](WP-24-share-extension.md) |
| WP-25 | Auth: PKCE, single-flight refresh, fake auth (AC-1) | L | WP-03 (real verify: H2, H10) | review | [WP-25](WP-25-auth.md) |
| WP-26 | Library list, search, delete (AC-2) | M | WP-12, WP-13 | todo | – |
| WP-27 | Submit queue, offline to online (AC-3) | M | WP-12, WP-13, WP-20 | review | [WP-27](WP-27-submit-queue-and-flow.md) |
| WP-28 | Analysis request, job poller, usage, limit UX (AN-1, LIM-2) | M | WP-12, WP-13 | todo | – |
| WP-29a | Review: board, move list, glyphs (AN-3) | M | WP-04, WP-14 | review | [WP-29](WP-29-review-screen.md) |
| WP-29b | Eval graph | S | WP-29a | review | [WP-29](WP-29-review-screen.md) |
| WP-29c | Best-line arrows, engine alternative (AN-4) | S | WP-29a | review | [WP-29](WP-29-review-screen.md) |
| WP-29d | Coach cards, thumbs outbox, summary (AN-5/6/7) | M | WP-29a, WP-13 | review | [WP-29](WP-29-review-screen.md) |
| WP-30 | Consents, legal documents, settings (PL-2) | M | WP-12 | review | [WP-30-35-36](WP-30-35-36-settings-consent-account.md) |
| WP-31 | About, licences, source link (PL-1) | S | WP-04 | review | [WP-31](WP-31-about-and-licences.md) |
| WP-32 | Push channel, permission, deep link (AN-2) | M | WP-01, WP-12, WP-29a | review | [WP-32-34](WP-32-34-push-analytics-crash.md) |
| WP-33 | Analytics outbox + event catalogue (PL-3) | M | WP-13, WP-30 | review | [WP-32-34](WP-32-34-push-analytics-crash.md) |
| WP-34 | Sentry, consent-gated | S | WP-30 | review | [WP-32-34](WP-32-34-push-analytics-crash.md) |
| WP-35 | Sign-out and account deletion | S | WP-25 | review | [WP-30-35-36](WP-30-35-36-settings-consent-account.md) |
| WP-36 | Piece-set and theme picker (optional) | S | WP-04 | review | [WP-30-35-36](WP-30-35-36-settings-consent-account.md) |
| WP-40 | End-to-end against the real backend | M | features done, H10 | todo | – |
| WP-41 | `entry_40_moves_test` with perf budget | S | WP-20 | in-progress | – |
| WP-42 | `full_loop_test` + nightly CI | M | features done | todo | – |
| WP-43 | Real-device push, sandbox + production | S | WP-32, H6 | todo | – |
| WP-50 | fastlane + TestFlight deploy workflow | M | H4 | todo | – |
| WP-51 | GPL compliance script + release checklist | S | WP-04 | in-progress | – |
| WP-52 | Accessibility, Dynamic Type, dark mode, German pass | M | features done | todo | – |
| WP-53 | Screenshot generator, privacy doc, review notes | S | features done, H8 | todo | – |
| WP-54 | Reproducible build from a clean clone | S | WP-50 | todo | – |
