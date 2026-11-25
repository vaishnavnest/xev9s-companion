#!/usr/bin/env bash
# ==============================================================================
# XEV 9S Companion Platform - Provision LocalStack AWS Simulation via Terraform
# Usage: ./scripts/init-aws.sh
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../infrastructure/terraform"
LOCALSTACK_HEALTH_URL="${LOCALSTACK_ENDPOINT:-http://localhost:4566}/_localstack/health"

if ! command -v terraform >/dev/null 2>&1; then
  echo "ERROR: terraform CLI not found in PATH." >&2
  exit 1
fi

echo "Checking LocalStack health at ${LOCALSTACK_HEALTH_URL}..."
ready=false
for i in $(seq 1 15); do
  if curl -sf "${LOCALSTACK_HEALTH_URL}" | grep -qE '"sqs": *"(running|available)"' && \
     curl -sf "${LOCALSTACK_HEALTH_URL}" | grep -qE '"s3": *"(running|available)"'; then
    ready=true
    break
  fi
  echo "Waiting for LocalStack SQS & S3 (${i}/15)..."
  sleep 2
done

if [ "${ready}" != "true" ]; then
  echo "ERROR: LocalStack is not ready. Start it first with: docker compose up -d localstack" >&2
  exit 1
fi

echo "LocalStack is healthy. Running Terraform..."
cd "${TERRAFORM_DIR}"
terraform init -input=false
terraform apply -auto-approve -input=false

echo ""
echo "Provisioned AWS Simulation Resources:"
terraform output
