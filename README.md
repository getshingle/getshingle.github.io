<p align="center"><a href="https://getshingle.github.io"><img src="https://getshingle.github.io/img/github/getshingle.github.io.png" alt="getshingle.github.io: the guide, demos and downloads" width="720"></a></p>

# getshingle.github.io

The Shingle website: the guide, the demos and the downloads. Looking for
Shingle itself? Go to **<https://getshingle.github.io>** or
[getshingle/shingle](https://github.com/getshingle/shingle).

```
guide/       the pages of the guide, built with Shingle on top of the template
examples/    complete example websites (halo)
tools/
  website.sh builds the guide, demos and downloads into _site/
  package.sh makes the download zips (website.sh runs it)
  test.sh    builds everything in a temporary folder and checks the result
```

## How it is published

GitHub Actions does everything; nothing built is stored in this repository.

- **A push to this repository** runs `.github/workflows/website.yml`: it
  fetches [shingle](https://github.com/getshingle/shingle),
  [extensions](https://github.com/getshingle/extensions) and
  [themes](https://github.com/getshingle/themes), runs the tests, builds
  `_site/` and publishes it on GitHub Pages.
- **After a change in one of the other repositories**, open **Actions →
  Website → Run workflow** here, so the website and downloads pick it up.
- **Tests** run on Linux, macOS (with its bash 3.2) and Windows with
  `.github/workflows/test.yml`, on every push and from the same Run workflow button.

## On your computer

Clone the four repositories next to each other:

```
getshingle/
  shingle/
  extensions/
  themes/
  getshingle.github.io/
```

Then, in `getshingle.github.io/`:

```
bash tools/test.sh       # check everything
bash tools/website.sh    # build _site/, then open _site/index.html
```

`website.sh` needs `zip`, which comes with macOS and Linux.

## License

MIT, see `LICENSE`. Shingle itself: see the
[shingle](https://github.com/getshingle/shingle) repository.
