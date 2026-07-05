#!/usr/bin/env bash
# Stages only the real site files (index.html + assets/) into a clean temp dir
# and deploys them to the gfp-llc Cloudflare Pages project via wrangler.
# Usage: ./deploy.sh   (run from the repo root, or pass the repo path as $1)
set -euo pipefail

REPO_DIR="${1:-.}"
PROJECT_NAME="gfp-llc"
ENV_FILE="$REPO_DIR/.env"

export PATH="/c/Program Files/nodejs:/c/Users/donal/AppData/Roaming/npm:$PATH"

if ! command -v wrangler >/dev/null 2>&1; then
  echo "wrangler not found on PATH. Install Node.js (winget install --id OpenJS.NodeJS.LTS -e)" >&2
  echo "then 'npm install -g wrangler' — confirm with the user before installing." >&2
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env found at $ENV_FILE — create it with CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID." >&2
  exit 1
fi

export CLOUDFLARE_API_TOKEN=$(grep '^CLOUDFLARE_API_TOKEN=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r\n')
export CLOUDFLARE_ACCOUNT_ID=$(grep '^CLOUDFLARE_ACCOUNT_ID=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r\n')

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

cp "$REPO_DIR/index.html" "$STAGE/"
cp -r "$REPO_DIR/assets" "$STAGE/"

wrangler pages deploy "$STAGE" --project-name="$PROJECT_NAME" --commit-dirty=true
