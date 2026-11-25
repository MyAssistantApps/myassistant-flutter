# MyAssistant: product readiness programme

Living progress document, started 2026-11-21. Read this first when resuming.
It records findings, decisions, what changed and what is still open, so no
session has to rediscover them. Verify a claim against the code before
relying on it.

## Ground rules (owner)

- Nothing is released until the owner says "release". Work is committed
  locally in both repos (`myassistant-flutter`, `myassistant-backend`).
- Builds and APK releases only on request; app changes are checked with
  `flutter analyze`, `flutter test` and a hot restart on the test phone.
- All user-facing copy follows the formal register (see
  `D:\MyAssistant\formal-english-style-guide.md`).
- Premium design is the minimum for any UI change.

## Status

| Phase | State |
|---|---|
| 1. Understand product and architecture | done |
| 2. Market and competitor research | done |
| 3. Feature audit | done (app + backend) |
| 4. Prioritised roadmap | done (see Open items) |
| 5. Implementation | first batch done 2026-11-21 |
| 6. Test and validate | app 146/146, backend suites green + test:readiness |
| 7. Release preparation | released 2026-11-21 on the owner's "push to production" |

## Baseline (2026-11-21, before any programme change)

- App: `flutter analyze` 0 errors/warnings (19 infos); `flutter test` 146/146 pass.
- Backend: all 48 `npm run test:*` suites pass against the local test DB
  (lt-pg, port 15434).
- Both repos carry the unreleased booking + urgent-escalation + Home work
  (backend d594b6c, app 526d536). The app's `pubspec.yaml` 0.2.137+215 is a
  local phone-build change: never commit it.
- Android: compileSdk 36, targetSdk = Flutter default, minSdk 26,
  Crashlytics wired (`lib/services/telemetry.dart`). Play-sensitive
  permissions declared: SEND_SMS, READ_CALL_LOG, REQUEST_INSTALL_PACKAGES,
  UPDATE_PACKAGES_WITHOUT_USER_ACTION, REQUEST_DELETE_PACKAGES,
  PACKAGE_USAGE_STATS, SYSTEM_ALERT_WINDOW, USE_FULL_SCREEN_INTENT.

## Findings

Three read-only audits were started 2026-11-21 (market research, app
feature/UX/Android audit, backend feature/security audit). Paste their
conclusions here when resuming.

### Market (research report, 2026-11-21; sources in the session transcript)

- Basic AI call answering is turning free in India: Truecaller AI voicemail
  (free, Dec 2025), Equal AI (1M+ MAU), Jio Call Agent (free, late 2026).
  "Answers your calls" alone is not a moat.
- The gap nobody fills: answer in Hindi/English → book into the
  professional's REAL slot engine → remind → log a record the professional
  owns. Practo Prime does call→booking but per-patient and marketplace-owned;
  clinic voice-AI vendors (CallMissed, Edesy) have no records.
- Pain evidence: doctors drown in WhatsApp (100–150/day), no-shows are
  driven by forgetting/no reminders, advocates fight unreliable cause lists.
- Price anchors: Practo Ray ₹999–1,499/mo, Legal Diary ₹999–1,499/mo,
  Vyapar ₹599/yr, consumer AI ₹399/mo. Voice cost ≈ ₹6.5–7.5/min (Bolna PAYG
  + telephony).
- Core: receptionist + real-slot booking, reminders/follow-ups, urgent
  escalation, hearing alerts, morning brief, dues. Distractions: price
  compare, AI headshots, broad student/personal segment.
- Monetisation proposal: Free (≈10 receptionist min) / Professional ₹999/mo
  or ₹9,999/yr (≈60 min, overage ₹9–10/min) / Practice ₹2,499–3,999/mo.
  The app subscription must use Play Billing (or user-choice billing);
  Razorpay only for patients paying professionals.
- Play risks: READ_CALL_LOG / SMS need default-handler or exception
  declaration; self-update outside Play is forbidden; AI-content rules for
  headshots need in-app reporting; health-apps declaration mandatory.
  TRAI 2026: AI-voice outbound calls must be declared. DPDP core duties from
  13 May 2027 (72 h breach reporting, 1-year logs, 90-day requests).

### App and backend audits (2026-11-21)

No missing endpoints (≈240 app calls checked). Biggest risks found: toll
fraud via outbound AI calls, in-memory call limits, unmetered /clinic AI,
hung jobs stalling the queue, erase gaps on two-sided tables, the mic as a
hard gate, a dead-end Premium CTA, Play-blocking permissions.

## Decisions

- In-app self-update is ON, quietly, for the sideloaded build (owner,
  2026-11-23; it was off from 2026-11-03). It is compiled out of a Google
  Play build: `AppUpdateService.enabled = !kPlayStoreBuild` (2026-11-25).
- Premium shows an early-access list until Play Billing exists
  (`kBillingLive` in premium_plans.dart); interest lands in the Feedback
  inbox with source "premium" — use it to validate pricing.
- Google Play gets its own build (`STORE=play`), the sideload build keeps
  every capability.

## Changes made (2026-11-21)

