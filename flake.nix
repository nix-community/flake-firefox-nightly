{
  description = "firefox-nightly";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    cachix = { url = "github:nixos/nixpkgs/nixos-20.09"; };
    mozilla = { url = "github:mozilla/nixpkgs-mozilla"; flake = false; };
    flake-compat = { url = "github:nix-community/flake-compat"; };
  };

  outputs = inputs:
    let
      metadata = builtins.fromJSON (builtins.readFile ./latest.json);

      xarch = {
        "x86_64-linux" = "linux-x86_64";
        "aarch64-linux" = "linux-aarch64"; # TODO: doesn't work since Moz doesn't publish 'em
      };

      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      # supportedSystems = [ "x86_64-linux" "aarch64-linux" ]; # TODO: still not there
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = genAttrs supportedSystems;

      pkgsFor = pkgs: system:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ (import "${inputs.mozilla}/firefox-overlay.nix") ];
        };
      pkgs_ = genAttrs (builtins.attrNames inputs) (inp: genAttrs supportedSystems (sys: pkgsFor inputs."${inp}" sys));

      fv = system: pkgs_.nixpkgs.${system}.lib.firefoxOverlay.firefoxVariants;
      variants = system: (builtins.mapAttrs
        (n: v:
          let
            cv = metadata.${system}."variants".${n};
            cvi = metadata.${system}."versionInfo".${n};
          in
            pkgs_.nixpkgs."${system}".lib.firefoxOverlay.firefoxVersion (cv // { info = cvi; })
        )
        (fv system)
      );

      # latest versionInfo outputs for each variant
      # impure, but by design. this is stored/recorded and then used purely
      impureVariants = system: (
        (pkgs_.nixpkgs."${system}".lib.firefoxOverlay.firefoxVariants)
      );
      impureVersionInfos = system: (builtins.mapAttrs
        (n: v: pkgs_.nixpkgs."${system}".lib.firefoxOverlay.versionInfo (v // { system = xarch.${system};}))
        (fv system)
      );

      # https://nixos.org/manual/nixos/unstable/index.html#sec-calling-nixos-tests
      nixos-lib = import (inputs.nixpkgs + "/nixos/lib") { };
      runNixOSTestFor = system: pkg: nixos-lib.runTest {
        imports = [ ./tests/firefox.nix ];
        hostPkgs = pkgs_.nixpkgs."${system}";
        defaults = {
          nixpkgs.pkgs = pkgs_.nixpkgs."${system}";
          # Less dependencies
          documentation.enable = false;
        };
        _module.args.firefoxPackage = pkg;
      };

    in
    rec {
      devShell = forAllSystems (system:
        pkgs_.nixpkgs.${system}.mkShell {
          nativeBuildInputs = []
            ++ (with pkgs_.cachix.${system}; [ cachix ])
            ++ (with pkgs_.nixpkgs.${system}; [
                nixUnstable nix-prefetch nix-build-uncached
                bash cacert curl git jq mercurial openssh ripgrep
            ])
          ;
        }
      );

      packages = forAllSystems (system: variants system);

      latest = forAllSystems (system: {
        variants = impureVariants system;
        versionInfo = impureVersionInfos system;
      });

      defaultPackage = forAllSystems (system:
        pkgs_.nixpkgs."${system}".symlinkJoin {
          name = "flake-firefox-nightly";
          paths = builtins.attrValues (variants system);
        }
      );

      checks = forAllSystems (system:
        builtins.mapAttrs (_: value: runNixOSTestFor system value ) packages.${system}
      );
    };
}
