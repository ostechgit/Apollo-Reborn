#!/bin/bash
# extract-assets.sh - pull Apollo's compiled asset catalog (and sounds) out of the
# original base IPA so the rebuild can draw the same art by the same asset names.
#
#   ./scripts/extract-assets.sh [path/to/base.ipa]
#
# Apollo 1.15.11 draws nearly all of its chrome from named assets in Assets.car
# ("option-upvote", "option-comments", "tab-bar-posts", "symbol-...", "slide-..."),
# so the rebuild bundles that same catalog instead of inventing stand-ins. The
# catalog is 39 MB and gitignored; this script recreates it from the IPA
# (default: ../Apollo-base.ipa, or ./apollo-base.ipa inside the rebuild).
#
# Only the asset catalog and the sound files are extracted - no code.

set -euo pipefail
REBUILD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REBUILD_DIR"

IPA="${1:-}"
if [ -z "$IPA" ]; then
    for candidate in ./apollo-base.ipa ../Apollo-base.ipa ../apollo-base.ipa; do
        if [ -f "$candidate" ]; then IPA="$candidate"; break; fi
    done
fi
if [ -z "$IPA" ] || [ ! -f "$IPA" ]; then
    echo "error: no base IPA found. Pass one: ./scripts/extract-assets.sh path/to/base.ipa" >&2
    exit 1
fi

echo "Extracting Apollo assets from $IPA"
mkdir -p Resources
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

unzip -q "$IPA" 'Payload/Apollo.app/Assets.car' -d "$TMP"

ASSETS="$TMP/Payload/Apollo.app/Assets.car"
if [ ! -f "$ASSETS" ]; then
    echo "error: the IPA has no Payload/Apollo.app/Assets.car" >&2
    exit 1
fi
cp "$ASSETS" Resources/Assets.car
echo "  Resources/Assets.car  $(du -h Resources/Assets.car | cut -f1)"

# Sanity check: a few asset names every screen depends on. assetutil's output is
# dumped to a file first because `grep -q` closing the pipe early SIGPIPEs it,
# which pipefail would then report as a failed pipeline.
assetutil --info Resources/Assets.car > "$TMP/asset-info.json" 2>/dev/null || true
for name in option-upvote option-comments tab-bar-posts symbol-subreddit; do
    if ! grep -q "\"$name\"" "$TMP/asset-info.json"; then
        echo "warning: $name is missing from the catalog" >&2
    fi
done

echo "Done."
