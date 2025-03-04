#!/usr/bin/env nu
const SYSTEMS = ["linux-x86_64" "linux-aarch64"];

def to_sri (hash: string) {
  return $"sha512-($hash | decode hex | encode base64)"
}

def fetch_release (version: string, system: string, extension: string) {
  let base = $"https://download.cdn.mozilla.net/pub/firefox/releases/($version)"

  let filename = $"($system)/en-US/firefox-($version).($extension)"

  let row = (
    http get $"($base)/SHA512SUMS"
    | from ssv -m 1 --noheaders
    | where column1 == $filename
  )

  if ($row | is-not-empty) {
    let hash = $row.column0.0

    return {
      version: $version,
      url: $"($base)/($filename)",
      hash: (to_sri $hash)
    }  
  } else {
    return null
  }
}

def fetch_nightly (version: string, system: string) {
  let product = $"firefox-($version).en-US.($system)";
  let data = http get $"https://download.cdn.mozilla.net/pub/firefox/nightly/latest-mozilla-central/($product).buildhub.json";
  
  let url = $data.download.url

  let hash = (
    http get $"($url | path dirname)/($product).checksums"
    | from ssv -m 1 --noheaders
    | where column1 == "sha512"
    | where column3 == ($url | path basename)
  ).column0.0

  return {
    version: $version,
    url: $url,
    hash: (to_sri $hash),
    date: $data.build.date,
  }
}

let versions = (http get "https://product-details.mozilla.org/1.0/firefox_versions.json")

let data = (
  $SYSTEMS
  | wrap system
  | each {|it| {
    system: $it.system,
    data: {
      release: (fetch_release $versions.LATEST_FIREFOX_VERSION $it.system "tar.xz")
      esr: (fetch_release $versions.FIREFOX_ESR $it.system "tar.bz2")
      beta: (fetch_release $versions.LATEST_FIREFOX_RELEASED_DEVEL_VERSION $it.system "tar.xz")
      nightly: (fetch_nightly $versions.FIREFOX_NIGHTLY $it.system)
    }
  }}
  | transpose --header-row --as-record
)

$data | to json | save -f latest.json
