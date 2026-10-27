#!/bin/bash
set -euo pipefail

# How many people have downloaded Vervain, from numbers GitHub already keeps.
# Nothing is added to the app or the website: no analytics, no tracking.
#
# Usage: scripts/stats.sh [owner/repo]
# Needs the GitHub CLI (`gh auth login`) with access to the repository.
#
# Notes
# - Download counts include `brew install`, because Homebrew downloads the same DMG.
# - A download is not a launch. Vervain does not report usage, so this script
#   cannot tell how many people use it, only how many fetched it.
# - GitHub only keeps 14 days of traffic. Run this now and then if you want a longer history.

REPO="${1:-yakupbulbul/Vervain}"
command -v gh >/dev/null || { echo "Error: gh not found. Install: brew install gh"; exit 1; }

echo "Downloads per release (${REPO})"
gh api "repos/${REPO}/releases" --paginate --jq '.[] | [.tag_name, ([.assets[].download_count] | add // 0)] | @tsv' \
    | awk -F'\t' '{ printf "  %-10s %6d\n", $1, $2; total += $2 } END { printf "  %-10s %6d\n", "total", total }'

echo
echo "Repository"
gh api "repos/${REPO}" --jq '"  stars \(.stargazers_count)   forks \(.forks_count)   open issues \(.open_issues_count)"'

echo
echo "Last 14 days (needs push access)"
if gh api "repos/${REPO}/traffic/views" --jq '"  page views \(.count) (\(.uniques) unique)"' 2>/dev/null; then
    gh api "repos/${REPO}/traffic/clones" --jq '"  clones     \(.count) (\(.uniques) unique)"' 2>/dev/null || true
    echo "  top referrers"
    gh api "repos/${REPO}/traffic/popular/referrers" --jq '.[] | "    \(.referrer)  \(.count) (\(.uniques) unique)"' 2>/dev/null || true
else
    echo "  not available for this account"
fi
