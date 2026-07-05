#!/usr/bin/env bash
# Verifies the Cloudflare API token in .env using the account-scoped endpoint.
# Usage: ./verify_token.sh   (run from the repo root, or pass the repo path as $1)
set -euo pipefail

REPO_DIR="${1:-.}"
ENV_FILE="$REPO_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env found at $ENV_FILE — create it with CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID." >&2
  exit 1
fi

TOKEN=$(grep '^CLOUDFLARE_API_TOKEN=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r\n')
ACCOUNT_ID=$(grep '^CLOUDFLARE_ACCOUNT_ID=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r\n')

if [ -z "$TOKEN" ] || [ -z "$ACCOUNT_ID" ]; then
  echo "CLOUDFLARE_API_TOKEN or CLOUDFLARE_ACCOUNT_ID is empty in $ENV_FILE." >&2
  exit 1
fi

# Account-scoped endpoint — the user-scoped /user/tokens/verify has given false
# negatives for this account, see SKILL.md. Always check this one first.
curl -s "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/tokens/verify" \
  -H "Authorization: Bearer $TOKEN"
echo
