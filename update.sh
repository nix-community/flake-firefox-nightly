#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -euo pipefail
set -x

cache="nixpkgs-wayland"

oldversion="$(cat latest.json | jq -r '.cachedInfo.chksum' |  grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}')"
rm -rf ./.ci/commit-message

nix flake --experimental-features 'nix-command flakes' \
  update \
    --update-input master \
    --update-input nixpkgs \
    --update-input mozilla \
    --update-input cachixpkgs

nix --experimental-features 'nix-command flakes' \
  eval --impure '.#latest' --json \
    | jq > latest.json

newversion="$(cat latest.json | jq -r '.cachedInfo.chksum' |  grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}')"

out="$(mktemp -d)"
nix-build-uncached \
  --option "extra-binary-caches" "https://cache.nixos.org https://nixpkgs-wayland.cachix.org" \
  --option "trusted-public-keys" "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA=" \
  --option "build-cores" "0" \
  --option "narinfo-cache-negative-ttl" "0" \
  --out-link "${out}/result" packages.nix
results=(); shopt -s nullglob
for f in ${out}/result*; do
  results=("${results[@]}" "${f}")
done
echo "${results[@]}" | cachix push "${cache}"

if [[ "${newversion}" != "${oldversion}" ]]; then
  commitmsg="firefox-nightly-bin: ${oldversion} -> ${newversion}"
  echo -e "${commitmsg}" > .ci/commit-message
else
  echo "nothing to do, there was no version bump"
fi
