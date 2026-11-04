#!/usr/bin/env bash
# Rewrites the Credly block in a README from Credly's badges JSON on stdin.
# Usage: curl -fsS .../badges.json | credly.sh README.md [YYYY-MM-DD]
# Any bad input exits non-zero and leaves the README untouched.
set -euo pipefail

readme=$1
today=${2:-$(date -u +%F)}

# ponytail: one page only (Credly returns 48 per page); add paging past 48 badges.
html=$(jq -er --arg today "$today" '
  if .metadata.total_pages > 1 then error("more than one page of badges") else . end
  | [.data[]
     | select(.state == "accepted" and .public and (.is_private_badge | not))
     | select((.expires_at_date // "9999-12-31") >= $today)]
  | if length == 0 then error("no badges to show") else . end
  | sort_by([.issued_at_date, .badge_template.name]) | reverse
  | map(@html "<a href=\"https://www.credly.com/badges/\(.id)/public_url\"><img src=\"\(.image_url)\" alt=\"\(.badge_template.name)\" title=\"\(.badge_template.name)\" width=\"80\" /></a>")
  | join("\n")
')

if ! grep -q '<!-- credly:start -->' "$readme" || ! grep -q '<!-- credly:end -->' "$readme"; then
  echo "credly markers missing in $readme" >&2
  exit 1
fi

tmp=$(mktemp)
HTML=$html awk '
  /<!-- credly:start -->/ { print; print ENVIRON["HTML"]; skip = 1; next }
  /<!-- credly:end -->/ { skip = 0 }
  !skip
' "$readme" > "$tmp"
cat "$tmp" > "$readme"
rm -f "$tmp"
