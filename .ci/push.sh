#!/usr/bin/env bash
set -euo pipefail
set -x

if [[ ! -f ./.ci/commit-message ]]; then
  echo "nothing to push"
  exit 0
fi

ssh-keyscan github.com >> ${HOME}/.ssh/known_hosts

git status
git add -A .
git status
git diff-index --cached --quiet HEAD || git commit -m "$(cat .ci/commit-message)"
git push origin HEAD
