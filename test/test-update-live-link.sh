#!/usr/bin/env bash
# Tests for scripts/update-live-link.sh. Run from anywhere:
#   bash test/test-update-live-link.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/update-live-link.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

check() { # check <name> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    pass=$((pass + 1))
    echo "ok   - $1"
  else
    fail=$((fail + 1))
    echo "FAIL - $1"
    echo "       expected: $2"
    echo "       actual:   $3"
  fi
}

new_readme() {
  cat > "$1" <<'EOF'
# My Project

Some intro text.

<!-- live-link:start -->
<!-- live-link:end -->

More content below.
EOF
}

# --- 1. URL override is injected -------------------------------------------

readme="$TMP/case1.md"
new_readme "$readme"
LIVE_LINK_URL="https://app.example.com" README_FILE="$readme" \
  bash "$SCRIPT" >/dev/null
check "injects live URL" \
  "[View the Live Site](https://app.example.com)" \
  "$(sed -n '6p' "$readme")"

# --- 2. Idempotent ----------------------------------------------------------

before="$(cat "$readme")"
LIVE_LINK_URL="https://app.example.com" README_FILE="$readme" \
  bash "$SCRIPT" >/dev/null
check "second run makes no change" "$before" "$(cat "$readme")"

# --- 3. Placeholder when no URL ----------------------------------------------

readme="$TMP/case3.md"
new_readme "$readme"
out="$(REPOSITORY="definitely-not-real-org/definitely-not-real-repo" \
  GH_TOKEN="" README_FILE="$readme" bash "$SCRIPT" 2>&1)"
check "placeholder URL keeps same link text" \
  "[View the Live Site](https://example.com/your-live-url)" \
  "$(sed -n '6p' "$readme")"
check "warns about placeholder" "0" "$(grep -c placeholder <<<"$out" >/dev/null; echo $?)"

# --- 4. Surrounding content is preserved -------------------------------------

check "heading preserved" "# My Project" "$(sed -n '1p' "$readme")"
check "trailing content preserved" "More content below." "$(sed -n '9p' "$readme")"

# --- 5. Missing markers fails ------------------------------------------------

readme="$TMP/case5.md"
echo "# No markers" > "$readme"
README_FILE="$readme" LIVE_LINK_URL="https://x.example" \
  bash "$SCRIPT" >/dev/null 2>&1
check "missing markers exits non-zero" "1" "$(($? > 0))"

# --- 6. Custom marker and link text ------------------------------------------

readme="$TMP/case6.md"
cat > "$readme" <<'EOF'
# App
<!-- website:start -->
old stuff
<!-- website:end -->
EOF
LIVE_LINK_URL="https://live.example.com" README_FILE="$readme" \
  MARKER="website" LINK_TEXT="Open App" bash "$SCRIPT" >/dev/null
check "custom marker + link text" \
  "[Open App](https://live.example.com)" \
  "$(sed -n '3p' "$readme")"

# --- 7. Multiple blocks -------------------------------------------------------

readme="$TMP/case7.md"
cat > "$readme" <<'EOF'
# Multi
<!-- live-link:start -->
<!-- live-link:end -->
middle
<!-- live-link:start -->
stale
<!-- live-link:end -->
EOF
LIVE_LINK_URL="https://multi.example.com" README_FILE="$readme" \
  bash "$SCRIPT" >/dev/null
check "all marked blocks updated" \
  "2" \
  "$(grep -c 'multi.example.com' "$readme")"

# --- 8. Markers inside fenced code blocks are ignored -------------------------

readme="$TMP/case8.md"
cat > "$readme" <<'EOF'
# Docs
<!-- live-link:start -->
<!-- live-link:end -->

```markdown
<!-- live-link:start -->
<!-- live-link:end -->
```
EOF
LIVE_LINK_URL="https://docs.example.com" README_FILE="$readme" \
  bash "$SCRIPT" >/dev/null
check "fenced markers untouched" \
  "1" \
  "$(grep -c 'docs.example.com' "$readme")"

echo
echo "${pass} passed, ${fail} failed"
(( fail == 0 ))
