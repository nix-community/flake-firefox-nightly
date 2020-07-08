{
  description = "firefox-nightly";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    master = { url = "github:nixos/nixpkgs/master"; }; # (for nixFlakes)
    mozilla  = { url = "github:colemickens/nixpkgs-mozilla"; flake = false; };
  };

  outputs = inputs:
    let
      metadata = builtins.fromJSON (builtins.readFile ./latest.json);
      
      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      forAllSystems = genAttrs [ "x86_64-linux" "i686-linux" "aarch64-linux" ];

      pkgsFor = pkgs: system:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ (import "${inputs.mozilla}/firefox-overlay.nix") ];
        };

      # impure, but that's by design
      sysPkgs = (pkgsFor inputs.nixpkgs builtins.currentSystem);
      version = {
        name = "Firefox Nightly";
        version = sysPkgs.lib.firefoxOverlay.firefox_versions.FIREFOX_NIGHTLY;
        release = false;
      };      
    in rec {
      devShell = forAllSystems (system:
        (pkgsFor inputs.nixpkgs system).mkShell {
          nativeBuildInputs = with (pkgsFor inputs.nixpkgs system); [ # TODO: "legacy" packages, why?
            (pkgsFor inputs.master system).nixFlakes
            bash cacert curl git jq openssh ripgrep
          ];
        }
      );

      latest =
        let
          pkgs = pkgsFor inputs.nixpkgs builtins.currentSystem;
          cachedInfo = pkgs.lib.firefoxOverlay.versionInfo version;
        in { inherit version cachedInfo; };

      defaultPackage = forAllSystems (system:
        (pkgsFor inputs.nixpkgs system).lib.firefoxOverlay.firefoxVersion {
          version = metadata.version // { info = metadata.cachedInfo; };
        }
      );
    };
}
