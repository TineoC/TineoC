#!/usr/bin/env bash
# Writes stats.svg and langs.svg from paginated GraphQL JSON on stdin.
# Usage: gh api graphql --paginate -F query=@.github/stats.graphql -f login=NAME | stats.sh OUTDIR
# Bad input exits non-zero and leaves existing cards untouched.
set -euo pipefail

outdir=$1
json=$(jq -es '
  . as $pages
  | $pages[0].data.user as $u
  | if $u == null then error("no user in response") else . end
  | ($pages | map(.data.user.repositories.nodes) | add) as $repos
  | ($repos | map(.languages.edges[])
     | group_by(.node.name)
     | map({name: .[0].node.name, color: (.[0].node.color // "#7aa2f7"), size: (map(.size) | add)})
     | sort_by(-.size) | .[:6]) as $langs
  | {
      name: $u.name,
      rows: [
        ["Total stars", ($repos | map(.stargazerCount) | add // 0)],
        ["Commits (last year)", $u.contributionsCollection.totalCommitContributions],
        ["Pull requests", $u.pullRequests.totalCount],
        ["Issues", $u.issues.totalCount],
        ["Contributed to", $u.repositoriesContributedTo.totalCount]
      ],
      langs: $langs,
      total: ($langs | map(.size) | add // 0)
    }
  | if .total == 0 then error("no language data") else . end
')

stats=$(jq -r '
  (.rows | to_entries | map(
    @html "<text x=\"25\" y=\"\(70 + .key * 24)\" fill=\"#38bdae\" font-size=\"14\" font-weight=\"600\">\(.value[0])</text><text x=\"470\" y=\"\(70 + .key * 24)\" fill=\"#38bdae\" font-size=\"14\" font-weight=\"700\" text-anchor=\"end\">\(.value[1])</text>"
  ) | join("")) as $rows
  | (@html "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"495\" height=\"195\" viewBox=\"0 0 495 195\" role=\"img\" aria-label=\"GitHub stats for \(.name)\" font-family=\"Segoe UI,Ubuntu,Helvetica,Arial,sans-serif\"><rect width=\"495\" height=\"195\" rx=\"8\" fill=\"#1a1b27\"/><text x=\"25\" y=\"36\" fill=\"#70a5fd\" font-size=\"18\" font-weight=\"600\">GitHub Stats</text>") + $rows + "</svg>"
' <<<"$json")

langs=$(jq -r '
  .total as $total
  | (reduce (.langs[] | . + {width: (445 * .size / $total)}) as $l ({x: 25, out: ""};
      .out += (@html "<rect x=\"\(.x)\" y=\"52\" width=\"\($l.width)\" height=\"10\" fill=\"\($l.color)\"/>")
      | .x += $l.width) | .out) as $bar
  | (.langs | to_entries | map(
      (25 + (.key % 2) * 235) as $x | (90 + ((.key / 2 | floor) * 30)) as $y
      | ((.value.size * 1000 / $total | round) / 10) as $pct
      | @html "<circle cx=\"\($x + 5)\" cy=\"\($y - 5)\" r=\"5\" fill=\"\(.value.color)\"/><text x=\"\($x + 18)\" y=\"\($y)\" fill=\"#38bdae\" font-size=\"13\">\(.value.name) \($pct)%</text>"
    ) | join("")) as $legend
  | "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"495\" height=\"195\" viewBox=\"0 0 495 195\" role=\"img\" aria-label=\"Most used languages\" font-family=\"Segoe UI,Ubuntu,Helvetica,Arial,sans-serif\"><rect width=\"495\" height=\"195\" rx=\"8\" fill=\"#1a1b27\"/><text x=\"25\" y=\"36\" fill=\"#70a5fd\" font-size=\"18\" font-weight=\"600\">Most Used Languages</text>" + $bar + $legend + "</svg>"
' <<<"$json")

mkdir -p "$outdir"
printf '%s\n' "$stats" > "$outdir/stats.svg"
printf '%s\n' "$langs" > "$outdir/langs.svg"
