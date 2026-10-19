#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# ==============================================================================
# tools/test.sh: builds the template, every extension, theme and example in a
# temporary folder and checks the results. Runs on Linux, macOS and Windows
# (Git Bash); build.sh runs with the same bash as this script, so
#
#   /bin/bash tools/test.sh      on a Mac tests the bash 3.2 that comes with it.
# ==============================================================================
set -eo pipefail
shopt -s nullglob
# shellcheck source-path=SCRIPTDIR source=repos.sh
source "$(dirname "$0")/repos.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
SITE_DIR=$WORK/site
FAILED=0
echo "Testing with bash $BASH_VERSION"

check() {   # check <what> <command…>: report one result
  if "${@:2}"; then echo "  ok    $1"; else echo "  FAIL  $1"; FAILED=1; fi
}
has() { grep -q -- "$2" "$SITE_DIR/$1"; }            # has <file in the website> <text>
lacks() { ! grep -q -- "$2" "$SITE_DIR/$1"; }
exists() { [[ -e $SITE_DIR/$1 ]]; }
missing() { [[ ! -e $SITE_DIR/$1 ]]; }
build() {   # build [preview]: must succeed
  if ! (cd "$SITE_DIR" && "$BASH" build.sh "$@") > "$WORK/log" 2>&1; then
    cat "$WORK/log"; echo "  FAIL  build.sh $*"; exit 1
  fi
}
fails_with() {   # fails_with <text>: build.sh must stop and say <text>
  if (cd "$SITE_DIR" && "$BASH" build.sh) > "$WORK/log" 2>&1; then return 1; fi
  grep -q -- "$1" "$WORK/log"
}
set_conf() {   # set_conf <line that replaces SITE_NAME=…>
  grep -v '^SITE_NAME=' "$WORK/good.conf" > "$WORK/conf"
  printf '%s\n' "$1" >> "$WORK/conf"
  cp "$WORK/conf" "$SITE_DIR/site.conf"
}

echo "The template:"
fresh "$SITE_DIR"
build
check "builds 4 pages" grep -q "Done: 4 pages" "$WORK/log"
check "makes the home page" exists dist/index.html
check "makes the 404 page" exists dist/404.html
check "links between files" has dist/about/index.html 'href="../contact/index.html"'
check "no links from the root" lacks dist/about/index.html 'href="/'
check "404 links from the root" has dist/404.html 'href="/assets/site.css'
check "adds the icons" has dist/index.html '<svg class="icon"'
check "hides the email address" has dist/index.html 'data-email='

echo "Settings and dist:"
mkdir -p "$SITE_DIR/dist/.git" && touch "$SITE_DIR/dist/.git/keep" "$SITE_DIR/dist/old.html"
awk '{ printf "%s\r\n", $0 }' "$SITE_DIR/site.conf" > "$WORK/conf" && mv "$WORK/conf" "$SITE_DIR/site.conf"
build
check "reads site.conf with Windows line endings" has dist/about/index.html 'Atrium</title>'
check "keeps dist/.git" exists dist/.git/keep
check "removes old files from dist" missing dist/old.html
printf 'LINKS="web"\nSITE_URL="https://example.github.io/site"\n' >> "$SITE_DIR/site.conf"
build
check "LINKS=web keeps links from the root" has dist/about/index.html 'href="/contact/"'
check "404 in a subfolder starts at the subfolder" has dist/404.html 'href="/site/assets/site.css'

echo "Mistakes in site.conf:"
cp "$TEMPLATE/site.conf" "$WORK/good.conf"
set_conf 'SITE_NAME = "Atrium"'
check "spaces around =" fails_with "Remove the spaces around the = sign"
set_conf 'SITE_NAME=Atrium Studio'
check "text without quotes" fails_with "Put the text in double quotes"
set_conf 'SITE_NAME="Atrium'
check "a missing quote" fails_with "site.conf has a mistake"
cp "$WORK/good.conf" "$SITE_DIR/site.conf"

echo "Extensions:"
fresh "$SITE_DIR"
for dir in "$EXTENSIONS"/*/; do
  name=${dir%/} && name=${name##*/}
  if [[ $name != markdown ]]; then add_extension "$SITE_DIR" "$name"; fi
done
build
check "copies example content" exists content/blog/_index.html
check "adds menu links" has site.conf '"Blog|/blog/"'
check "adds footer links" has site.conf '"Privacy policy|/privacy/"'
check "builds the blog" exists dist/blog/index.html
check "builds a post with pictures" exists dist/blog/daylight-first/cover.jpg
check "makes a feed" exists dist/blog/feed.xml
check "builds the team" exists dist/team/anna-berg/index.html
check "links an author to the team" has dist/blog/daylight-first/index.html 'href="../../team/anna-berg/index.html"'
check "builds careers" exists dist/careers/project-architect/index.html
check "builds the portfolio" exists dist/portfolio/riverside-house/index.html
check "builds news" exists dist/news/index.html
check "builds the privacy page" exists dist/privacy/index.html
check "makes a sitemap" has dist/sitemap.xml '/blog/daylight-first/'
check "copies static files" exists dist/_headers
build
check "adds a menu link only once" test "$(grep -c '"Blog|/blog/"' "$SITE_DIR/site.conf")" -eq 1
mv "$SITE_DIR/extensions/careers" "$SITE_DIR/extensions/_careers"
grep -v '"Careers|/careers/"' "$SITE_DIR/site.conf" > "$WORK/conf" && mv "$WORK/conf" "$SITE_DIR/site.conf"
build
check "switches an extension off with _" missing dist/careers/index.html
check "does not add a removed link again" lacks site.conf 'Careers|'
printf -- '---\ntitle: Notes\ndraft: true\n---\n<p>Draft.</p>\n' > "$SITE_DIR/content/blog/2026-01-01_draft-note.html"
build
check "leaves drafts out" missing dist/blog/draft-note/index.html
build preview
check "preview builds drafts" exists dist/blog/draft-note/index.html

echo "Markdown:"
printf -- '---\ntitle: Notes\n---\nSome *notes*.\n' > "$SITE_DIR/content/notes.md"
check "stops at .md without the markdown extension" fails_with "written in Markdown"
add_extension "$SITE_DIR" markdown
if command -v cmark-gfm > /dev/null || command -v cmark > /dev/null; then
  build
  check "builds .md with the markdown extension" has dist/notes/index.html '<em>notes</em>'
else
  check "says how to install cmark-gfm" fails_with "brew install cmark-gfm"
fi

echo "Themes:"
for dir in "$THEMES"/*/; do
  name=${dir%/} && name=${name##*/}
  cp -R "${dir%/}" "$SITE_DIR/themes/"
  sed "s|^THEME=.*|THEME=\"$name\"|" "$SITE_DIR/site.conf" > "$WORK/conf" && mv "$WORK/conf" "$SITE_DIR/site.conf"
  rm -f "$SITE_DIR/content/notes.md"
  build
  check "builds with $name" has dist/assets/site.css "Theme: "
done

for dir in "$SITE"/examples/*/; do
  name=${dir%/} && name=${name##*/}
  echo "Example $name:"
  example_site "${dir%/}" "$SITE_DIR"
  build
  check "builds" exists dist/index.html
  check "uses its theme" has dist/assets/site.css "Theme: "
done

if (( FAILED )); then echo "Some tests failed."; exit 1; fi
echo "All tests passed."
