# Working in this repo (team rules — read first)

Five people work on this code and share ONE Claude account, so a session
cannot tell who is driving it. These rules keep us from overwriting each
other's work. They apply to people and to Claude alike.

## Before you start, and before every push

1. `git pull --rebase origin hardening` before starting any task.
2. Before **every** push, pull again: `git pull --rebase origin hardening`.
   Resolve any conflicts, re-run the checks (below), then push.
3. **Never force-push** (`--force`, `--force-with-lease`, `+ref`) to
   `hardening` or `main`, and never rewrite commits that are already on
   GitHub. The `.githooks/pre-push` hook refuses a push that would drop a
   teammate's commits; `./setup.sh` switches it on
   (`git config core.hooksPath .githooks`). Do not bypass it with `--no-verify`.
4. Work on `hardening`. Keep commits small and say what changed and why.
5. Check `git config user.name` is YOUR name on your machine, so the
   history shows who did what (the Claude account does not).

A change that needs the backend too (a new field from `/ai/context`, a new
device action) goes in BOTH repos; the backend's tests read this repo's
source to check the two halves agree.

## Secrets — both repos are PUBLIC

Never commit `google-services.json`, `.env*` files, keystores,
`android/key.properties` or `android/app-check-debug-token.txt`. They live
in the team Bitwarden vault and `./setup.sh` writes them locally.

## Checks before pushing

- `flutter analyze` — no new errors or warnings
- `flutter test`
- Java 17 for builds: `export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`

## Setup

`./setup.sh` (see SETUP.md) resets both repos to `origin/hardening`, writes
the secrets from Bitwarden and runs the backend and the app.
