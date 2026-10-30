#!/bin/bash
# Compile the actual client/serializer/models. Transport is intercepted in-process;
# no sharedClient, credentials, simulator data, or network is used.
set -euo pipefail
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REBUILD_DIR="$(dirname "$TESTS_DIR")"
MANTLE="$REBUILD_DIR/Pods/Mantle/Mantle"
AF="$REBUILD_DIR/Pods/AFNetworking/AFNetworking"
REDDITKIT="$REBUILD_DIR/Sources/RedditKit"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/include"
ln -s "$MANTLE/include" "$WORK/include/Mantle"
MODELS=(RDKThing RDKCreated RDKVotable RDKLink RDKLinkPreviewItem RDKComment RDKMoreComments
        RDKObjectBuilder RDKPagination RDKUser RDKMe RDKMessage RDKCommentReplyMessage
        RDKSubreddit RDKMultireddit RDKMultiredditDescription RDKClient RDKResponseSerializer
        RDKOAuthCredential RDKAccessToken)
SOURCES=("$TESTS_DIR/CommentSubmitTests.m" "$MANTLE"/*.m "$MANTLE"/extobjc/*.m "$AF"/*.m)
for model in "${MODELS[@]}"; do SOURCES+=("$REDDITKIT/$model.m"); done
xcrun clang -fobjc-arc -fmodules -Wno-deprecated-declarations -O0 -g \
    -I "$WORK/include" -I "$MANTLE" -I "$MANTLE/include" -I "$MANTLE/extobjc/include" \
    -I "$REBUILD_DIR/Pods/AFNetworking" -I "$REDDITKIT" \
    -framework Foundation -framework SystemConfiguration -framework Security -framework Cocoa \
    "${SOURCES[@]}" -o "$WORK/comment-submit-tests"
"$WORK/comment-submit-tests" 2> >(grep -v "Unrecognized attribute string flag" >&2)
