#!/usr/bin/env bash
# Lightweight pre-deploy smoke test for the static site. No dependencies beyond
# coreutils/grep, matching this repo's "no build system" philosophy. Run from
# the repo root (or pass the repo path as $1). Exits non-zero on the first
# failure so CI can gate deployment on this passing.
set -uo pipefail

REPO_DIR="${1:-.}"
INDEX="$REPO_DIR/index.html"
FAIL=0

fail() {
  echo "FAIL: $1" >&2
  FAIL=1
}
pass() {
  echo "ok: $1"
}

if [ ! -s "$INDEX" ]; then
  fail "index.html is missing or empty at $INDEX"
  exit 1
fi
pass "index.html exists and is non-empty"

if grep -qi '<!doctype html>' "$INDEX"; then
  pass "has a doctype"
else
  fail "missing <!DOCTYPE html>"
fi

if grep -qi '<title>.*</title>' "$INDEX"; then
  pass "has a <title>"
else
  fail "missing <title>"
fi

# Every local asset the page references (assets/*.css, *.js, *.jsx) must exist.
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  if [ -f "$REPO_DIR/$ref" ]; then
    pass "referenced asset exists: $ref"
  else
    fail "index.html references missing asset: $ref"
  fi
done < <(grep -oE '(href|src)="assets/[^"?]+' "$INDEX" | sed -E 's/^(href|src)="//' | sort -u)

# Every nav/footer anchor link (#services etc.) must have a matching id="...".
while IFS= read -r anchor; do
  [ -z "$anchor" ] && continue
  if grep -q "id=\"$anchor\"" "$INDEX"; then
    pass "anchor target exists: #$anchor"
  else
    fail "nav links to #$anchor but no element has id=\"$anchor\""
  fi
done < <(grep -oE 'href="#[a-zA-Z0-9_-]+"' "$INDEX" | sed -E 's/href="#(.*)"/\1/' | grep -v '^top$' | sort -u)

# Catch accidentally-committed placeholder/lorem-ipsum content. Note: the
# image-slot component legitimately uses a placeholder="..." HTML attribute
# for its empty-state hint text, so match on standalone marker words only —
# not the word "placeholder" itself, which is a real feature of this page.
if grep -qiE 'lorem ipsum|\btodo\b|\bfixme\b|\bTBD\b|\bXXX\b' "$INDEX"; then
  fail "index.html contains placeholder/TODO-looking text — check before deploying"
else
  pass "no placeholder/TODO markers found"
fi

# Root files for search engines / AI crawlers must exist and be the real thing
# (Cloudflare Pages otherwise serves the homepage for any unknown path).
for f in robots.txt sitemap.xml llms.txt 404.html favicon.svg; do
  if [ -s "$REPO_DIR/$f" ] && ! grep -qi '<title>GFP, LLC — ' "$REPO_DIR/$f"; then
    pass "root file present: $f"
  else
    fail "missing or invalid root file: $f"
  fi
done
grep -q '^Sitemap: https://gfp-engineering.com/sitemap.xml' "$REPO_DIR/robots.txt" 2>/dev/null \
  && pass "robots.txt points to sitemap" || fail "robots.txt has no Sitemap line"
if grep -qiE '^Disallow: */ *$' "$REPO_DIR/robots.txt" 2>/dev/null; then
  fail "robots.txt blocks the whole site"
else
  pass "robots.txt does not block the site"
fi
grep -q '<loc>https://gfp-engineering.com/</loc>' "$REPO_DIR/sitemap.xml" 2>/dev/null \
  && pass "sitemap lists the homepage" || fail "sitemap.xml missing homepage <loc>"

# Every root file must also be staged by the deploy workflow, or it never reaches the site.
for f in robots.txt sitemap.xml llms.txt 404.html favicon.svg; do
  grep -q "cp .*$f" "$REPO_DIR/.github/workflows/deploy.yml" 2>/dev/null \
    && pass "deploy workflow stages $f" || fail "deploy workflow does not copy $f"
done

# Head metadata
grep -q '<meta name="description"' "$INDEX" && pass "has meta description" || fail "missing meta description"
grep -q '<link rel="canonical"' "$INDEX" && pass "has canonical link" || fail "missing canonical link"

# Structured data must be valid JSON (a syntax error silently disables it in search engines).
if command -v node >/dev/null 2>&1; then
  if node -e '
    const s=require("fs").readFileSync(process.argv[1],"utf8");
    const m=[...s.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)];
    if(!m.length) process.exit(2);
    m.forEach(x=>JSON.parse(x[1]));' "$INDEX"; then
    pass "JSON-LD structured data parses"
  else
    fail "JSON-LD structured data missing or invalid"
  fi
else
  echo "skip: node not available, JSON-LD not validated"
fi

# Heavy design-tool libraries must not load for regular visitors.
if grep -qE '<script src="https://unpkg.com/(react|@babel)' "$INDEX"; then
  fail "React/Babel loaded unconditionally — should load only inside the design tool frame"
else
  pass "design-tool libraries are not loaded for visitors"
fi

if [ "$FAIL" -ne 0 ]; then
  echo "Smoke test FAILED — refusing to deploy." >&2
  exit 1
fi

echo "Smoke test passed."
