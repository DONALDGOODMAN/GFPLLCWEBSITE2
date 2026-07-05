#!/usr/bin/env bash
# Reports the latest gfp-llc deployment's stage/status and live URL.
# Usage: ./check_status.sh   (run from the repo root, or pass the repo path as $1)
set -euo pipefail

REPO_DIR="${1:-.}"
PROJECT_NAME="gfp-llc"
ENV_FILE="$REPO_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env found at $ENV_FILE — create it with CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID." >&2
  exit 1
fi

TOKEN=$(grep '^CLOUDFLARE_API_TOKEN=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r\n')
ACCOUNT_ID=$(grep '^CLOUDFLARE_ACCOUNT_ID=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r\n')

curl -s "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/pages/projects/$PROJECT_NAME/deployments" \
  -H "Authorization: Bearer $TOKEN"
echo
