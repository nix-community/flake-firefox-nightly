# This is a somewhat stripped down version of the firefox-bin expression from nixpkgs,
# modified for our purposes (slightly more extensible, a lot less Darwin).
{
  name,
  version,
  src,
  branch,
}:
{
  lib,
  stdenv,
  fetchurl,
  config,
  wrapGAppsHook3,
  autoPatchelfHook,
  alsa-lib,
  curl,
  dbus-glib,
  gtk3,
  libXtst,
  pciutils,
  pipewire,
  adwaita-icon-theme,
  writeText,
  patchelfUnstable, # have to use patchelfUnstable to support --no-clobber-old-sections
}:

let
  policies = {
    DisableAppUpdate = true;
  } // config.firefox.policies or { };

  policiesJson = writeText "firefox-policies.json" (builtins.toJSON { inherit policies; });

  binaryName = "firefox-${branch}";
in

stdenv.mkDerivation {
  pname = "firefox-${branch}-bin-unwrapped";

  inherit src version;

  nativeBuildInputs = [
    wrapGAppsHook3
    autoPatchelfHook
    patchelfUnstable
  ];

  buildInputs = [
    gtk3
    adwaita-icon-theme
    alsa-lib
    dbus-glib
    libXtst
  ];

  runtimeDependencies = [
    curl
    pciutils
  ];

  appendRunpaths = [
    "${pipewire}/lib"
  ];

  # Firefox uses "relrhack" to manually process relocations from a fixed offset
  patchelfFlags = [ "--no-clobber-old-sections" ];

  installPhase = ''
    mkdir -p "$prefix/lib/firefox-bin-${version}"
    cp -r * "$prefix/lib/firefox-bin-${version}"

    mkdir -p "$out/bin"
    ln -s "$prefix/lib/firefox-bin-${version}/firefox" "$out/bin/${binaryName}"

    # See: https://github.com/mozilla/policy-templates/blob/master/README.md
    mkdir -p "$out/lib/firefox-bin-${version}/distribution";
    ln -s ${policiesJson} "$out/lib/firefox-bin-${version}/distribution/policies.json";
  '';

  passthru = {
    applicationName = name;
    inherit binaryName;
    libName = "firefox-bin-${version}";
    ffmpegSupport = true;
    gssSupport = true;
    gtk3 = gtk3;
  };

  meta = {
    changelog = "https://www.mozilla.org/en-US/firefox/${version}/releasenotes/";
    description = "Mozilla Firefox, free web browser (binary package)";
    homepage = "https://www.mozilla.org/firefox/";
    license = {
      shortName = "firefox";
      fullName = "Firefox Terms of Use";
      url = "https://www.mozilla.org/about/legal/terms/firefox/";
      # "You Are Responsible for the Consequences of Your Use of Firefox"
      # (despite the heading, not an indemnity clause) states the following:
      #
      # > You agree that you will not use Firefox to infringe anyone’s rights
      # > or violate any applicable laws or regulations.
      # >
      # > You will not do anything that interferes with or disrupts Mozilla’s
      # > services or products (or the servers and networks which are connected
      # > to Mozilla’s services).
      #
      # This conflicts with FSF freedom 0: "The freedom to run the program as
      # you wish, for any purpose". (Why should Mozilla be involved in
      # instances where you break your local laws just because you happen to
      # use Firefox whilst doing it?)
      free = false;
      redistributable = true; # since MPL-2.0 still applies
    };
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = binaryName;
  };
}
