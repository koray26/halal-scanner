#!/usr/bin/env bash
# Legt die CI-Protokolle in einem eigenen Branch ab, damit sie ohne
# Anmeldung lesbar sind (Build-Protokolle von GitHub erfordern ein Login).
set -euo pipefail
branch="$1"
[ -d ci-logs ] || exit 0
tmp="$(mktemp -d)"
cp -R ci-logs/. "$tmp/"
echo "${GITHUB_SHA:-unknown}" > "$tmp/commit.txt"
cd "$tmp"
git init -q -b "$branch"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A
git commit -q -m "CI-Protokolle für ${GITHUB_SHA:-unknown}"
git push -q -f "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "HEAD:refs/heads/$branch"
