{
  description = "firefox-nightly";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    #mozilla  = { url = "github:mozilla/nixpkgs-mozilla";     flake = false; };
    mozilla  = { type="path"; path="/home/cole/code/overlays/nixpkgs-mozilla"; flake=false;};
  };

  outputs = inputs:
    let
      metadata = import ./latest.nix;
      
      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      forAllSystems = genAttrs [ "x86_64-linux" "i686-linux" "aarch64-linux" ];

      pkgsFor = pkgs: system:
        import pkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = [
            (import "${inputs.mozilla}/firefox-overlay.nix")
          ];
        };

      curSysPkgs = (pkgsFor inputs.nixpkgs builtins.currentSystem);

      version = {
        name = "Firefox Nightly";
        version = curSysPkgs.lib.firefoxOverlay.firefox_versions.FIREFOX_NIGHTLY;
        release = false;
      };
      
    in rec {
      # this is to be evaluated impurely so that nixpkgs-mozilla
      # can hit the network and determine latest version and hashes
      latest =
        let
          pkgs = pkgsFor inputs.nixpkgs builtins.currentSystem;
          versionInfo = pkgs.lib.firefoxOverlay.versionInfo version;
        in { inherit version versionInfo; };

      # this is expected to be pulled in via flake to user config repos
      # this uses all static imports, so it evaluates purely.
      # this effectively "pins" a nightly version, so users are expected to update
      # often
      defaultPackage = forAllSystems (system:
        let
          pkgs = (pkgsFor inputs.nixpkgs system);
          # TODO: do this for all attributes of nixpkgs-mozilla's overlay
          # ()
          firefox-nightly-bin =
            pkgs.lib.firefoxOverlay.firefoxVersion {
              version = metadata.version;
              versionInfoStatic = metadata.versionInfo;
            };
        in
          firefox-nightly-bin
      );
    };
}
