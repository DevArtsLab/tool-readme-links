#!/usr/bin/env bash
# update-live-link.sh
#
# Injects a repository's live deployment URL into a README, between HTML
# comment markers. The URL is read from the repository's "About" section
# (the `homepage` field of the GitHub repository API). When no homepage is
# set, the same link markup is written with a placeholder URL so the README
# UI stays identical.
#
# Configuration (environment variables):
#   README_FILE       File to update.                 Default: README.md
#   MARKER            Marker name in "<!-- NAME:start -->" / "<!-- NAME:end -->".
#                                                     Default: live-link
#   LINK_TEXT         Visible text of the link.       Default: View the Live Site
#   PLACEHOLDER_URL   URL used when no homepage is set.
#                                                     Default: https://example.com/your-live-url
#   REPOSITORY        owner/name to query.            Default: $GITHUB_REPOSITORY
#   LIVE_LINK_URL     Skip the API and use this URL directly (testing/manual).
#   GH_TOKEN          Token for `gh`/`curl` API calls. In Actions pass
#                     ${{ secrets.GITHUB_TOKEN }}.
#
# Outputs (appended to $GITHUB_OUTPUT when set):
#   url, changed, using_placeholder

set -euo pipefail

README_FILE="${README_FILE:-README.md}"
MARKER="${MARKER:-live-link}"
LINK_TEXT="${LINK_TEXT:-View the Live Site}"
PLACEHOLDER_URL="${PLACEHOLDER_URL:-https://example.com/your-live-url}"
REPOSITORY="${REPOSITORY:-${GITHUB_REPOSITORY:-}}"

die() { echo "error: $*" >&2; exit 1; }

[[ -f "$README_FILE" ]] || die "readme file not found: $README_FILE"

START="<!-- ${MARKER}:start -->"
END="<!-- ${MARKER}:end -->"

start_ln="$(grep -nF "$START" "$README_FILE" | head -1 | cut -d: -f1)"
end_ln="$(grep -nF "$END" "$README_FILE" | head -1 | cut -d: -f1)"

[[ -n "$start_ln" ]] || die "missing start marker: $START"
[[ -n "$end_ln" ]]   || die "missing end marker: $END"
(( start_ln < end_ln )) || die "end marker appears before start marker"

# --- Resolve the live URL ---------------------------------------------------

url="${LIVE_LINK_URL:-}"

if [[ -z "$url" && -n "$REPOSITORY" ]]; then
  if command -v gh >/dev/null 2>&1; then
    # gh exits non-zero on API errors but may still print the error body on
    # stdout, so only accept the output when the command succeeded.
    if out="$(gh api "repos/${REPOSITORY}" --jq '.homepage // ""' 2>/dev/null)"; then
      url="$out"
    else
      echo "warning: could not read homepage for ${REPOSITORY} via gh" >&2
    fi
  elif command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
    if [[ -n "$token" ]]; then
      if out="$(curl -fsS -H "Authorization: Bearer ${token}" \
        "https://api.github.com/repos/${REPOSITORY}" 2>/dev/null | jq -r '.homepage // ""')"; then
        url="$out"
      else
        echo "warning: could not read homepage for ${REPOSITORY} via curl" >&2
      fi
    else
      echo "warning: gh not found and no GH_TOKEN for curl fallback" >&2
    fi
  else
    echo "warning: no way to query GitHub API (need gh, or curl+jq)" >&2
  fi
elif [[ -z "$REPOSITORY" && -z "${LIVE_LINK_URL:-}" ]]; then
  echo "warning: no repository specified; falling back to placeholder" >&2
fi

using_placeholder=0
if [[ -z "$url" ]]; then
  url="$PLACEHOLDER_URL"
  using_placeholder=1
  echo "info: no homepage set on ${REPOSITORY:-<unknown repo>}; using placeholder URL" >&2
fi

# --- Rewrite the marked block -----------------------------------------------

link_line="[${LINK_TEXT}](${url})"
tmp="${README_FILE}.tmp.$$"

# Rewrite only markers outside fenced code blocks, so marker examples in
# documentation are not rewritten.
awk -v start="$START" -v end="$END" -v line="$link_line" '
  skip {
    if (index($0, end)) { skip = 0; print }
    next
  }
  /^[[:space:]]*(`{3,}|~{3,})/ { in_fence = !in_fence; print; next }
  in_fence { print; next }
  index($0, start) { print; print line; skip = 1; next }
  { print }
' "$README_FILE" > "$tmp"

if cmp -s "$tmp" "$README_FILE"; then
  changed=false
  rm -f "$tmp"
else
  mv "$tmp" "$README_FILE"
  changed=true
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "url=${url}"
    echo "changed=${changed}"
    echo "using_placeholder=${using_placeholder}"
  } >> "$GITHUB_OUTPUT"
fi

if [[ "$changed" == true ]]; then
  echo "updated ${README_FILE}: ${link_line}"
else
  echo "no change needed; already ${link_line}"
fi
