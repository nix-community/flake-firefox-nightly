# flake-firefox-nightly

[![Update](https://github.com/colemickens/flake-firefox-nightly/actions/workflows/update.yaml/badge.svg)](https://github.com/colemickens/flake-firefox-nightly/actions/workflows/update.yaml)

## overview

This is a nix flake that lets you import `firefoxNightly` via flake
in a pinned, safely reproducible manner.

(put another way, this allows flakes --pure-eval + firefox-nightly, which
otherwise is not so possbile)

# Usage

```nix
{ pkgs, inputs, config, ... }:
{
  config = {
    environment.systemPackages = [
      inputs.firefox.packages.${pkgs.system}.firefox-nightly-bin
    ];
  };
}
```

# Warnings

1. The structures of outputs of the flake may change if/when I update to export more of the
   firefox-overlay ouputs. (a breaking change for users potentially)

# Security Warning

Mozilla expects Firefox Nightly users to run with auto-update
mechanisms to ensure they don't wind up stuck on an old nightly build.
Using `nixpkgs-mozilla` already circumvents some of this philosophy by requiring
you to update your system/profile frequently to get new builds.

In some (hopefully minor) sense, this flake exacerbates that problem:

1. It requires users to update their flakes inputs (though this was already
   true for users that were using `niv` etc to pin `nixpkgs-mozilla`).

2. This repo adds up to an hour of lag, since the CI job runs on ~1 hour interval.
   Depending on when you update your inputs, and when the CI job runs, it's possible
   for you to "miss" a newer Nightly build that is actually available.
