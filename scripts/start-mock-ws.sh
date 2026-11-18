#!/usr/bin/env bash
# Start the Fake WebSocket Realtime Server for XEV 9S Companion.
# Requires: Node.js (LTS).
# Usage: ./scripts/start-mock-ws.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_SCRIPT="$SCRIPT_DIR/mock-ws-server.js"

if [ ! -f "$SERVER_SCRIPT" ]; then
    echo "Error: Server script not found at $SERVER_SCRIPT" >&2
    exit 1
fi

echo "Starting Fake WebSocket Server on ws://localhost:4011/ws ..."
echo "Press Ctrl+C to stop."
echo ""

if command -v node >/dev/null 2>&1; then
    node "$SERVER_SCRIPT"
else
    python "$SCRIPT_DIR/mock_ws_server.py"
fi
