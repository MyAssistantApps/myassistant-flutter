# Local setup — myassistant-flutter

## Quick start

`./setup.sh` sets up both repos and runs the backend and this app on the
connected phone — see the Quick start in `myassistant-backend/SETUP.md`.
The sections below are the same steps by hand.

Builds the Android app and runs it on a phone against your local backend.
Work happens on the `hardening` branch. Set up the backend first
(`myassistant-backend/SETUP.md`).

> **This repo is public.** Never commit `google-services.json`, `.env*`
> files, keystores or `android/key.properties`. `.gitignore` already blocks
> them — do not force-add.

## Prerequisites

- Flutter SDK (stable) and Android SDK with `adb`
- Java 17 — Gradle breaks on newer JDKs:
  `export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`
- An Android phone with USB debugging on, on the same Wi-Fi as your machine
- Membership in Firebase project **hari-62ec0** (ask a maintainer)

## 1. Clone

```bash
git clone https://github.com/MyAssistantApps/myassistant-flutter.git
cd myassistant-flutter
git checkout hardening
flutter pub get
```

## 2. google-services.json

Firebase console → project **hari-62ec0** → Project settings → Your apps →
Android app `com.myassistant.myassistant` → download `google-services.json`
into `android/app/`.

## 3. Register your debug key (Google Sign-In)

Google sign-in only works from an APK signed with a key whose SHA-1 is
registered. Every developer machine has its own debug key:

```bash
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android | grep SHA1
```

Send the SHA-1 to a maintainer. It is added in Google Cloud project
**hariassistantapp** → APIs & Services → Credentials → Create credentials →
OAuth client ID → Android, package `com.myassistant.myassistant`. That is
the project that owns the Web client the app signs in with. A package +
SHA-1 pair can exist in only one project, so it cannot also be added in
Firebase for hari-62ec0.

## 4. Build settings

The app reads its settings at compile time (`--dart-define`), not from a
`.env` at runtime. Create `.env.dev.json` (git-ignored) in the repo root:

```json
{
  "BASE_URL": "http://<your-LAN-IP>:3000",
  "APP_API_KEY": "<APP_API_KEY from your backend .env>",
  "GOOGLE_WEB_CLIENT_ID": "745518568956-211gq0mf70kv5lq58nnv9k9gmfe9i3i1.apps.googleusercontent.com"
}
```

- `BASE_URL`: your machine's address from `hostname -I`. `localhost` means
  the phone itself, not your machine.
- `GOOGLE_WEB_CLIENT_ID` is also the built-in default; keep it equal to the
  backend's `GOOGLE_WEB_CLIENT_ID`.

## 5. Run

```bash
adb devices                                        # phone listed as "device"
flutter run --dart-define-from-file=.env.dev.json
```

For hot reload from another terminal, see `tool/dev_run.sh` and
`tool/hot.sh`.

## App Check / Firebase AI Logic

Debug builds need an App Check debug token or Firebase AI Logic refuses
them. Put it in `android/app-check-debug-token.txt` (git-ignored); the
scripts in `tool/` pass it in. Get one from a maintainer, or register your
own in Firebase console → App Check → Apps → Manage debug tokens.
