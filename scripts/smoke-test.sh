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

if [ "$FAIL" -ne 0 ]; then
  echo "Smoke test FAILED — refusing to deploy." >&2
  exit 1
fi

echo "Smoke test passed."
