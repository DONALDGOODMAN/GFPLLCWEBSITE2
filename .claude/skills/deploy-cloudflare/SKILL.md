---
name: deploy-cloudflare
description: Deploy this repo's static site (index.html + assets/) to the existing Cloudflare Pages project "gfp-llc" (gfp-engineering.com). Use whenever the user asks to deploy, publish, push live, or ship changes to Cloudflare/the website, or asks to check the live deployment status or verify the Cloudflare API token/credentials for this project.
---

# Deploy to Cloudflare Pages

This repo is a static HTML/CSS/JS site with no build step (see `CLAUDE.md`/`AGENTS.md`). It's already
connected to a live Cloudflare Pages project named **`gfp-llc`** (custom domains `gfp-engineering.com`
and `www.gfp-engineering.com`), deployed via direct upload rather than a git-connected build.

## Why this skill exists

Getting this working the first time involved a long, confusing debugging session — a real API token
kept failing verification, which turned out to be a wrong assumption on the debugging side, not a
broken token. That cost a lot of back-and-forth. The notes below exist so the same dead ends aren't
re-walked. Read them before troubleshooting from scratch.

## Credentials

Read from `.env` in the repo root (gitignored — never commit it, never print/echo its values, not even
truncated to a few characters). It holds:

```
CLOUDFLARE_API_TOKEN=...
CLOUDFLARE_ACCOUNT_ID=...
```

**Always strip CR before using these values.** The file may have been saved with Windows Notepad, which
writes CRLF line endings — plain `source .env` silently appends an invisible trailing `\r` to values,
which looks exactly like "the token is wrong" when it isn't. Read values like this instead:

```bash
export CLOUDFLARE_API_TOKEN=$(grep '^CLOUDFLARE_API_TOKEN=' .env | cut -d'=' -f2- | tr -d '\r\n')
export CLOUDFLARE_ACCOUNT_ID=$(grep '^CLOUDFLARE_ACCOUNT_ID=' .env | cut -d'=' -f2- | tr -d '\r\n')
```

If a value is ever missing or the file doesn't exist, ask the user to create it — don't ask them to
paste the token into the chat. If a token value is ever accidentally exposed (echoed, printed, or
partially shown) in a terminal or conversation, tell the user to roll it immediately in the Cloudflare
dashboard (My Profile → API Tokens) — treat it as compromised, don't keep using it.

## Verifying the token

Use the **account-scoped** endpoint, not the user-scoped one:

```bash
curl -s "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/tokens/verify" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

`GET /client/v4/user/tokens/verify` (no account scoping) returned `{"success":false,"errors":[{"code":1000,
"message":"Invalid API Token"}]}` for this account even when the token was genuinely valid and active —
confirmed only by the account-scoped endpoint returning `{"success":true,"messages":[{"message":"This API
Token is valid and active"}]}`. **Don't conclude a token is broken from the user-scoped endpoint alone** —
it gave a false negative here. If a token fails the account-scoped check too, then it's actually invalid
(wrong copy-paste, rolled/revoked since, wrong account ID, etc.) and worth troubleshooting for real.

`scripts/verify_token.sh` wraps this check.

## Deploying

**Use `wrangler`, not a hand-rolled `curl` upload.** Cloudflare's Pages direct-upload API requires a
content-hash manifest per file (confirmed via a real failed attempt: posting files as plain multipart
parts returns `{"code":8000096,"message":"A \"manifest\" field was expected..."}`). Reproducing Cloudflare's
internal hashing scheme in a shell script would be guessing at an undocumented format — `wrangler`
already implements it correctly, so use it instead of re-deriving this.

If `wrangler`/`node` aren't installed, check first (`command -v wrangler`, `command -v node`). If
missing, install with `winget install --id OpenJS.NodeJS.LTS -e` then `npm install -g wrangler` (confirm
with the user before installing anything — this changes their system, not just the project). This
project intentionally has no `package.json`/build system (per `CLAUDE.md`) — install wrangler **globally**,
don't add it as a project dependency.

**Always deploy from a clean staging directory, never the repo root directly.** The repo root also
contains `.env`, `.git`, `AGENTS.md`/`CLAUDE.md`, and `screenshots/` — none of which belong in the
deployment, and `.env` in particular must never be uploaded anywhere. Stage only the real site files
first:

```bash
STAGE=$(mktemp -d)
cp index.html "$STAGE/"
cp -r assets "$STAGE/"
```

Then deploy that staged copy:

```bash
export CLOUDFLARE_API_TOKEN=$(grep '^CLOUDFLARE_API_TOKEN=' .env | cut -d'=' -f2- | tr -d '\r\n')
export CLOUDFLARE_ACCOUNT_ID=$(grep '^CLOUDFLARE_ACCOUNT_ID=' .env | cut -d'=' -f2- | tr -d '\r\n')
wrangler pages deploy "$STAGE" --project-name=gfp-llc --commit-dirty=true
```

`wrangler` picks up `CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_ACCOUNT_ID` from the environment automatically —
no interactive login needed. `scripts/deploy.sh` wraps the full staging + deploy sequence.

On Windows/Git Bash, Node and the global npm bin often aren't on `PATH` within a single tool-call shell
(shell state doesn't persist between separate commands). Prepend both before calling `wrangler`:

```bash
export PATH="/c/Program Files/nodejs:/c/Users/donal/AppData/Roaming/npm:$PATH"
```

## Verifying the deploy worked

`wrangler pages deploy` prints a preview URL (`https://<hash>.gfp-llc.pages.dev`) on success. Confirm
the real domain picked it up too — don't just trust the CLI output:

```bash
curl -s https://gfp-engineering.com/ | grep -o "<something distinctive from the change just made>"
```

Or check deployment history via the API:

```bash
curl -s "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/gfp-llc/deployments" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | head -c 2000
```

`scripts/check_status.sh` wraps the latest-deployment check and reports its stage/status and live URL.

## Reference

- Project name: `gfp-llc` (id `e6137d6d-88f0-4e05-82a9-0011c300423c`)
- Custom domains: `gfp-engineering.com`, `www.gfp-engineering.com`
- Default `*.pages.dev` subdomain: `gfp-llc.pages.dev`
