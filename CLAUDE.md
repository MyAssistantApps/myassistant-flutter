# Working in this repo (team rules — read first)

Five people work on this code and share ONE Claude account, so a session
cannot tell who is driving it. These rules keep us from overwriting each
other's work. They apply to people and to Claude alike.

## Branches: only the owner pushes `hardening`

`hardening` is protected on GitHub: **only dhanuvagman006 can push to it**
(no force-push, no delete). Everyone else works on their own branch and
opens a pull request; the owner reviews and merges.

Each teammate has ONE branch of their own, in both repos, that only they
(and the owner) can push to:

| Person | Branch    |
|--------|-----------|
| Allen   (allenlobo31)      | `allen`   |
| Manish  (Manish-G-suvarna) | `manish`  |
| Karthik (Karthikshettyhub) | `karthik` |
| Chirag  (Chiragkulal07)    | `chirag`  |

Work only on your own branch. It builds nothing, deploys nothing and sends
nothing to testers, so you cannot break the app for anyone else there.

1. Switch to your branch and bring in the latest `hardening`:
   `git checkout <you> && git pull --rebase origin <you> && git pull --rebase origin hardening`
2. Make your change. Commit small, clear commits.
3. Run the checks (below). Do not push code that fails them.
4. Before **every** push, bring in the latest again:
   `git pull --rebase origin hardening`, resolve conflicts, re-run the checks.
5. Push: `git push origin <you>`. Never push to `hardening` or
   `hardening-test` — GitHub refuses it ("protected branch").
6. When it works, open a pull request into `hardening`:
   `gh pr create --base hardening --head <you> --fill` — say what changed
   and how you tested it. The owner reviews and merges it.
7. **Never force-push** a branch someone else also works on, and never
   rewrite commits already on GitHub. The `.githooks/pre-push` hook refuses
   a push that would drop commits already on the remote; `./setup.sh`
   switches it on. Do not bypass it with `--no-verify`.
8. Check `git config user.name` is YOUR name on your machine, so the
   history shows who did what (the shared Claude account does not).

Claude: never push to `hardening` or `hardening-test` unless the person at
the keyboard is the owner and asked for it. Otherwise ask who is at the
keyboard, work on THEIR branch from the table above, push it, and open a PR.
Never push to another teammate's branch, never merge a PR, and never change
branch protection, collaborators, secrets or workflows for a teammate.

## Pushing releases the app

**Every push to `hardening` (except docs-only) releases the app** through
`.github/workflows/in-app-update.yml`: tests, then a build signed with the
team key, numbered one above what the backend publishes now, uploaded to
the backend's update channel. Installed apps offer it on their next
launch. The commit's first line is the "What's new" text users see — write
it for them. Actions → in-app update → Run workflow publishes on demand.

App Distribution is no longer used (the last one was build 207,
2026-11-14). A build signed with another key will not install over
existing ones, which is why the workflow checks the key.

## Secrets — both repos are PUBLIC

Never commit `google-services.json`, `.env*` files, keystores,
`android/key.properties` or `android/app-check-debug-token.txt`. They live
in the team Bitwarden vault and `./setup.sh` writes them locally.

## Checks before pushing

- `flutter analyze` — no new errors or warnings
- `flutter test`
- Java 17 for builds: `export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`
- Use Flutter **3.47.5** (what CI pins). Newer Flutter needs a newer Gradle
  than this project has.

## Setup

`./setup.sh` (see SETUP.md) resets both repos to `origin/hardening` (commit
your branch's work first — uncommitted changes are backed up, then
discarded), writes
the secrets from Bitwarden and runs the backend and the app.

---

# Project guide (for Claude and the team)

MyAssistant is a voice-first personal assistant. Users name their own
assistant — never hardcode a name (the client's old name "Hari" must not
appear in the UI). Backend: `myassistant-backend` (Node/Express/Postgres).

## Which server

The app talks to `https://backend.envisionsit.in` by default
(`lib/services/api_service.dart`, since 2026-11-14). Override per build with
`--dart-define=BASE_URL=...`, e.g. a local backend over USB:

```sh
flutter build apk --debug --dart-define=BASE_URL=http://localhost:3998
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb reverse tcp:3998 tcp:3998
```

Every request carries the phone's location (`X-Geo-Lat/Lng`, from
`LocationService`) and timezone (`X-TZ-Offset`).

## Code map

- `lib/services/api_service.dart` — all HTTP; `getJson` / `sendJson` /
  `postJson` / `deleteJson` return null on failure (409 returns the server's
  explanation with `rejected: true`). Screens say what went wrong in words.
- `lib/services/persona.dart` — the profession chosen at sign-up
  (doctor / advocate / business / professional / student / personal).
  `Persona.proKind` decides which Pro assistant a user sees — only their own.
- `lib/services/pro_words.dart` — profession wording (Clinic / Chambers /
  Office, Patient / Client …). Use it instead of hardcoding "clinic".
- `lib/screens/pro_assistant_screen.dart` — the doctor's / advocate's /
  business assistant page (featured Today card, action grid, public-page
  card, Ask card).
- `lib/screens/clinic/`, `lib/screens/pro/` — the workspaces
  (appointments, follow-ups, dues, consult notes, prescriptions, cases,
  legal drafts, invoices, leads); services in `clinic_service.dart` /
  `pro_service.dart`.
- `lib/screens/listing/` — "Your public page" (professionals publish a page
  found nearby and on Google; posts; booking requests) and "Professionals
  near you" (any user).
- `lib/features/pricecompare/` — Price compare offers products only;
  `PriceCategory.shown` lists what is offered (flights, hotels, rides and
  grocery were removed on 2026-11-14 but stay in the enum for old history).
- Pushes are routed by their `kind` in `lib/services/push_service.dart`;
  notification taps by payload in `openNotificationPayload` (home_shell.dart).

## Conventions

- Hiding a screen is UX, not security — the backend enforces who may use what.
- The app must tolerate an older backend (missing fields): parse defensively,
  and never trap a user on a step the server cannot save.
- Run `flutter analyze` on the files you changed and `flutter test` before
  pushing; add a test in `test/` for new models and parsing.
- Builds on Windows: `--android-project-arg=kotlin.incremental=false` avoids a
  Kotlin cache error when the project and the Pub cache are on different drives.
