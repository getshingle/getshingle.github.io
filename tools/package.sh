#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# ==============================================================================
# tools/package.sh: makes the download zips.
#
#   bash tools/package.sh [folder]     default: _site/downloads
#
#   shingle.zip            the template
#   extension-<name>.zip   one extension (unzip into extensions/)
#   theme-<name>.zip       one theme (unzip into themes/)
#   site-<name>.zip        a complete website for each folder in examples/
# ==============================================================================
set -eo pipefail
shopt -s nullglob
# shellcheck source-path=SCRIPTDIR source=repos.sh
source "$(dirname "$0")/repos.sh"
OUT=${1:-$SITE/_site/downloads}
mkdir -p "$OUT" && OUT=$(cd "$OUT" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

zip_folder() {   # zip_folder <zip file> <parent folder> <files>…
  local zip=$1 parent=$2
  shift 2
  rm -f "$OUT/$zip"
  (cd "$parent" && zip -qrX "$OUT/$zip" "$@" -x '*/dist/*' '*.DS_Store' '*/.git/*')
}

fresh "$WORK/shingle"
zip_folder shingle.zip "$WORK" shingle

for dir in "$EXTENSIONS"/*/; do
  name=${dir%/} && name=${name##*/}
  # shellcheck disable=SC2046
  zip_folder "extension-$name.zip" "$EXTENSIONS" "$name" $(shared "$name")
done

for dir in "$THEMES"/*/; do
  name=${dir%/} && name=${name##*/}
  zip_folder "theme-$name.zip" "$THEMES" "$name"
done

for dir in "$SITE"/examples/*/; do
  name=${dir%/} && name=${name##*/}
  example_site "${dir%/}" "$WORK/$name"
  rm -f "$WORK/$name/preview.jpg"
  zip_folder "site-$name.zip" "$WORK" "$name"
done

ls -1 "$OUT"
