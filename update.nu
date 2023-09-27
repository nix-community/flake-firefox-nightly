#!/usr/bin/env nu

let DIR = ($env.FILE_PWD)
let cache = "nixpkgs-wayland"

print -e $"::group::flake-lock-update"
do {
  nix flake lock --recreate-lock-file --commit-lock-file
}
print -e $"::endgroup::"

print -e $"::group::firefox-update"
let commitmsg = do {
  let oldversion = (cat latest.json
    | jq -r '.["x86_64-linux"].versionInfo["firefox-nightly-bin"].chksum'
    | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}')
  
  print -e $"::notice ::oldversion=($oldversion)"
  
  rm latest.json
  nix eval --impure '.#latest' --json | jq out> latest.json
  
  let newversion = (cat latest.json
    | jq -r '.["x86_64-linux"].versionInfo["firefox-nightly-bin"].chksum'
    | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}')
  
  print -e $"::notice ::newversion=($newversion)"

  $"firefox-nightly-bin: ($oldversion) -> ($newversion)"
}
print -e "::endgroup::"

print -e $"::group::nix-build"
do {
  nix build . --keep-going -L
}
print -e $"::endgroup::"

print -e $"::group::nix-flake-check"
try {
  nix flake check --keep-going -j1 -L
  print -e $"::notice ::nix flake check = pass"
} catch {
  print -e $"::warning ::nix flake check = FAIL"
}
print -e $"::endgroup::"

print -e $"::group::git-commit-push"
if ("GITHUB_ACTIONS" in $env) {
  print -e $"::notice ::commitmsg=($commitmsg)"
  do -i {
    git commit ./latest.json -m $commitmsg
    git push origin HEAD
  }
} else {
  print -e $"skipping git actions, we're not running in GitHub Actions"
}
print -e $"::endgroup::"
