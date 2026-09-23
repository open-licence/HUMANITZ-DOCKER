#!/bin/bash
set -euo pipefail

# Reject invalid configuration before downloading or checking game updates.
/bin/bash /app/configure-humanitz.sh --check-only
cd /app
exec /bin/bash ./entrypoint.sh "$@"
