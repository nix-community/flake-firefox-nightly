{
  description = "firefox-nightly";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
    lib-aggregate.url = "github:nix-community/lib-aggregate";
    flake-compat.url = "github:nix-community/flake-compat";
  };

  outputs =
    inputs:
    let
      inherit (inputs.lib-aggregate) lib;
      versions = builtins.fromJSON (builtins.readFile ./latest.json);

      overlay =
        final: prev:
        let
          mkFirefox =
            {
              branch,
              name,
              channel ? "release",
            }:
            let
              inherit (final.stdenv.hostPlatform) system;

              # map nixpkgs systems to mozilla
              mozSystem =
                {
                  "x86_64-linux" = "linux-x86_64";
                  "aarch64-linux" = "linux-aarch64";
                }
                .${system};

              data = versions.${mozSystem}.${branch};

              unwrapped =
                if isNull data then
                  throw "${name} is not available on ${system}!"
                else
                  final.callPackage (import ./package.nix {
                    inherit name branch;
                    version = data.version;
                    src = final.fetchurl {
                      inherit (data) url hash;
                    };
                  }) { };
            in
            final.wrapFirefox unwrapped ({
              pname = "${unwrapped.binaryName}-bin";
            });
        in
        {
          firefox-bin = mkFirefox {
            branch = "release";
            name = "Firefox";
          };

          firefox-esr-bin = mkFirefox {
            branch = "esr";
            name = "Firefox ESR";
          };

          firefox-beta-bin = mkFirefox {
            branch = "beta";
            name = "Firefox Beta";
            channel = "beta";
          };

          firefox-devedition-bin = mkFirefox {
            branch = "devedition";
            name = "Firefox Developer Edition";
            channel = "developer-edition";
          };

          firefox-nightly-bin = mkFirefox {
            branch = "nightly";
            name = "Firefox Nightly";
            channel = "nightly";
          };
        };

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

    in
    {
      overlays.default = overlay;
    }
    // (lib.flake-utils.eachSystem supportedSystems (
      system:
      let
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        firefoxPkgs = overlay pkgs pkgs;

        # https://nixos.org/manual/nixos/unstable/index.html#sec-calling-nixos-tests
        runNixOSTestFor =
          pkg:
          pkgs.testers.runNixOSTest {
            imports = [ ./tests/firefox.nix ];
            defaults = {
              # Less dependencies
              documentation.enable = false;
            };
            _module.args.firefoxPackage = pkg;
          };
      in
      {
        devShells = {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              cachix
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
            ];
          };
        };

        packages = firefoxPkgs // {
          default = pkgs.linkFarm "firefox-variants" (
            lib.mapAttrsToList (name: value: {
              inherit name;
              path = value;
            }) firefoxPkgs
          );
        };

        checks = builtins.mapAttrs (_: value: runNixOSTestFor value) firefoxPkgs;
      }
    ));
}
