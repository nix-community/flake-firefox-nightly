#!/usr/bin/env bash
set -euo pipefail
set -x
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

BUILD_HOST="https://builds.sr.ht"
TOKEN="$(cat "/run/secrets/srht-pat")" # this assumes we're submitting from a colemickens/nixcfg machine

DATA="$(mktemp)"
MANIFEST="$(jq -aRs . <"${DIR}/srht-job.yaml")"
echo "{ \"tags\": [ \"flake-firefox-nightly\" ], \"manifest\": ${MANIFEST} }" > "${DATA}"
trap "rm ${DATA}" EXIT

curl \
  -H "Authorization:token ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "@${DATA}" \
  "${BUILD_HOST}/api/jobs"
