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
      metadata = builtins.fromJSON (builtins.readFile ./latest.json);

      mozillaSystemDict = {
        "x86_64-linux" = "linux-x86_64";
        "aarch64-linux" = "linux-aarch64"; # TODO: doesn't work since Moz doesn't publish 'em
      };

      # supportedSystems = [ "x86_64-linux" "aarch64-linux" ]; # TODO: still not there
      supportedSystems = [ "x86_64-linux" ];

    in
    lib.flake-utils.eachSystem supportedSystems (system: let
      pkgsFor = pkgs: overlays:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ (import "${inputs.mozilla}/firefox-overlay.nix") ];
        };

      pkgs_ = lib.genAttrs (builtins.attrNames inputs) (inp: pkgsFor inputs."${inp}" [ ]);

      fv = pkgs_.nixpkgs.lib.firefoxOverlay.firefoxVariants;
      variants = (builtins.mapAttrs
        (n: v:
          let
            cv = metadata.${system}."variants".${n};
            cvi = metadata.${system}."versionInfo".${n};
          in
            pkgs_.nixpkgs.lib.firefoxOverlay.firefoxVersion (cv // { info = cvi; })
        )
        (fv)
      );

      # latest versionInfo outputs for each variant
      # impure, but by design. this is stored/recorded and then used purely
      impureVariants =
        (pkgs_.nixpkgs.lib.firefoxOverlay.firefoxVariants);

      impureVersionInfos = (builtins.mapAttrs
        (n: v: pkgs_.nixpkgs.lib.firefoxOverlay.versionInfo (v // { system = mozillaSystemDict.${system};}))
        (fv)
      );

      # https://nixos.org/manual/nixos/unstable/index.html#sec-calling-nixos-tests
      nixos-lib = import (inputs.nixpkgs + "/nixos/lib") { };
      runNixOSTestFor = pkg: nixos-lib.runTest {
        imports = [ ./tests/firefox.nix ];
        hostPkgs = pkgs_.nixpkgs;
        defaults = {
          nixpkgs.pkgs = pkgs_.nixpkgs;
          # Less dependencies
          documentation.enable = false;
        };
        _module.args.firefoxPackage = pkg;
      };

    in {
      devShell = pkgs_.nixpkgs.mkShell {
        nativeBuildInputs = []
          ++ (with pkgs_.cachix; [ cachix ])
          ++ (with pkgs_.nixpkgs; [
              nixUnstable nix-prefetch nix-build-uncached
              bash cacert curl git jq mercurial openssh ripgrep
          ])
        ;
      };

      packages = variants;

      latest = {
        variants = impureVariants;
        versionInfo = impureVersionInfos;
      };

      defaultPackage = pkgs_.nixpkgs.symlinkJoin {
          name = "flake-firefox-nightly";
          paths = builtins.attrValues (variants);
      };

      checks = builtins.mapAttrs (_: value: runNixOSTestFor value ) self.packages.${system};
    });
}
