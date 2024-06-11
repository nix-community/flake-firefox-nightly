{
  description = "firefox-nightly";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    lib-aggregate = { url = "github:nix-community/lib-aggregate"; };
    cachix = { url = "github:nixos/nixpkgs/nixos-20.09"; };
    mozilla = { url = "github:mozilla/nixpkgs-mozilla"; flake = false; };
    flake-compat = { url = "github:nix-community/flake-compat"; };
  };

  outputs = inputs:
    let
      inherit (inputs.lib-aggregate) lib;
      inherit (inputs) self;
      latestJson = builtins.fromJSON (builtins.readFile ./latest.json);

      mozillaSystemDict = {
        "x86_64-linux" = "linux-x86_64";
        "aarch64-linux" = "linux-aarch64";
      };

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

    in
    lib.flake-utils.eachSystem supportedSystems (system:
      let
        pkgsFor = pkgs: overlays:
          import pkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ (import "${inputs.mozilla}/firefox-overlay.nix") ];
          };

        pkgs_ = lib.genAttrs (builtins.attrNames inputs) (inp: pkgsFor inputs."${inp}" [ ]);

        # get the variants we support from upstream, except filter on not-x86_64-linux
        # as there are no release=true releases published for aarch64-linux, only nightly
        variants =
          let variants = pkgs_.nixpkgs.lib.firefoxOverlay.firefoxVariants; in
            if (system == "x86_64-linux")
            then variants
            else (pkgs_.nixpkgs.lib.filterAttrs (n: v: lib.hasInfix "nightly" n) variants);

        # latest versionInfo outputs for each variant
        # impure, but by design. this is stored/recorded and then used purely
        impureVersionInfos = (builtins.mapAttrs
          (n: v: pkgs_.nixpkgs.lib.firefoxOverlay.versionInfo
            (builtins.trace (v // { system = mozillaSystemDict.${system}; })
            (v // { system = mozillaSystemDict.${system}; })
            )
          )
          (variants)
        );

        latestVersions = (builtins.mapAttrs
          (n: v:
            let
              cv = latestJson.${system}."variants".${n};
              cvi = latestJson.${system}."versionInfo".${n};
            in
            pkgs_.nixpkgs.lib.firefoxOverlay.firefoxVersion (cv // { info = cvi; })
          )
          (variants)
        );


        # https://nixos.org/manual/nixos/unstable/index.html#sec-calling-nixos-tests
        nixos-lib = import (inputs.nixpkgs + "/nixos/lib") { };
        runNixOSTestFor = pkg: nixos-lib.runTest {
          imports = [ ./tests/firefox.nix ];
          hostPkgs = pkgs_.nixpkgs;
          defaults = {
            # reuse the already evaluated nixpkgs
            # https://search.nixos.org/options?channel=unstable&show=nixpkgs.pkgs
            # with 3.9 s without 4.9 s both with a dirty tree
            # `time nix build ".#checks.x86_64-linux.firefox-bin"`
            nixpkgs.pkgs = pkgs_.nixpkgs;
            # Less dependencies
            documentation.enable = false;
          };
          _module.args.firefoxPackage = pkg;
        };

      in
      {
        devShells = {
          default = pkgs_.nixpkgs.mkShell {
            nativeBuildInputs = [ ]
              ++ (with pkgs_.cachix; [ cachix ])
              ++ (with pkgs_.nixpkgs; [
              nixVersions.latest
              nix-prefetch
              nix-build-uncached
              bash
              cacert
              curl
              git
              jq
              mercurial
              nushell
              openssh
              ripgrep
            ])
            ;
          };
        };

        packages = ({
          default = pkgs_.nixpkgs.linkFarm "firefox-variants" [
            { name = "firefox-bin"; path = latestVersions.firefox-bin; }
            { name = "firefox-esr-bin"; path = latestVersions.firefox-esr-bin; }
            { name = "firefox-nightly-bin"; path = latestVersions.firefox-nightly-bin; }
            { name = "firefox-beta-bin"; path = latestVersions.firefox-beta-bin; }
          ];
        } // latestVersions);

        latest = {
          variants = variants;
          versionInfo = impureVersionInfos;
        };

        checks = builtins.mapAttrs (_: value: runNixOSTestFor value) (builtins.removeAttrs self.packages.${system} [ "default" ]);
      });
}
