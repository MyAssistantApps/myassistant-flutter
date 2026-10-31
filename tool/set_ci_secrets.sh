#!/usr/bin/env bash
# Owner only: store the secrets .github/workflows/distribute.yml needs.
# Run from the repo root after `gh auth login`. Nothing is printed or committed.
#
#   tool/set_ci_secrets.sh ~/release-key
#
# The folder must hold hari-release.jks and key.properties.
set -euo pipefail
cd "$(dirname "$0")/.."
KEYDIR="${1:-$HOME/release-key}"
REPO=MyAssistantApps/myassistant-flutter

[ -f "$KEYDIR/hari-release.jks" ] || { echo "missing $KEYDIR/hari-release.jks"; exit 1; }
[ -f "$KEYDIR/key.properties" ]   || { echo "missing $KEYDIR/key.properties"; exit 1; }

base64 -w0 "$KEYDIR/hari-release.jks" | gh secret set RELEASE_KEYSTORE_BASE64 -R "$REPO"
# CI writes the keystore to android/app/hari-release.jks, so point storeFile there.
sed 's#^storeFile=.*#storeFile=hari-release.jks#' "$KEYDIR/key.properties" \
  | gh secret set RELEASE_KEY_PROPERTIES -R "$REPO"
gh secret set FIREBASE_SERVICE_ACCOUNT -R "$REPO" < ../myassistant-backend/firebase-adminsdk.json
tr -d '[:space:]' < android/app-check-debug-token.txt | gh secret set APP_CHECK_DEBUG_TOKEN -R "$REPO"
gh secret list -R "$REPO"
