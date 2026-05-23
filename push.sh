#!/usr/bin/env bash
set -euo pipefail

MESSAGE="${1:-update}"

git add -A

if git diff --cached --quiet; then
  echo "No changes to commit."
  exit 0
fi

git commit -m "$MESSAGE"
git push origin "$(git branch --show-current)"

echo "=== Changes pushed and GitHub Actions triggered ==="
