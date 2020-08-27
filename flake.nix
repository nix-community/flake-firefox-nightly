{
  description = "firefox-nightly";

  # TODO: should warn whenever flakes are resolved to different versions (names of flakes should match repo names?)
  inputs = {
    master = { url = "github:nixos/nixpkgs/master"; };
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    cachixpkgs = { url = "github:nixos/nixpkgs/nixos-20.03"; };
    mozilla = { url = "github:colemickens/nixpkgs-mozilla"; flake = false; };
    flake-utils = { url = "github:numtide/flake-utils"; }; # TODO: adopt this
  };

  outputs = inputs:
    let
      fv = system: {
        # TODO: move to nixpkgs-mozilla and de-dupe
        firefox-nightly-bin = {
          name = "Firefox Nightly";
          version = (pkgsFor inputs.nixpkgs system).lib.firefoxOverlay.firefox_versions.FIREFOX_NIGHTLY;
          release = false;
        };
        firefox-beta-bin = {
          name = "Firefox Beta";
          version = (pkgsFor inputs.nixpkgs system).lib.firefoxOverlay.firefox_versions.LATEST_FIREFOX_DEVEL_VERSION;
          release = true;
        };
        firefox-bin = {
          name = "Firefox";
          version = (pkgsFor inputs.nixpkgs system).lib.firefoxOverlay.firefox_versions.LATEST_FIREFOX_VERSION;
          release = true;
        };
        firefox-esr-bin = {
          name = "Firefox Esr";
          version = (pkgsFor inputs.nixpkgs system).lib.firefoxOverlay.firefox_versions.FIREFOX_ESR;
          release = true;
        };
      };

      metadata = system: builtins.fromJSON (builtins.readFile (./. + "/latest.${system}.json"));

      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      forAllSystems = genAttrs [ "x86_64-linux" "i686-linux" "aarch64-linux" ];

      pkgsFor = pkgs: system:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ (import "${inputs.mozilla}/firefox-overlay.nix") ];
        };

      variants = system: inputs.nixpkgs.lib.mapAttrs (k: v: 
        (pkgsFor inputs.nixpkgs system).lib.firefoxOverlay.firefoxVersion (
          (metadata system)."${k}".version
            // { info = (metadata system)."${k}".cachedInfo; }
        )
      ) (fv system);
    in
    rec {
      devShell =
       forAllSystems (system:
        let 
          master_ = pkgsFor inputs.master system;
          nixpkgs_ = pkgsFor inputs.nixpkgs system;
          cachixpkgs_ = pkgsFor inputs.cachixpkgs system;
        in nixpkgs_.mkShell {
          nativeBuildInputs = with nixpkgs_; [
            bash cacert curl git jq openssh ripgrep
            cachixpkgs_.cachix
            master_.nixFlakes
            master_.nix-build-uncached
          ];
        }
      );

      packages = forAllSystems (system:
        let
          nixpkgs_ = (pkgsFor inputs.nixpkgs system);
          attrValues = inputs.nixpkgs.lib.attrValues;
          out = (variants system);
        in out
      );

      latest = inputs.nixpkgs.lib.mapAttrs (k: v:
        let
          pkgs = pkgsFor inputs.nixpkgs builtins.currentSystem;
        in
        {
          version = v;
          cachedInfo = pkgs.lib.firefoxOverlay.versionInfo v;
        }
      ) (fv builtins.currentSystem);

      # defaultPackage = forAllSystems (system:
      #   let
      #     nixpkgs_ = (pkgsFor inputs.nixpkgs system);
      #     attrValues = inputs.nixpkgs.lib.attrValues;
      #   in
      #   nixpkgs_.symlinkJoin {
      #     name = "flake-firefox-nightly";
      #     paths = attrValues (variants system);
      #   }
      # );
    };
}
