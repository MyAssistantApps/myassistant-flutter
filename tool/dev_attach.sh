#!/usr/bin/env bash
# Attach to the debug app already running on the phone (no rebuild) and
# take hot-reload keys from a pipe, so a reload can be sent from any shell:
#   tool/dev_attach.sh          # in one terminal; keeps running
#   tool/hot.sh                 # hot reload   (tool/hot.sh R = hot restart)
set -u
cd "$(dirname "$0")/.."
PIPE=/tmp/flutter_attach_keys
[ -p "$PIPE" ] || mkfifo "$PIPE"
DEVICE="${1:-$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')}"
# The pipe is held open for writing too, so it never hits end-of-file.
exec 3<>"$PIPE"
exec flutter attach -d "$DEVICE" <&3
