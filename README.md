# flake-firefox-nightly

[![builds.sr.ht status](https://builds.sr.ht/~colemickens/flake-firefox-nightly.svg)](https://builds.sr.ht/~colemickens/flake-firefox-nightly?)

This is a nix flake that outputs Firefox builds, including a 
pinnable Nightly build, suitable for use in a flake-built pure-eval'd system.

- [flake-firefox-nightly](#flake-firefox-nightly)
  - [Experimental! Warnings!](#experimental-warnings)
  - [Packages](#packages)
    - [Firefox Nightly](#firefox-nightly)
    - [Firefox (with Pipewire)](#firefox-with-pipewire)
    - [Security Warning](#security-warning)

## Experimental! Warnings!

1. This uses my fork of nixpkgs-mozilla, pending this PR: https://github.com/mozilla/nixpkgs-mozilla/pull/230.
2. This flake will likely be renamed to **nixos-firefox-apps**.
3. This flake's binary cache will likely be changed.
4. The flake outputs may change slightly.


## Packages

### Firefox Nightly
* package: **`firefox-nightly-bin`**
* this build is re-determined every half-hour, so that the pinned build is as
  new as possible

### Firefox (with Pipewire)
* package: **`firefox-pipewire`**
* These builds are meant for `wlroots` users who can leverage XDG Portals and 
 [`xdg-portal-wlroots`]() to get native screensharing with Firefox in Wayland,
 for compositors supporting the relevant wlroots protocol.
* This package is exactly `nixpkgs.firefox` with Fedora's `pipewire-0.3` patch applied, courtesy of [@calbrecht](https://github.com/calbrecht/nixpkgs-overlays). (In our flake, nixpkgs is `nixos-unstable`, so you will get a pipewire-enabled build at whatever version Firefox is at in the `nixos-unstable` channel.)
* Example with  nixos + home-manager configuration:
  
  `flake.nix`:
  ```nix
  # add nixos-firefox-apps as 'firefox' to flake inputs:
  {
      inputs = {
        nixpkgs  = { url = "github:colemickens/nixpkgs/cmpkgs"; };
        # ...
        firenight  = { url = "github:colemickens/flake-firefox-nightly"; };
        firenight.inputs.nixpkgs.follows = "nixpkgs";
        # ...
      };
      # ...
  }
  ```
  `configuration.nix`:
  ```nix
  { pkgs, lib, config, inputs, ... }:

  let firefox-pipewire =
    # I keep firefox-pipewire as a separate binary in $PATH.
    firefoxPipewire = pkgs.writeShellScriptBin "firefox-pipewire" ''
      exec ${firefoxFlake.firefox-pipewire}/bin/firefox "''${@}"
    '';
  in
  {
    config = {
      services.pipewire.enable = true;
      xdg.portal.enable = true;
      xdg.portal.gtkUsePortal = true;
      xdg.portal.extraPortals = with pkgs;
        [ xdg-desktop-portal-wlr xdg-desktop-portal-gtk ];
      home-manager.users.cole = { pkgs, ... }: {
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "sway";
      };
      home.packages = [ firefoxPipewire ];
    };
  }
  ```

### Security Warning

In theory, this flake could lag behind an official nightly release by up to
30 minutes (that's our update interval).
