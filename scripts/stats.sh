#!/bin/bash
set -euo pipefail

# How many people have downloaded Vervain, from numbers GitHub already keeps.
# Nothing is added to the app or the website: no analytics, no tracking.
#
# Usage: scripts/stats.sh [owner/repo]
# Needs the GitHub CLI (`gh auth login`) with access to the repository.
#
# Notes
# - Releases from 2.0.0 on carry a second, identical DMG named *-homebrew.dmg that only
#   Homebrew downloads, so brew installs and direct downloads are counted apart. Older
#   releases only have one file, so their numbers are all in the "direct" column.
# - A download is not a launch. Vervain does not report usage, so this script
#   cannot tell how many people use it, only how many fetched it.
# - GitHub only keeps 14 days of traffic. Run this now and then if you want a longer history.

REPO="${1:-yakupbulbul/Vervain}"
command -v gh >/dev/null || { echo "Error: gh not found. Install: brew install gh"; exit 1; }

echo "Downloads per release (${REPO})"
echo "  release    direct  homebrew    total"
gh api "repos/${REPO}/releases" --paginate --jq '
    .[] | [.tag_name,
           ([.assets[] | select(.name | endswith("-homebrew.dmg") | not) | .download_count] | add // 0),
           ([.assets[] | select(.name | endswith("-homebrew.dmg")) | .download_count] | add // 0)] | @tsv' \
    | awk -F'\t' '{ printf "  %-9s %7d %9d %8d\n", $1, $2, $3, $2 + $3; d += $2; h += $3 }
                  END { printf "  %-9s %7d %9d %8d\n", "total", d, h, d + h }'

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
