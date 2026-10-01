# Analytics events

First-party product analytics: the app records a small, fixed set of events
and sends them to the Bogner Chess backend (`trackMobileEvents`), nowhere
else. There is no analytics SDK in the app. This document is the catalogue:
which events exist, when they fire, which properties they may carry, and which
question of the PRD they answer. The names are the constants of
`AnalyticsEvents` in `lib/core/analytics/analytics.dart`; the backend's
allow-list is the same set and drops every other name.

## The rules

1. **Consent first.** Nothing is recorded, not even locally, unless the user
   has granted analytics consent (`analyticsConsentProvider`). Events from
   before the decision are dropped, not kept for later. Withdrawing consent
   empties the local outbox at once; the backend also drops events of people
   whose consent is withdrawn.
2. **No personal data and no content in properties.** No names, e-mail
   addresses, moves, PGN, FEN, comments, error messages or ids of games.
   Properties are counts, durations, booleans and enum-like strings.
3. **The sanitiser enforces rule 2** (`lib/core/analytics/props_sanitizer.dart`),
   because a rule in a document does not stop a mistake in a feature:
   - keys: `^[a-z][a-z0-9_]{0,39}$`;
   - values: `bool`, finite `num`, or a string of at most 40 characters that
     matches `^[a-z0-9_\-\.]+$` (lower case, no spaces: a full name, a
     sentence or a move list cannot pass; a single lower-case word can, so
     rule 2 stays the caller's duty);
   - at most 12 properties; whatever does not fit is **dropped**, never cut.
   The result is always far below the backend's 2 KB limit.
4. **An unknown event name is dropped on the device.** Adding an event means:
   a constant in `AnalyticsEvents` (and in `AnalyticsEvents.all`), a row here,
   and the same name on the backend's allow-list.
5. **Features only call `ref.read(analyticsProvider).track(name, props)`.**
   Fire and forget: it never throws and never blocks.

## What is added to every event

| Field | Value |
| --- | --- |
| `occurredAt` | The moment `track` was called, UTC. The backend accepts ±7 days; older events count as rejected and are dropped. |
| `sessionId` | A random UUID per stretch of use: new at every start of the process and after 30 minutes or more in the background. Never stored outside the outbox, says nothing about the person or the device. |
| `deviceId` | The installation id (`deviceIdProvider`, a random UUID created on first use; not a hardware id). |
| `appVersion` | `<version>+<build>` of the app that sends the batch. |
| owner | The signed-in subject is kept with the event **locally** so that events of one account are never sent under another; on the wire the account is the one of the access token. |

## Delivery

`OutboxAnalytics` writes to the drift table `event_outbox` (at most 1000 rows,
the oldest go first). `EventFlusher` sends it:

- only while somebody is signed in and consent is granted;
- batches of at most 50 events, one session per call, oldest first;
- on app pause, on app resume, after a sign-in, before a sign-out, and every
  60 s in the foreground while something waits (there is no connectivity
  listener; the resume and the timer cover the return of the network);
- after an answer the batch is removed, including what the server counted as
  rejected; a failure worth retrying (offline, time-out, 5xx, rate limit)
  bumps the batch's attempt counter and backs off 60 s, 120 s, … up to 1 h (or
  the server's `retryAfter` if longer); after 10 attempts an event is dropped;
  a validation error drops the batch;
- a sign-out removes that account's unsent events (`AppDatabase.wipeOwner`)
  after one last flush.

## The catalogue

"Owner" is the feature whose code fires the event. Properties marked *planned*
are the agreed shape for a feature that is not merged yet; its work package
fills them in and updates this table if it deviates.

| Event | Fired when | Properties (allowed values) | Serves | Owner |
| --- | --- | --- | --- | --- |
| `app_open` | Once per session: at the start of the process, and when the app returns after ≥ 30 min in the background. | `start`: `cold` \| `warm` | Repeat use (active days), denominator for limit pressure ("active users") | `core/analytics` (`AnalyticsLifecycle`) |
| `sign_in` | The auth state goes from signed out to signed in. Not for a session restored at start. | none | User growth funnel, start of the time-to-first-analysis clock on this device | `core/analytics` (`AnalyticsLifecycle`) |
| `game_entry_started` | The first move is played on the entry board of a new draft. | `resumed`: bool (*planned*) | Goal 1 ("a game in under 2 minutes"): start of the entry timer | entry |
| `game_entry_completed` | The user leaves the entry board for the metadata form. | `plies`: int, `duration_s`: int, `undo_count`: int (*planned*) | Goal 1: entry duration; drop-off between start and completion | entry |
| `pgn_imported` | A PGN passed validation on the import screen. | `source`: `paste` \| `file` \| `open_in` \| `share_extension`, `plies`: int, `games_in_text`: int (*planned*) | Goal 1; which import paths matter | import |
| `game_submitted` | The backend accepted a new game. | `source`: `entry` \| `import`, `plies`: int, `offline_queued`: bool (*planned*) | **Activation** (first game within 24 h of sign-up), **repeat use** (second game within 7 days) | new-game flow |
| `analysis_requested` | The backend took an `analyseGame`: an analysis of that game was asked for. One event per tap, whatever the server then runs. | `source`: `game_detail` \| `submit_queue` | **Time to first analysis** (start), analysis latency (start) | new-game flow / game detail |
| `analysis_stage_ready` | A stage the tracker was watching turned READY. | `stage`: `base_evaluation` \| `base_classification` \| `deep_evaluation` \| `coaching`; `duration_s`: int, from the request to the finish | Latency per stage: which one the user actually waits for | analysis status (`AnalysisNotices`) |
| `analysis_stage_failed` | A stage the tracker was watching failed. | `stage` (as above); `code`: the server's failure code (`stage_input_missing`, `timeout`, `too_many_attempts`, …) | Reliability per stage | analysis status (`AnalysisNotices`) |
| `coach_requested` | The coach was asked for: an `analyseGame` whose target was the coaching stage, or a `runCoaching` from "Run the coach again". | `language`: `en` \| `de` | Take-up of the coach against the analyses that stop short of it; which language it writes in | game detail |
| `analysis_limit_hit` | A **coach** request was answered with "limit reached". Only the coaching stage is metered, so no other stage can raise it. Written by the backend when `analyseGame` leaves the coach out, and by the app when `runCoaching` is refused. | `window`: `day` \| `month` \| `unknown` | **Limit pressure** | game detail |
| `analysis_ready_opened` | The user tapped an "analysis ready" notification and the review opened. | `source`: `push`, `cold_start`: bool | Time to first analysis (end, as the user experiences it); value of push | `core/push` (`PushService`) |
| `review_opened` | The review screen showed an analysis. | `source`: `library` \| `push` \| `link`, `from_cache`: bool (*planned*) | **Time to first analysis** (end), repeat use | review |
| `comment_feedback` | Thumbs up or down on a coach comment (the feedback itself goes through its own mutation; this is the count). | `vote`: `up` \| `down` \| `cleared`, `comment_type`: enum of the analysis document (*planned*) | **Coach usefulness** (thumbs-up share) | review |
| `push_permission_result` | The user answered the notification explainer or the iOS prompt. | `result`: `granted` \| `denied` \| `not_now`, `reason`: `after_first_submit` | Reach of push; explains time-to-open differences | `core/push` (`PushService`) |
| `consent_ai_accepted` | The one-time AI consent was accepted. | `version`: int (*planned*) | Activation funnel (a step before the first analysis) | consent |
| `consent_analytics_changed` | The analytics switch changed. Recorded only when the new value is "granted": a withdrawal records nothing, by rule 1. | `granted`: `true` (*planned*) | Size of the measured population | settings / consent |
| `account_deleted` | The backend confirmed the account deletion. Sent by the flush before the sign-out that follows. | none | Churn | settings / account |

## Mapping to the PRD success metrics

The source of truth for anything that involves money, limits or accounts is
the backend's own data; events add what only the client can see. Where both
exist, the backend table wins and the events explain.

| PRD metric | Definition (PRD) | Computed from | Events involved |
| --- | --- | --- | --- |
| User growth | New registered mobile users per week | Backend: accounts with a first mobile device registration | `sign_in`, `app_open` as cross-check |
| Activation | New users who submit a first game within 24 h of sign-up | Backend: account creation and first game; **events give the funnel**: `sign_in` → `game_entry_started` / `pgn_imported` → `game_submitted` | `sign_in`, `game_entry_started`, `game_entry_completed`, `pgn_imported`, `game_submitted`, `consent_ai_accepted` |
| Time to first analysis | Sign-up to first delivered analysis, median | Backend: account creation → first coaching run done. **Events give the experienced time**: the person's first `analysis_requested` → their first `review_opened` or `analysis_ready_opened`. `analysis_stage_ready` splits that wait into the four stages | `analysis_requested`, `analysis_stage_ready`, `review_opened`, `analysis_ready_opened`, `push_permission_result` (segment) |
| Repeat use | Activated users who submit a 2nd game within 7 days | Backend: games per account; events: `game_submitted` per person, `app_open` for active days | `game_submitted`, `app_open` |
| Coach usefulness | Thumbs-up share on coach comments | Backend: the feedback table (authoritative); events for the share per `comment_type` and per app version | `comment_feedback` |
| Limit pressure | Active users who hit the analysis limit in a month | Numerator: backend limit rejections, or persons with `analysis_limit_hit`; denominator: persons with `app_open` in the month. Since WP-60 only the coach is metered, so this counts coach refusals; since WP-61 the backend writes it when a chained analysis leaves the coach out | `analysis_limit_hit`, `coach_requested`, `app_open` |
| Unit cost, analysis latency | Backend cost per game; submit → results, p90 | Backend only | none |

Two honest limits: events exist only for people who consented, so every
event-based number describes that group; and `sign_in` is recorded only when
consent was granted **before** the sign-in, which on a first install it
usually is not. For new users the funnel therefore starts at
`consent_analytics_changed`.

## The analysis pipeline

Four of the events above belong to one flow, and `lib/core/analytics/analysis_analytics.dart`
is the only place that fires them (`Analytics.analysisRequested`, `.stageReady`,
`.stageFailed`, `.coachRequested`). Three things are worth knowing.

`analysis_requested` is one event per **request**, not per stage. Since WP-61
there is one request — `analyseGame` — and the server runs the stages behind
it, so `analysis_stage_started` is gone: the app no longer starts a stage and
cannot honestly report one. (`runCoaching` from "Run the coach again" is the
single exception, and it reports `coach_requested`, which is what it is.)

`source` says who asked, and each source is recorded by whoever knows:
`game_detail` by `GameDetailController`, `submit_queue` by `SubmitQueue` after
"Save & analyse". Nothing else asks, so nothing can be counted twice.

`analysis_stage_ready` and `analysis_stage_failed` are recorded for **every**
watched game, including the one whose screen is open — the snack bar is
suppressed there, the count is not. They are the only events that still name a
stage: the user never sees the stages, but the latency and the reliability per
stage are what the backend work is steered by.

## For whoever adds an event call

```dart
ref.read(analyticsProvider).track(AnalyticsEvents.gameSubmitted, {
  'source': 'import',
  'plies': game.plies,
});
```

In widget tests `analyticsProvider` is the no-op default; override it with a
recording fake to assert on events (`RecordingAnalytics` in
`test/core/push/push_test_support.dart`). `main.dart` installs the real
implementation (`analyticsOverrides`).
