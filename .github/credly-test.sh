#!/usr/bin/env bash
# Run: bash .github/credly-test.sh
set -euo pipefail

script="$(dirname "$0")/credly.sh"
readme=$(mktemp)
trap 'rm -f "$readme"' EXIT
original=$'before\n<!-- credly:start -->\nold\n<!-- credly:end -->\nafter'
printf '%s\n' "$original" > "$readme"

badge() { # id name expires state public
  printf '{"id":"%s","image_url":"https://i/%s.png","badge_template":{"name":"%s"},"issued_at_date":"2026-01-0%s","expires_at_date":%s,"state":"%s","public":%s,"is_private_badge":false}' \
    "$1" "$1" "$2" "${1#b}" "$3" "$4" "$5"
}
data="[$(badge b1 'Older' null accepted true),$(badge b2 'Newer & Co' '"2027-01-01"' accepted true),$(badge b3 'Expired' '"2026-06-30"' accepted true),$(badge b4 'Pending' null pending true),$(badge b5 'Hidden' null accepted false)]"

printf '{"metadata":{"total_pages":1},"data":%s}' "$data" | bash "$script" "$readme" 2026-07-01
out=$(cat "$readme")

[[ $out == *'/badges/b1/public_url'* && $out == *'alt="Newer &amp; Co"'* ]] || { echo "FAIL: valid badge missing"; exit 1; }
[[ $out != *b3* && $out != *b4* && $out != *b5* && $out != *old* ]] || { echo "FAIL: filter or stale content"; exit 1; }
[[ $(grep -n b2 "$readme" | cut -d: -f1) -lt $(grep -n b1 "$readme" | cut -d: -f1) ]] || { echo "FAIL: not newest first"; exit 1; }
[[ $out == before* && $out == *after ]] || { echo "FAIL: text outside markers changed"; exit 1; }

# Bad input must fail and keep the README.
for bad in '' '<html>blocked</html>' '{"metadata":{"total_pages":1},"data":[]}' '{"metadata":{"total_pages":2},"data":[]}'; do
  if printf '%s' "$bad" | bash "$script" "$readme" 2026-07-01 2>/dev/null; then echo "FAIL: accepted: $bad"; exit 1; fi
  [[ $(cat "$readme") == "$out" ]] || { echo "FAIL: README changed on: $bad"; exit 1; }
done

echo PASS
