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
no_address() {   # no readable email address, mailto: link or "[at]" in any page
  ! grep -rqE '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z]{2,}|mailto:|\[at\]' "$SITE_DIR/dist" --include='*.html'
}
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

echo "Email addresses:"
printf -- '---\ntitle: Write\n---\n<p><a href="mailto:me@example.com">me@example.com</a> <a class="btn" href="mailto:me@example.com?subject=Hi">Write to us</a> <a href="mailto:me@example.com" aria-label="Email">{{ICON_EMAIL}}</a></p>\n' > "$SITE_DIR/content/write.html"
build
check "leaves no address in the pages" no_address
check "hides an address written in a page" has dist/write/index.html '<a data-email="bWVAZXhhbXBsZS5jb20="></a>'
check "keeps the words of a link" has dist/write/index.html '>Write to us</a>'
check "keeps the subject" has dist/write/index.html 'data-email-query="subject=Hi"'
check "keeps an icon's name valid" has dist/write/index.html 'role="link" aria-label="Email"'
check "says JavaScript shows the address" has dist/write/index.html '<noscript>Enable JavaScript to see the email address.</noscript>'
cp "$SITE_DIR/site.conf" "$WORK/conf.keep"
printf 'EMAIL_NOSCRIPT=""\n' >> "$SITE_DIR/site.conf"
build
check "EMAIL_NOSCRIPT=\"\" leaves the note out" lacks dist/write/index.html '<noscript>'
mv "$WORK/conf.keep" "$SITE_DIR/site.conf"
rm "$SITE_DIR/content/write.html"

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
check "hides the address of an apply button" has dist/careers/project-architect/index.html 'data-email-query="subject=Application'
check "no apply button for a closed position" lacks dist/careers/interior-design-intern/index.html 'Apply for this position'
check "no apply button on the careers page" lacks dist/careers/index.html 'Apply for this position'
check "leaves no address in any extension's pages" no_address
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
mv "$SITE_DIR/extensions/collection.css" "$WORK/collection.css"
check "says where collection.css goes when it is missing" fails_with "Put them straight into extensions/"
mv "$WORK/collection.css" "$SITE_DIR/extensions/"

echo "Extensions on your pages:"
cat > "$SITE_DIR/content/values.html" <<'EOF'
---
title: Values
---
<section>
{{OPENING_HOURS}}
<p><a href="{{MAP_URL}}">Map</a></p>
{{FAQ_FEES}}
{{SERVICES}}
{{TESTIMONIALS}}
{{PRICING}}
{{SCHEDULE}}
{{DOWNLOADS}}
{{FORM_CONTACT}}
{{EMBED_MAP}}
{{EMBED_VIDEO}}
</section>
EOF
sed 's|^FOOTER_TEXT=.*|FOOTER_TEXT="Open {{OPENING_HOURS_TEXT}}."|' "$SITE_DIR/site.conf" > "$WORK/conf" && mv "$WORK/conf" "$SITE_DIR/site.conf"
printf -- '---\ntitle: How do I reach you?\ntopic: Fees\n---\n<p>Write to {{EMAIL}}.</p>\n' > "$SITE_DIR/content/faq/07_reach-you.html"
build
check "hides an address in structured data" has dist/faq/index.html '<a data-email=\\"aGVsbG9AZXhhbXBsZS5jb20=\\"><\\/a>'
check "leaves no address in the pages, structured data included" no_address
check "the services extension wins over content/services.html" grep -q "Not used: content/services.html" "$WORK/log"
check "adds no second link to /services/" test "$(grep -c '|/services/"' "$SITE_DIR/site.conf")" -eq 1
check "builds a service" exists dist/services/new-homes/index.html
check "shows the opening hours" has dist/values/index.html '<th scope="row">Monday–Friday</th><td>9:00–17:30</td>'
check "shows the hours in FOOTER_TEXT" has dist/about/index.html 'Open Monday–Friday 9:00–17:30.'
check "links to a map" has dist/values/index.html 'maps/search/?api=1&amp;query=12+Harbour+Lane'
check "describes the business for search engines" has dist/index.html '"openingHoursSpecification"'
check "builds the FAQ page" has dist/faq/index.html '"@type": "FAQPage"'
check "shows the questions of one topic" has dist/values/index.html 'id="first-meeting"'
check "leaves out the other topics" lacks dist/values/index.html 'id="do-i-need-a-permit"'
check "shows the services" has dist/values/index.html 'class="cols-3 services"'
check "shows three testimonials" test "$(grep -c '<blockquote>' "$SITE_DIR/dist/values/index.html")" -eq 3
check "builds a gallery album" exists dist/gallery/riverside-house/02_living-room.jpg
check "uses the first photo as the cover" has dist/gallery/index.html 'riverside-house/01_from-the-river.jpg'
check "turns a text file into a caption" has dist/gallery/riverside-house/index.html '<figcaption>The living room'
check "does not publish caption files" missing dist/gallery/riverside-house/02_living-room.txt
check "builds the menu" has dist/menu/index.html '<p class="price">9.50</p>'
check "shows a dish's tags" has dist/menu/index.html '<span class="tag">VG</span><span class="tag">GF</span>'
check "shows seven days" test "$(grep -c 'class="day"' "$SITE_DIR/dist/values/index.html")" -eq 7
check "builds the pricing page" has dist/pricing/index.html 'class="plan featured"'
check "has no yearly switch without yearly prices" lacks dist/pricing/index.html 'name="billing"'
check "lists the downloads" has dist/downloads/index.html '<h2>Checklists</h2>'
check "publishes a download without its number" exists dist/downloads/project-brief.pdf
check "shows a download's size" has dist/values/index.html 'PDF · [0-9]* KB'
check "shows the form" has dist/values/index.html 'name="email" type="email" autocomplete="email" required'
check "says the form has no service yet" grep -q "has no form service yet" "$WORK/log"
check "shows an embed" has dist/values/index.html 'data-src="https://www.openstreetmap.org/export/embed.html'
check "plays YouTube videos without cookies" has dist/values/index.html 'youtube-nocookie.com/embed/aqz-KE-bpKQ'
printf 'price_yearly: €20\n' > "$WORK/yearly"
sed '/^price: /r '"$WORK/yearly" "$SITE_DIR/content/pricing/1_advice-visit.html" > "$WORK/plan" && mv "$WORK/plan" "$SITE_DIR/content/pricing/1_advice-visit.html"
sed 's|^action:.*|action: https://formspree.io/f/test|' "$SITE_DIR/content/forms/_index.html" > "$WORK/form" && mv "$WORK/form" "$SITE_DIR/content/forms/_index.html"
build
check "adds the yearly switch" has dist/pricing/index.html 'name="billing"'
check "sends the form to the service" has dist/values/index.html 'action="https://formspree.io/f/test"'

