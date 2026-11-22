#!/usr/bin/env bash
# Owner only: store the secrets .github/workflows/in-app-update.yml and
# ci.yml need. Run from anywhere after `gh auth login`. Nothing is printed
# or committed. Needs ./setup.sh to have run first (team debug keystore,
# android/app/google-services.json).
#
# in-app-update.yml reads its secrets from the "production" environment;
# ci.yml reads GOOGLE_SERVICES_JSON from the repository secrets.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=MyAssistantApps/myassistant-flutter
ENVIRONMENT=production
KS="$HOME/.android/debug.keystore"
GS=android/app/google-services.json

# Refuse anything but the team key, so a personal debug key never ships.
keytool -list -v -keystore "$KS" -storepass android 2>/dev/null \
  | grep -q "SHA1: 39:03:80:8D:51:B7:62:B3:83:5F:AB:C5:09:63:5A:B4:D3:9A:5E:1D" \
  || { echo "$KS is not the team debug key — run ./setup.sh first"; exit 1; }
[ -f "$GS" ] || { echo "$GS is missing — run ./setup.sh first"; exit 1; }

base64 -w0 "$KS" | gh secret set DEBUG_KEYSTORE_BASE64 -R "$REPO" --env "$ENVIRONMENT"
gh secret set GOOGLE_SERVICES_JSON -R "$REPO" --env "$ENVIRONMENT" < "$GS"
gh secret set GOOGLE_SERVICES_JSON -R "$REPO" < "$GS"

# The backend's ADMIN_KEY, typed in (not echoed) so it never sits in a file.
read -rsp "Backend ADMIN_KEY (for UPDATE_ADMIN_KEY): " ADMIN_KEY; echo
[ -n "$ADMIN_KEY" ] || { echo "No key entered; UPDATE_ADMIN_KEY not set"; exit 1; }
printf '%s' "$ADMIN_KEY" | gh secret set UPDATE_ADMIN_KEY -R "$REPO" --env "$ENVIRONMENT"
unset ADMIN_KEY

gh secret list -R "$REPO" --env "$ENVIRONMENT"
gh secret list -R "$REPO"
