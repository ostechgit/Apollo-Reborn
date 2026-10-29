#!/bin/bash
# Host-side tests for the RedditKit models: compiles Mantle + the model classes
# for macOS and runs them against tests/fixtures. No simulator or network needed.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REBUILD_DIR="$(dirname "$TESTS_DIR")"
MANTLE="$REBUILD_DIR/Pods/Mantle/Mantle"
REDDITKIT="$REBUILD_DIR/Sources/RedditKit"
[[ -d "$MANTLE" ]] || { echo "Mantle not found at $MANTLE — run pod install first" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# RedditKit imports <Mantle/Mantle.h>
mkdir -p "$WORK/include"
ln -s "$MANTLE/include" "$WORK/include/Mantle"

MODELS=(RDKThing RDKCreated RDKVotable RDKLink RDKLinkPreviewItem RDKComment RDKMoreComments
        RDKObjectBuilder RDKPagination RDKUser RDKMe RDKMessage RDKCommentReplyMessage
        RDKSubreddit RDKMultireddit RDKMultiredditDescription)
SOURCES=("$TESTS_DIR/RedditKitModelTests.m" "$MANTLE"/*.m "$MANTLE"/extobjc/*.m)
for model in "${MODELS[@]}"; do SOURCES+=("$REDDITKIT/$model.m"); done

xcrun clang -fobjc-arc -fmodules -Wno-deprecated-declarations -O0 -g \
    -I "$WORK/include" -I "$MANTLE" -I "$MANTLE/include" -I "$MANTLE/extobjc/include" -I "$REDDITKIT" \
    -framework Foundation "${SOURCES[@]}" -o "$WORK/redditkit-tests"
# Mantle logs "Unrecognized attribute string flag '?'" for NSObject properties on current runtimes; harmless
"$WORK/redditkit-tests" "$TESTS_DIR/fixtures" 2> >(grep -v "Unrecognized attribute string flag" >&2)
