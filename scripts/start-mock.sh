#!/usr/bin/env bash
# Start the Prism mock server for the XEV 9S Companion API.
# Requires: Node.js (LTS) with npx available.
# Usage: ./scripts/start-mock.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="$SCRIPT_DIR/../docs/openapi.yaml"

if [ ! -f "$SPEC" ]; then
  echo "ERROR: OpenAPI spec not found at $SPEC" >&2
  exit 1
fi

echo "Starting Prism mock server on http://localhost:4010 ..."
echo "API base URL: http://localhost:4010"
echo "Press Ctrl+C to stop."
echo ""

npx @stoplight/prism-cli mock "$SPEC" -p 4010 --cors
