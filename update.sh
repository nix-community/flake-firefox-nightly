#! /usr/bin/env nix-shell
#! nix-shell -i bash /home/cole/code/nixcfg/shell.nix
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -euo pipefail
set -x

nix flake --experimental-features 'nix-command flakes' \
  update \
    --update-input nixpkgs \
    --update-input mozilla

nix --experimental-features 'nix-command flakes' \
  eval --impure '.#latest' --json \
    | jq > latest.json

nix --experimental-features 'nix-command flakes' \
  build
