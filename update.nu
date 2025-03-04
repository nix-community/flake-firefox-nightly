#!/usr/bin/env nu
print -e $"::group::flake-lock-update"
do {
  nix flake lock --commit-lock-file
}
print -e $"::endgroup::"

print -e $"::group::firefox-update"
let commitmsg = do {
  let oldversion = (cat latest.json | jq -r '."linux-x86_64".nightly.date')
  
  print -e $"::notice ::oldversion=($oldversion)"

  ./generate.nu
  
  let newversion = (cat latest.json | jq -r '."linux-x86_64".nightly.date')

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
