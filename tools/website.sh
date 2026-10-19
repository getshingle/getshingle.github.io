#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# ==============================================================================
# tools/website.sh: builds getshingle.github.io into _site/.
#
#   _site/                      the guide: the template with guide/ on top
#   _site/demo/atrium/          the template as it is downloaded
#   _site/demo/extensions/      the template with every extension
#   _site/demo/theme-<name>/    the same, in each theme
#   _site/demo/<example>/       each complete website from examples/
#   _site/downloads/            the zips from tools/package.sh
#
# GitHub Actions runs this on every push (.github/workflows/website.yml).
# To look at the result on your computer, open _site/index.html.
# ==============================================================================
set -eo pipefail
shopt -s nullglob
# shellcheck source-path=SCRIPTDIR source=repos.sh
source "$(dirname "$0")/repos.sh"
OUT=$SITE/_site
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
URL=$(sed -n 's/^SITE_URL="\([^"]*\)".*/\1/p' "$SITE/guide/site.conf")

rm -rf "$OUT"
mkdir -p "$OUT"
bash "$SITE/tools/package.sh" "$OUT/downloads" > /dev/null

publish() {   # publish <website folder> <path in _site>: build it at its address, copy dist/
  local conf=$1/site.conf
  sed "s|^SITE_URL=.*|SITE_URL=\"$URL${2:+/$2}\"|" "$conf" > "$conf.new" && mv "$conf.new" "$conf"
  (cd "$1" && bash build.sh > /dev/null)
  mkdir -p "$OUT/$2"
  cp -R "$1/dist/." "$OUT/$2"
  echo "  _site/$2"
}

# A demo says so on every page, links back to the guide and stays out of search engines.
BANNER="<a id=\"shingle-demo\" href=\"$URL/\" style=\"position:fixed;z-index:1000;left:50%;bottom:14px;transform:translateX(-50%);display:flex;gap:.6em;align-items:center;padding:.4em 1em .4em .4em;border-radius:999px;background:#1f4f9a;color:#fff;font:600 14px/1.2 system-ui,sans-serif;text-decoration:none;box-shadow:0 8px 24px -8px rgba(0,0,0,.5);white-space:nowrap\"><b style=\"padding:.3em .7em;border-radius:999px;background:#dbe6ff;color:#0e2f66;font-size:12px;letter-spacing:.06em\">DEMO</b><span>Made with Shingle · back to the guide</span></a>"
mark_demo() {   # mark_demo <path in _site>
  local page
  while IFS= read -r -d '' page; do
    sed -e "s|^<body>$|<body>\\
$BANNER|" -e 's|^<head>$|<head>\
  <meta name="robots" content="noindex">|' "$page" > "$page.new" && mv "$page.new" "$page"
  done < <(find "$OUT/$1" -name '*.html' -print0)
}

# Replace a list in site.conf, such as MENU, with new lines.
set_list() {   # set_list <site.conf> <list> <"Label|/address/">…
  local conf=$1 list=$2
  shift 2
  awk -v list="$list" -v items="$(printf '  "%s"\n' "$@")" '
    index($0, list "=(") == 1 { print list "=("; print items; skip = 1; next }
    skip && /^\)/ { skip = 0 }
    !skip { print }' "$conf" > "$conf.new"
  mv "$conf.new" "$conf"
}

demo() {   # demo <website folder> <name>
  publish "$1" "demo/$2"
  mark_demo "demo/$2"
}

# The guide: the template's frame with the guide's settings, pages, look and pictures.
fresh "$WORK/guide"
rm -rf "$WORK/guide/content" "$WORK/guide/static"
cp -R "$SITE/guide/." "$WORK/guide/"
for file in "$THEMES"/*/preview.jpg; do name=${file%/*} && cp "$file" "$WORK/guide/static/img/theme-${name##*/}.jpg"; done
for file in "$SITE"/examples/*/preview.jpg; do name=${file%/*} && cp "$file" "$WORK/guide/static/img/example-${name##*/}.jpg"; done
publish "$WORK/guide" ''

# Demos.
fresh "$WORK/atrium"
demo "$WORK/atrium" atrium

# Atrium with the extensions that suit it (menu and schedule have their own
# examples). The first build adds their examples; then the menu is shortened
# and values such as {{TESTIMONIALS}} are added to the home and contact pages.
fresh "$WORK/extensions"
for name in blog portfolio news team careers privacy sitemap business services faq testimonials \
  gallery pricing downloads forms embed; do
  add_extension "$WORK/extensions" "$name"
done
if command -v cmark-gfm > /dev/null || command -v cmark > /dev/null; then
  add_extension "$WORK/extensions" markdown
else
  echo "  (no cmark-gfm: the demo is built without the markdown extension)"
fi
(cd "$WORK/extensions" && bash build.sh > /dev/null)
set_list "$WORK/extensions/site.conf" MENU "About|/about/" "Services|/services/" "Projects|/portfolio/" \
  "Gallery|/gallery/" "Blog|/blog/" "Team|/team/" "Pricing|/pricing/" "Contact|/contact/"
set_list "$WORK/extensions/site.conf" LEGAL "News|/news/" "Careers|/careers/" "FAQ|/faq/" \
  "Downloads|/downloads/" "Privacy policy|/privacy/"
for file in "$SITE"/demo/extensions/*.html; do cat "$file" >> "$WORK/extensions/content/${file##*/}"; done
demo "$WORK/extensions" extensions

for dir in "$THEMES"/*/; do
  name=${dir%/} && name=${name##*/}
  cp -R "$WORK/extensions" "$WORK/theme-$name"
  cp -R "${dir%/}" "$WORK/theme-$name/themes/"
  conf=$WORK/theme-$name/site.conf
  sed "s|^THEME=.*|THEME=\"$name\"|" "$conf" > "$conf.new" && mv "$conf.new" "$conf"
  demo "$WORK/theme-$name" "theme-$name"
done

for dir in "$SITE"/examples/*/; do
  name=${dir%/} && name=${name##*/}
  example_site "${dir%/}" "$WORK/example-$name"
  demo "$WORK/example-$name" "$name"
done

touch "$OUT/.nojekyll"
echo "Done: open _site/index.html."
