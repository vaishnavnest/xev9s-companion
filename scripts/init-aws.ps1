# ==============================================================================
# XEV 9S Companion Platform - Provision LocalStack AWS Simulation via Terraform
# Usage: .\scripts\init-aws.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"

# Refresh PATH in case Terraform was recently installed via winget
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Error "Terraform CLI not found. Install via: winget install HashiCorp.Terraform"
    exit 1
}

$LocalStackHealthUrl = "http://localhost:4566/_localstack/health"
$TerraformDir = Join-Path $PSScriptRoot "..\infrastructure\terraform"

Write-Host "Checking LocalStack health at $LocalStackHealthUrl..." -ForegroundColor Cyan
$MaxAttempts = 15
$Ready = $false

for ($i = 1; $i -le $MaxAttempts; $i++) {
    try {
        $Response = Invoke-RestMethod -Uri $LocalStackHealthUrl -Method Get -TimeoutSec 3
        if ($Response.services.sqs -match "running|available" -and $Response.services.s3 -match "running|available") {
            $Ready = $true
            break
        }
    } catch {
        # LocalStack not ready yet
    }
    Write-Host "Waiting for LocalStack SQS & S3 ($i/$MaxAttempts)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

if (-not $Ready) {
    Write-Error "LocalStack is not ready. Start it first with: docker compose up -d localstack"
    exit 1
}

Write-Host "LocalStack is healthy. Running Terraform..." -ForegroundColor Green

# Provide LocalStack dummy credentials via environment variables (no hardcoded keys in .tf)
if (-not $env:AWS_ACCESS_KEY_ID) { $env:AWS_ACCESS_KEY_ID = "test" } # gitleaks:allow
if (-not $env:AWS_SECRET_ACCESS_KEY) { $env:AWS_SECRET_ACCESS_KEY = "test" } # gitleaks:allow

Push-Location $TerraformDir
try {
    terraform init -input=false
    terraform apply -auto-approve -input=false

    Write-Host "`nProvisioned AWS Simulation Resources:" -ForegroundColor Green
    terraform output
} finally {
    Pop-Location
}
