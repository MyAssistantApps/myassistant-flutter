#!/usr/bin/env bash
# Owner only: store the secrets .github/workflows/distribute.yml needs.
# Run from anywhere after `gh auth login`. Nothing is printed or committed.
# Needs ./setup.sh to have run first (team debug keystore, App Check token,
# backend firebase-adminsdk.json).
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=MyAssistantApps/myassistant-flutter
KS="$HOME/.android/debug.keystore"

# Refuse anything but the team key, so a personal debug key never ships.
keytool -list -v -keystore "$KS" -storepass android 2>/dev/null \
  | grep -q "SHA1: 39:03:80:8D:51:B7:62:B3:83:5F:AB:C5:09:63:5A:B4:D3:9A:5E:1D" \
  || { echo "$KS is not the team debug key — run ./setup.sh first"; exit 1; }

base64 -w0 "$KS" | gh secret set DEBUG_KEYSTORE_BASE64 -R "$REPO"
gh secret set FIREBASE_SERVICE_ACCOUNT -R "$REPO" < ../myassistant-backend/firebase-adminsdk.json
tr -d '[:space:]' < android/app-check-debug-token.txt | gh secret set APP_CHECK_DEBUG_TOKEN -R "$REPO"
gh secret list -R "$REPO"