echo "Markdown:"
printf -- '---\ntitle: Notes\n---\nSome *notes*.\n' > "$SITE_DIR/content/notes.md"
check "stops at .md without the markdown extension" fails_with "written in Markdown"
add_extension "$SITE_DIR" markdown
if command -v cmark-gfm > /dev/null || command -v cmark > /dev/null; then
  printf -- '---\ntitle: In Markdown\nsummary: A post.\n---\nA **bold** post.\n' > "$SITE_DIR/content/blog/2026-01-02_in-markdown.md"
  printf -- '---\ntitle: Mark Down\nrole: Writer\n---\nShe writes *Markdown*.\n' > "$SITE_DIR/content/team/009_mark-down.md"
  printf -- '---\ntitle: Is Markdown fine?\n---\nYes, *it is*.\n' > "$SITE_DIR/content/faq/09_markdown.md"
  rm "$SITE_DIR"/content/news/_index.*
  printf -- '---\ntitle: News\n---\nOur **news**.\n' > "$SITE_DIR/content/news/_index.md"
  build
  check "builds .md with the markdown extension" has dist/notes/index.html '<em>notes</em>'
  check "puts a page's title on top" has dist/notes/index.html '<h1>Notes</h1>'
  check "adds the example page" has dist/markdown/index.html '<figcaption>Morning light in the studio</figcaption>'
  check "builds a blog post in Markdown" has dist/blog/in-markdown/index.html '<strong>bold</strong>'
  check "builds a person in Markdown" has dist/team/mark-down/index.html '<em>Markdown</em>'
  check "builds a question in Markdown" has dist/faq/index.html '<em>it is</em>'
  check "builds an _index.md" has dist/news/index.html '<p>Our <strong>news</strong>.</p>'
  check "does not give an _index.md a second title" test "$(grep -c '<h1>' "$SITE_DIR/dist/news/index.html")" -eq 1
else
  check "says how to install cmark-gfm" fails_with "brew install cmark-gfm"
fi
rm -rf "$SITE_DIR/extensions/markdown" "$SITE_DIR/content/markdown"
find "$SITE_DIR/content" -name '*.md' -exec rm {} +
printf -- '---\ntitle: News\n---\n' > "$SITE_DIR/content/news/_index.html"

echo "Themes:"
for dir in "$THEMES"/*/; do
  name=${dir%/} && name=${name##*/}
  cp -R "${dir%/}" "$SITE_DIR/themes/"
  sed "s|^THEME=.*|THEME=\"$name\"|" "$SITE_DIR/site.conf" > "$WORK/conf" && mv "$WORK/conf" "$SITE_DIR/site.conf"
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
