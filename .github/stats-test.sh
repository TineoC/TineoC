#!/usr/bin/env bash
# Run: bash .github/stats-test.sh
set -euo pipefail

script="$(dirname "$0")/stats.sh"
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

page() { # stars lang size
  printf '{"data":{"user":{"name":"A & B","contributionsCollection":{"totalCommitContributions":7},"pullRequests":{"totalCount":8},"issues":{"totalCount":9},"repositoriesContributedTo":{"totalCount":3},"repositories":{"nodes":[{"stargazerCount":%s,"languages":{"edges":[{"size":%s,"node":{"name":"%s","color":null}}]}}]}}}}' "$1" "$3" "$2"
}

{ page 2 'C++' 75; page 3 Go 25; } | bash "$script" "$dir"
stats=$(cat "$dir/stats.svg"); langs=$(cat "$dir/langs.svg")

[[ $stats == *'>Total stars</text>'*'>5</text>'* ]] || { echo "FAIL: stars not summed across pages"; exit 1; }
[[ $stats == *'A &amp; B'* ]] || { echo "FAIL: name not escaped"; exit 1; }
[[ $langs == *'C++ 75%'* && $langs == *'Go 25%'* ]] || { echo "FAIL: language percent"; exit 1; }
[[ $langs == *'#7aa2f7'* ]] || { echo "FAIL: null color fallback"; exit 1; }

# Bad input must fail and keep the cards.
for bad in '' '<html>' '{"data":{"user":null}}'; do
  if printf '%s' "$bad" | bash "$script" "$dir" 2>/dev/null; then echo "FAIL: accepted: $bad"; exit 1; fi
  [[ $(cat "$dir/stats.svg") == "$stats" ]] || { echo "FAIL: card changed on: $bad"; exit 1; }
done

echo PASS
