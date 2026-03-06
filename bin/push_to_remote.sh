#!/usr/bin/env bash
set -euo pipefail

# Usage: ./bin/push_to_remote.sh <REMOTE_URL>
# Example SSH: ./bin/push_to_remote.sh git@github.com:<YOUR_USERNAME>/static_site.git
# Example HTTPS: ./bin/push_to_remote.sh https://github.com/<YOUR_USERNAME>/static_site.git

REMOTE_URL="${1:-}" 
if [[ -z "${REMOTE_URL}" ]]; then
  echo "[usage] ./bin/push_to_remote.sh <REMOTE_URL>" >&2
  echo "  e.g. git@github.com:<USER>/static_site.git or https://github.com/<USER>/static_site.git" >&2
  exit 1
fi

# Go to repo root
cd "$(dirname "$0")/.."

# Ensure git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[err] Not inside a git repository" >&2
  exit 2
fi

# Ensure user config
if ! git config user.name >/dev/null; then
  git config user.name "dailygh"
fi
if ! git config user.email >/dev/null; then
  git config user.email "dailygh@example.com"
fi

# Ensure branch main
CURRENT_BRANCH="$(git branch --show-current || true)"
if [[ -z "${CURRENT_BRANCH}" || "${CURRENT_BRANCH}" != "main" ]]; then
  git checkout -B main
fi

# Stage and commit if changes exist
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "chore: update static site"
else
  echo "[info] No changes to commit"
fi

# Set origin remote
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "${REMOTE_URL}"
else
  git remote add origin "${REMOTE_URL}"
fi

# Push
echo "[push] -> ${REMOTE_URL} (branch: main)"
git push -u origin main

echo "[done] Pushed to remote. Configure Cloudflare Pages to connect to this repo."