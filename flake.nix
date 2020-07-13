{
  description = "firefox-nightly";

  # TODO: should warn whenever flakes are resolved to different versions (names of flakes should match repo names?)
  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    mozilla = { url = "github:colemickens/nixpkgs-mozilla"; flake = false; };
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

      variants = system: {
        firefox-nightly-bin =
          (pkgsFor inputs.nixpkgs system).lib.firefoxOverlay.firefoxVersion (
            metadata.version // { info = metadata.cachedInfo; }
          );
      };
    in
    rec {
      devShell = forAllSystems (system:
        (pkgsFor inputs.nixpkgs system).mkShell {
          nativeBuildInputs = with (pkgsFor inputs.nixpkgs system); [
            nixFlakes bash cacert curl git jq openssh ripgrep
          ];
        }
      );

      latest =
        let
          pkgs = pkgsFor inputs.nixpkgs builtins.currentSystem;
          cachedInfo = pkgs.lib.firefoxOverlay.versionInfo version;
        in
        { inherit version cachedInfo; };

      defaultPackage = forAllSystems (system:
        let
          nixpkgs_ = (pkgsFor inputs.nixpkgs system);
          attrValues = inputs.nixpkgs.lib.attrValues;
        in
        nixpkgs_.symlinkJoin {
          name = "flake-firefox-nightly";
          paths = attrValues (variants system);
        }
      );
    };
}
