#!/usr/bin/env bash
#
# Publish docs/ to Cloudflare Pages at https://beewatch.pages.dev
#
# GitHub Pages (giovannicoppola.github.io/beeWatch) still serves the same
# docs/ from main while the App Store listing points there. Cloudflare Pages
# works from a private repo, so this is the host to move the support and
# privacy URLs to before the repo goes private, as with Wristwise.
#
# Usage: Tools/deploy-site.sh
#
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="beewatch"
OUT="$REPO/build/site"

rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$REPO/docs/." "$OUT/"

# Jekyll and GitHub Pages leftovers mean nothing to Cloudflare.
rm -f "$OUT/_config.yml" "$OUT/.nojekyll"

# Pages looks for functions/ in the directory it is run from: functions/media/[[path]].js serves
# media/ in byte ranges, without which Safari will not play the tour video at all. (GitHub Pages
# serves ranges itself.)
cd "$REPO"
wrangler pages deploy "$OUT" --project-name "$PROJECT" --branch main --commit-dirty=true
