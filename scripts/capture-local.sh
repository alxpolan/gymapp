#!/bin/zsh
# Runs the local worker's screenshot capture against this repo.
# Requires MARTESO_API_TOKEN to be set in the environment (not stored here).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

: "${MARTESO_API_URL:=https://app.marteso.com}"
: "${BUNDLE_ID:=com.fringelo.gymnio.Gymnio}"

if [[ -z "${MARTESO_API_TOKEN:-}" ]]; then
  echo "MARTESO_API_TOKEN is required (export it before running this script)" >&2
  exit 1
fi

cd "$REPO_ROOT"
MARTESO_API_URL="$MARTESO_API_URL" MARTESO_API_TOKEN="$MARTESO_API_TOKEN" BUNDLE_ID="$BUNDLE_ID" \
  "$REPO_ROOT/worker/node_modules/.bin/tsx" "$REPO_ROOT/worker/src/local-capture.ts" "$@"
