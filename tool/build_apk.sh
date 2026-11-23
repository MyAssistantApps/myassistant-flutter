#!/usr/bin/env bash
# Build the release APK for REAL PHONES ONLY.
#
# Always build through this script (or copy its flag): plain
# `flutter build apk --release` bundles x86_64 as well — that ABI exists
# only on emulators, and its plugin native libs are dead weight in every
# download. The gradle abiFilters entry
# does NOT stop it: the Flutter gradle plugin overrides abiFilters with
# its own target-platform list, so the trim must happen on the flutter
# command line.
#
#   tool/build_apk.sh            → build/app/outputs/flutter-apk/app-release.apk
#   tool/build_apk.sh --phone    → the same, arm64 only: for installing on
#                                  the owner's phone (half the native work
#                                  and about half the APK, so the build and
#                                  the install are both quicker). Releases
#                                  for testers keep both ARM ABIs.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGETS="android-arm,android-arm64"
if [ "${1:-}" = "--phone" ]; then
  TARGETS="android-arm64"
  echo "→ phone build: arm64 only (not for publishing)"
fi

# BUILD_NUMBER (optional) overrides the +N in pubspec.yaml — CI sets it so
# every automatic build installs as an update over the previous one.
EXTRA=()
if [ -n "${BUILD_NUMBER:-}" ]; then
  EXTRA+=("--build-number=$BUILD_NUMBER")
  echo "→ build number $BUILD_NUMBER"
fi

flutter build apk --release --target-platform "$TARGETS" \
  ${EXTRA[@]+"${EXTRA[@]}"}
