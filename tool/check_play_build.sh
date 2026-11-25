#!/usr/bin/env bash
# PROVE THAT A GOOGLE PLAY BUILD CONTAINS NO SELF-UPDATER (2026-11-25).
#
# Google Play forbids an app that updates itself. Switching the updater
# off is not enough to rely on: the Play build must not CONTAIN it. The
# updater's native half lives in android/app/src/sideload/kotlin and is
# compiled only into the sideloaded build (android/app/build.gradle.kts);
# a Play build (`-Pstore=play`) compiles android/app/src/play/kotlin, an
# empty stand-in. This script checks that this is still true.
#
#   tool/check_play_build.sh            the source check (seconds; also
#                                       what test/launch_readiness_test.dart
#                                       asserts)
#   tool/check_play_build.sh --gradle   the real thing as well: compiles the
#                                       Play variant and merges its release
#                                       manifest, then inspects both. Nothing
#                                       is packaged, so no upload key is
#                                       needed. CI runs this on every push
#                                       (.github/workflows/ci.yml); do not
#                                       run it on the shared server.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "✗ $*" >&2; exit 1; }
ok() { echo "✓ $*"; }

# What only the updater uses. None of it may appear outside src/sideload.
INSTALLER='PackageInstaller|InstallResultReceiver|ApkInstaller|QuietInstallJob|package-archive|ACTION_INSTALL_PACKAGE|canRequestPackageInstalls|REQUEST_INSTALL_PACKAGES'

SRC=android/app/src
[ -f "$SRC/sideload/kotlin/com/myassistant/myassistant/ApkInstaller.kt" ] || fail "the installer is not in $SRC/sideload/kotlin"
[ -f "$SRC/play/kotlin/com/myassistant/myassistant/UpdaterChannel.kt" ] || fail "the Play stand-in is missing"

if grep -rnE "$INSTALLER" "$SRC/main/kotlin" "$SRC/main/java" 2>/dev/null | grep -v '^\s*$'; then
  fail "installer code in the shared sources (lines above): move it to $SRC/sideload/kotlin"
fi
# The stand-in may NAME the classes in its comment; it may not use an API.
if grep -vE '^\s*(\*|/\*\*|//)' "$SRC/play/kotlin/com/myassistant/myassistant/UpdaterChannel.kt" | grep -nE "$INSTALLER|MethodChannel|JobScheduler|startActivity|http"; then
  fail "the Play stand-in does something (lines above); it must stay empty"
fi
grep -q 'kotlin.srcDir(if (playStoreBuild) "src/play/kotlin" else "src/sideload/kotlin")' android/app/build.gradle.kts \
  || fail "android/app/build.gradle.kts no longer picks the source folder by store"
PLAY_MANIFEST="$SRC/playRelease/AndroidManifest.xml"
for gone in android.permission.REQUEST_INSTALL_PACKAGES android.permission.UPDATE_PACKAGES_WITHOUT_USER_ACTION .InstallResultReceiver .QuietInstallJob; do
  grep -qE "android:name=\"${gone//./\\.}\"[[:space:]]+tools:node=\"remove\"" "$PLAY_MANIFEST" \
    || fail "$gone is not removed in $PLAY_MANIFEST"
done
grep -q 'static const bool enabled = !kPlayStoreBuild;' lib/services/app_update_service.dart \
  || fail "the Dart updater is not tied to kPlayStoreBuild"
ok "sources: the installer is only in src/sideload, the Play stand-in is empty"

[ "${1:-}" = "--gradle" ] || exit 0

# ── the compiled Play variant ────────────────────────────────────────────
[ -x android/gradlew ] || fail "android/gradlew is missing: run a flutter build first (it creates the wrapper)"
echo "→ compiling the Play variant (release, -Pstore=play; nothing is packaged)"
(cd android && ./gradlew --console=plain -q -Pstore=play \
  :app:compileReleaseKotlin :app:processReleaseMainManifest)

MANIFEST=$(find build/app -type f -name AndroidManifest.xml -path '*merged_manifest*' -path '*elease*' | head -1)
[ -n "$MANIFEST" ] || fail "the merged release manifest was not found under build/app"
grep -q 'android.permission.RECORD_AUDIO' "$MANIFEST" || fail "$MANIFEST does not look like the app's manifest"
# Declarations only (android:name="…"): the merger carries the overlay's
# explanatory comment into the merged file, and that comment names them.
for gone in REQUEST_INSTALL_PACKAGES UPDATE_PACKAGES_WITHOUT_USER_ACTION InstallResultReceiver QuietInstallJob; do
  if grep -nE "android:name=\"[^\"]*${gone}\"" "$MANIFEST"; then
    fail "$gone is declared in the Play build's merged manifest ($MANIFEST)"
  fi
done
# The check can see a declaration when there is one: the microphone is.
grep -qE 'android:name="android.permission.RECORD_AUDIO"' "$MANIFEST" \
  || fail "the declaration pattern matches nothing in $MANIFEST"
ok "merged manifest: no install permission, no installer component ($MANIFEST)"

CLASSES=$(find build/app -type f -name 'MainActivity*.class' -path '*elease*' | head -1)
[ -n "$CLASSES" ] || fail "the compiled release classes were not found under build/app"
DIR=$(dirname "$CLASSES")
[ -f "$DIR/UpdaterChannel.class" ] || fail "UpdaterChannel was not compiled into the Play variant ($DIR)"
LEFT=$(find "$DIR" -maxdepth 1 -type f \( -name 'ApkInstaller*.class' -o -name 'QuietInstallJob*.class' -o -name 'InstallResultReceiver*.class' \))
[ -z "$LEFT" ] || fail "installer classes were compiled into the Play variant: $LEFT"
# And the stand-in really is the stand-in: no installer API in its bytecode.
if grep -a -cE 'PackageInstaller|hari/updater|QuietInstallJob' "$DIR/UpdaterChannel.class" | grep -qv '^0$'; then
  fail "the compiled UpdaterChannel refers to the installer"
fi
ok "compiled classes: no ApkInstaller, QuietInstallJob or InstallResultReceiver ($DIR)"
echo "✓ a Google Play build contains no self-updater"
