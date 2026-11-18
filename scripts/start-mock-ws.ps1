# Start the Fake WebSocket Realtime Server for XEV 9S Companion.
# Requires: Node.js (LTS).
# Usage: .\scripts\start-mock-ws.ps1

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServerScript = Join-Path $ScriptDir "mock-ws-server.js"

if (-not (Test-Path $ServerScript)) {
    Write-Error "Server script not found at $ServerScript"
    exit 1
}

Write-Host "Starting Fake WebSocket Server on ws://localhost:4011/ws ..."
Write-Host "Press Ctrl+C to stop."
Write-Host ""

if (Get-Command node -ErrorAction SilentlyContinue) {
    node $ServerScript
} else {
    $PyScript = Join-Path $ScriptDir "mock_ws_server.py"
    python $PyScript
}
