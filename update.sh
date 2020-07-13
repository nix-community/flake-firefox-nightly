#! /usr/bin/env nix-shell
#! nix-shell -i bash ./shell.nix
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -euo pipefail
set -x

oldversion="$(cat latest.json | jq -r '.cachedInfo.chksum' |  grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}')"
rm -rf ./.ci/commit-message

nix flake --experimental-features 'nix-command flakes' \
  update \
    --update-input nixpkgs \
    --update-input mozilla

nix --experimental-features 'nix-command flakes' \
  eval --impure '.#latest' --json \
    | jq > latest.json

newversion="$(cat latest.json | jq -r '.cachedInfo.chksum' |  grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}')"

nix --experimental-features 'nix-command flakes' \
  build

readlink -f result | cachix push nixpkgs-wayland

if [[ "${newversion}" != "${oldversion}" ]]; then
  commitmsg="firefox-nightly-bin: ${oldversion} -> ${newversion}"
  echo -e "${commitmsg}" > .ci/commit-message
else
  echo "nothing to do, there was no version bump"
fi
