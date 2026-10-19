#!/usr/bin/env bash
# Send a key to tool/dev_attach.sh: r = hot reload (default), R = hot restart.
printf '%s' "${1:-r}" > /tmp/flutter_attach_keys
