# Start the Prism mock server for the XEV 9S Companion API.
# Requires: Node.js (LTS) with npx available.
# Usage: .\scripts\start-mock.ps1

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Spec = Join-Path $ScriptDir "..\docs\openapi.yaml"

if (-not (Test-Path $Spec)) {
    Write-Error "OpenAPI spec not found at $Spec"
    exit 1
}

Write-Host "Starting Prism mock server on http://localhost:4010 ..."
Write-Host "API base URL: http://localhost:4010"
Write-Host "Press Ctrl+C to stop."
Write-Host ""

npx @stoplight/prism-cli mock $Spec -p 4010 --cors
