#!/usr/bin/env bash
# Build and install the DEBUG app on the phone (needed only when native
# Android code changed), then keep it attached for hot reload from a pipe:
#   tool/dev_run.sh             # in one terminal; keeps running
#   tool/hot.sh                 # hot reload   (tool/hot.sh R = hot restart)
set -u
cd "$(dirname "$0")/.."
PIPE=/tmp/flutter_attach_keys
[ -p "$PIPE" ] || mkfifo "$PIPE"
DEVICE="${1:-$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')}"
# Flutter's Gradle wants Java 17; a stray JAVA_HOME breaks the build.
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
exec 3<>"$PIPE"
exec flutter run -d "$DEVICE" <&3
