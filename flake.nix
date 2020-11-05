{
  description = "firefox-nightly";

  # TODO: should warn whenever flakes are resolved to different versions (names of flakes should match repo names?)
  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    cmpkgs = { url = "github:colemickens/nixpkgs/cmpkgs"; };# TODO: remove
    cachixpkgs = { url = "github:nixos/nixpkgs/nixos-20.09"; };
    mozilla = { url = "github:colemickens/nixpkgs-mozilla"; flake = false; };
  };

  outputs = inputs:
    let
      metadata = builtins.fromJSON (builtins.readFile ./latest.json);

      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = genAttrs supportedSystems;

      pkgsFor = pkgs: system:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ (import "${inputs.mozilla}/firefox-overlay.nix") ];
        };
      pkgs_ = genAttrs (builtins.attrNames inputs) (inp: genAttrs supportedSystems (sys: pkgsFor inputs."${inp}" sys));

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
        pkgs_.nixpkgs.${system}.mkShell {
          nativeBuildInputs = []
            ++ (with pkgs_.cachixpkgs.${system}; [ cachix ])
            ++ (with pkgs_.nixpkgs.${system}; [ bash cacert curl git jq mercurial openssh ripgrep ])
            ++ (with pkgs_.cmpkgs.${system}; [ nixUnstable nix-prefetch nix-build-uncached ])
          ;
        }
      );

      packages = forAllSystems (system: variants system);

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