Backend (`a836107` + follow-up):
- `src/agents/agentCall.js`: +91-only destinations (AGENT_CALL_ALLOWED_PREFIXES),
  restart-proof atomic daily limit, separate allowance for scheduled
  professional reminders (`system: true` in `proactive/scheduler.js`).
- `src/server.js`: per-user write buckets on /clinic; /auth/me and
  logout-all exempt from the sign-in limiter; new POST /feedback.
- `src/infra/jobs.js`: JOB_TIMEOUT_MS deadline, 7-day pruning.
- `src/routes/privacy.js` + feature stores: erase/export both parties
  (bookings host, urgent caller, listing request sender).
- `src/clinic/routes.js`: invoice "paid" is a conditional claim.
- `src/tools/builtins.js`: LIKE-escaped name lookups; `src/ai/context.js`:
  newest 20 unread messages only.
- `src/feedback/routes.js`: Help & Feedback and Pro early-access intake.
- `scripts/readiness-test.js` (`npm run test:readiness`, 7 tests).

App:
- Mic optional: "Continue With Typing Only" (`permissions_screen.dart`),
  orb asks again on first tap (`assistant_engine.dart`).
- Premium: early-access list instead of a dead-end toast.
- Pro page: failed load ≠ empty day (`pro_assistant_screen.dart`).
- `api_service.dart`: one retry on dropped connections; guarded casts in
  clinic_service, reminder, listing, agent-call parsing.
- Hub: "Your Assistant" group (Pro assistant / Workspace, Connect).
- You tab: Help & Feedback sheet with app version (`help_feedback_sheet.dart`).
- Offline first launch re-checks onboarding (`assistant_setup_screen.dart`).
- Play build: `lib/core/store_build.dart`, `android/app/src/playRelease/
  AndroidManifest.xml`, `-Pstore=play` in build.gradle.kts (verified: the
  merged release manifest drops SEND_SMS, READ_CALL_LOG, install/delete
  packages, usage stats, media images/video, AD_ID).

## Changes made (2026-11-25, launch-readiness audit)

A full pre-launch audit was run on 2026-11-25 (both repos, the live server,
Play policy and cost). The owner holds the report; the code changes were:

App (`test/launch_readiness_test.dart`):
- The chat list polls only while its tab is shown (a hidden tab asked the
  server 12 times a minute from every open phone).
- `NetStatus`: an answer below 500 is "the server answers" (a 429 read as
  "server down" and kept re-probing).
- Phone verification requests time out after 30 s.
- `SignOutCleanup` (a sign-out hook): the next account does not inherit the
  assistant's name, price searches or the calendar month; an ended session
  returns to the sign-in screen.
- A release build follows a server override only to our own domains
  (`ApiService.ownDomains`).
- The native copy of the session token is excluded from backups.
- `MicService.acquire` refuses without the microphone permission (Android
  14+ killed the app for a microphone service that could not start).
- Play build: the updater is off, its job and receiver are removed from the
  Play manifest, and Check for Updates is hidden.
- Premium: the "payment is secure" strip and card marks wait for
  `kBillingLive`.
- A widget that fails to build shows one sentence, not a grey box.

Backend (`scripts/hardening-test.js`, `call-code-test.js`, `connect-test.js`):
- Default image model `gpt-image-1.5` (`gpt-image-1` no longer exists on the
  account; every picture had been failing).
- General rate limit per account when signed in (`src/infra/rateKey.js`),
  `/health` not counted; sign-in limit counts refusals tightly.
- Verification-code tries are claimed atomically.
- `GET /legal/delete-account` (Play's account deletion URL).
- Orders, cabs and parcels ask first after outside content.
- Held on branch `owner/reminder-call-fix`, NOT released: the appointment
  and hearing reminder-call queries (they have never run on live; releasing
  the fix starts real phone calls to patients and clients).

## Open items (ranked)

P0 before a Play submission
- Play Console declarations: accessibility service (screen agent),
  special-use + microphone FGS, SYSTEM_ALERT_WINDOW, full-screen intent,
  exact alarms; Data safety (location on every request, analytics id);
  health-apps declaration; AI-content reporting for headshots.
- Play Billing (or user-choice billing) for Pro; then `kBillingLive = true`.
- Turn ALLOW_DEV_PHONE_VERIFY off for a public launch.

P1
- Listing verification/moderation before Google indexes "doctor" pages.
- Connect: default `assistant_open` to contacts, require verified caller.
- Realtime voice session/cost cap; per-account budget before global.
- TRAI 2026 AI-voice declaration with Bolna; announce AI on every call.
- Alert routing (Alertmanager/Grafana contact point), error tracker.
- CI deploy user `ghdeploy` (deploys are manual until then).

P2
- Ask permissions in context instead of one burst at onboarding.
- Accessibility: tooltips/labels listed in the audit, 48 dp targets,
  fixed-height chip rows; cacheWidth on network images.
- Bound weather/place caches; indexes on users(lower(name)), users(fcm_token).
- Product focus: hide price compare / bus "coming soon"; lead with the
  clinic front-desk loop (answer → book real slot → remind → record).

P3
- Rename MeetingsScreen → ChatsScreen; FutureBuilders built in build().
- DPDP (core duties from 13 May 2027): processor terms for doctors,
  72 h breach runbook, 1-year logs.
