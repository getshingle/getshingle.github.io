# shellcheck shell=bash
# SPDX-License-Identifier: MIT
# tools/repos.sh: where the other Shingle repositories are. Sourced by the
# other tools. They sit next to this one:
#
#   getshingle/
#     shingle/                 the template
#     extensions/              extensions
#     themes/                  themes
#     getshingle.github.io/    this repository: the guide, examples and tools

SITE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ROOT=$(dirname "$SITE")
TEMPLATE=$ROOT/shingle
EXTENSIONS=$ROOT/extensions
THEMES=$ROOT/themes

for repo in "$TEMPLATE" "$EXTENSIONS" "$THEMES"; do
  if [[ ! -d $repo ]]; then
    echo "Missing $repo." >&2
    echo "Clone shingle, extensions and themes next to getshingle.github.io." >&2
    exit 1
  fi
done

# The shared files an extension needs: collection.sh and .css for list extensions.
shared() {   # shared <extension>
  if grep -q '^  collection$' "$EXTENSIONS/$1/extension.sh"; then echo collection.sh collection.css; fi
}

# A fresh copy of the template, without Git files and without dist/.
fresh() {   # fresh <folder>
  rm -rf "$1"
  mkdir -p "$1"
  cp -R "$TEMPLATE/." "$1/"
  rm -rf "$1/.git" "$1/.github" "$1/dist"
}

# Add an extension (and the shared files it needs) to a website folder.
add_extension() {   # add_extension <website folder> <extension>
  local file
  cp -R "$EXTENSIONS/$2" "$1/extensions/"
  for file in $(shared "$2"); do cp "$EXTENSIONS/$file" "$1/extensions/"; done
}

# A complete website from an example: its content, settings and pictures,
# its theme and the extensions its content uses.
example_site() {   # example_site <example folder> <website folder>
  local theme folder ext
  fresh "$2"
  rm -rf "$2/content" "$2/static/img"
  cp -R "$1/content" "$2/content"
  cp "$1/site.conf" "$2/site.conf"
  cp -R "$1/static/." "$2/static/"
  theme=$(sed -n 's/^THEME="\([^"]*\)".*/\1/p' "$2/site.conf")
  if [[ -d $THEMES/$theme ]]; then cp -R "$THEMES/$theme" "$2/themes/"; fi
  for folder in "$2"/content/*/; do
    ext=${folder%/} && ext=${ext##*/}
    if [[ -f $EXTENSIONS/$ext/extension.sh ]]; then
      add_extension "$2" "$ext"
      rm -rf "${2:?}/extensions/$ext/example"
    fi
  done
}
