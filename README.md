# flake-firefox-nightly

This is a nix flake that lets you import `firefoxNightly` via flake
in a pinned, safely reproducible manner.

(put another way, this allows flakes --pure-eval + firefox-nightly, which
otherwise is not so possbile)

# NOTE

This effectively pins `firefox-nightly-bin` to what this flake publishes.
This flake will hopefully have CI.

You must `--update-input` this flake often to get newer nightly versions,
for the sake of security updates, etc.

## TODO

1. better docs
2. 
