# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## What this is

A single-page static marketing website for **GFP, LLC**, an engineering consulting and building commissioning firm (Hollidaysburg, PA). No build system, no package manager, no backend. The page is plain HTML/CSS/JS plus one small React island.

## Layout

```
index.html        # the page (must stay at repo root — see image-slot note)
assets/           # all code
  styles.css
  main.js
  image-slot.js
  tweaks-panel.jsx
  tweaks-app.jsx
screenshots/      # design-iteration PNGs, not referenced by the site
AGENTS.md
```

## Running / previewing

There is no build step. Serve the repo root over HTTP and open the page:

```
python3 -m http.server 8000
# then open http://localhost:8000/
```

Use a server rather than `file://` — the page fetches sidecar JSON and uses modules that browsers block on `file://`. There is no linter; `scripts/smoke-test.sh` is a basic pre-deploy check, and `.github/workflows/deploy.yml` deploys only when run manually (see Deployment rules).

## Architecture

The page is built from three layers that stay deliberately separate:

1. **Vanilla page** — `index.html` + `assets/styles.css` + `assets/main.js`.
   - `styles.css` defines the "Instrument" design system: a `:root` palette of CSS custom properties (`--signal`, `--paper*`, `--ink*`, `--steel*`, type scale, `--maxw`/`--gut`). Restyle by editing these variables, not per-element rules.
   - `main.js` is one IIFE wiring scroll progress, `IntersectionObserver`-driven scroll-spy / reveal / counter animations, contact-form validation+success, and the mobile menu. No framework, no dependencies.

2. **`<image-slot>` web component** — `assets/image-slot.js`. A user-fillable image placeholder: drag/drop or click-to-browse, with cover-mode reframe. It persists drops to a `.image-slots.state.json` sidecar via a host "omelette" runtime bridge (`window.omelette`), so filled images survive reloads and exports. **Outside that runtime it is read-only** — drops won't persist in a plain browser. Each slot needs a unique `id` for persistence; sidecar writes are only permitted at the project root, so `index.html` must stay at the repo root (this is why the page is not moved into a subfolder). See the usage block at the top of the file for all attributes (`shape`, `mask`, `fit`, `radius`, etc.).

3. **Tweaks panel (React island)** — `tweaks-panel.jsx` + `tweaks-app.jsx`, mounted into `#tweaks-root`. React 18 + Babel standalone are loaded from unpkg CDN and transpiled in-browser (`<script type="text/babel">`). This panel is a live theme editor that repaints the vanilla page by setting CSS variables on `:root` (accent color → `--signal`/`--signal-deep`, paper tone, blueprint grid toggle). It does **not** render any page content — the marketing page works without it.
   - `tweaks-panel.jsx` is the reusable shell + control primitives (`useTweaks`, `TweaksPanel`, `TweakColor`, `TweakRadio`, `TweakToggle`, etc.) and owns the host edit-mode protocol (`__activate_edit_mode` / `__edit_mode_*` postMessage handshake).
   - `tweaks-app.jsx` is the GFP-specific config: defaults live in the `/*EDITMODE-BEGIN*/ … /*EDITMODE-END*/` JSON block, which the host runtime reads/writes.

### Scaffold provenance

`image-slot.js`, `tweaks-panel.jsx`, and `tweaks-app.jsx` are starter scaffolds from an "omelette" prototyping runtime (marked `@ds-adherence-ignore`, and they intentionally use raw hex/px). They assume a host bridge (`window.omelette`, postMessage edit-mode) that is absent in a plain static deploy — treat their persistence/edit features as no-ops outside that runtime.

## Working in this repo

- `screenshots/*.png` are design-iteration captures, not site assets — the page does not reference them.
- Section content lives directly in `index.html` (services, process, capabilities, about, contact). The contact form is client-side only; submit just hides the form and shows a success message — there is no backend wired up.
- Cache-busting is manual via `?v=N` query strings on `assets/styles.css` and `assets/main.js`; bump them when changing those files.

## Deployment rules (MANDATORY — read before any git push or deploy)

The owner reviews every change before it goes live. These rules exist because changes were once
pushed and auto-deployed to the live site without review. Do not repeat that.

1. **Never deploy without explicit approval in the current conversation.** "Deploy", "publish",
   "push it live", or "ship it" from the owner, given *after* they have reviewed the specific change,
   is approval. Approval of wording or an idea is NOT approval to deploy. Approval does not carry
   over to later changes.
2. **Rollbacks are deploys too.** Rolling production back, re-running the workflow, or running
   `wrangler pages deploy` / the `deploy-cloudflare` skill all require the same explicit approval.
3. **Pushing to GitHub does not deploy** — `.github/workflows/deploy.yml` is `workflow_dispatch`
   only. Never add `push` or `pull_request` triggers back. Even so, ask before pushing to `main`,
   and say plainly what will happen.
4. **Review locally first.** Show every change on localhost before asking to deploy: serve the repo
   root (`python3 -m http.server 8000`, or the `gfp-site` config in `.claude/launch.json`) and open
   http://localhost:8000/, or share desktop and mobile screenshots of the affected sections when
   the owner can't open localhost. Run `bash scripts/smoke-test.sh .` before asking.
5. **Only when approved, deploy by running the workflow by hand:**
   - Production: `gh workflow run deploy.yml --ref main` (→ gfp-engineering.com)
   - Hosted preview, only if the owner asks for one: `gh workflow run deploy.yml --ref preview`
     (→ https://preview.gfp-llc.pages.dev, not indexed by search engines)
   Then confirm the run succeeded and the change is visible on the live URL.
6. **When unsure, ask.** If it's unclear whether an action changes what visitors see, stop and ask.

## Cloudflare deployment

Deployed on Cloudflare Pages. Credentials live in a local, gitignored `.env` (`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`) — never commit these or print them to a terminal/log.

- **Verify a token against `/client/v4/accounts/{account_id}/tokens/verify`, not `/client/v4/user/tokens/verify`.** For this account, the user-scoped endpoint returns `{"success":false,"errors":[{"code":1000,"message":"Invalid API Token"}]}` for a token that is genuinely valid and active — confirmed only by the account-scoped endpoint (`{"success":true,"messages":[{"message":"This API Token is valid and active"}]}`). Don't conclude a token is bad from the user-scoped endpoint alone; cross-check the account-scoped one before assuming the token/setup is broken.
- **`.env` files saved via Windows Notepad have CRLF line endings.** A trailing `\r` gets silently appended to values when the file is read with plain `source .env` / `. .env` in bash, which can look like "the token is wrong" when it isn't. Read env files with the CR stripped: `source <(tr -d '\r' < .env)`, or extract a single value with `grep '^KEY=' .env | cut -d'=' -f2- | tr -d '\r\n'`.
- **Never print, echo, or partially reveal secret values** (not even first/last N characters) when debugging — check length, character class (e.g. `LC_ALL=C grep -P '[^\x20-\x7E]'` for hidden/non-ASCII chars), or byte-count instead. If a secret is ever accidentally exposed (even partially) in a terminal output or chat, treat it as compromised and roll it immediately rather than continuing to use it.
