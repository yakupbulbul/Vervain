#!/bin/bash
set -euo pipefail

# Appends one row of numbers to a CSV so growth can be seen over time.
# Usage: scripts/record-stats.sh <history.csv> [owner/repo]
#
# GitHub only keeps the current download count, not a history, so the weekly
# Stats workflow calls this and keeps the file on the `stats` branch.

OUT="${1:?Usage: scripts/record-stats.sh <history.csv> [owner/repo]}"
REPO="${2:-yakupbulbul/Vervain}"

read -r direct homebrew < <(gh api "repos/${REPO}/releases" --paginate --jq '
    [ .[].assets[] ] as $a
    | [ ($a | map(select(.name | endswith("-homebrew.dmg") | not) | .download_count) | add // 0),
        ($a | map(select(.name | endswith("-homebrew.dmg")) | .download_count) | add // 0) ]
    | @tsv')
read -r stars forks < <(gh api "repos/${REPO}" --jq '[.stargazers_count, .forks_count] | @tsv')

[ -s "$OUT" ] || echo "date,direct,homebrew,total,stars,forks" > "$OUT"
echo "$(date -u +%F),${direct},${homebrew},$((direct + homebrew)),${stars},${forks}" >> "$OUT"
tail -1 "$OUT"
