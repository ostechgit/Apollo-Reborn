#!/usr/bin/env bash
#
# install.sh — build the auth shim and run STOCK Apollo in the iOS Simulator.
#
# Why this exists: stock Apollo 1.15.11 embeds a Reddit OAuth client id that
# Reddit revoked, and offers no way to enter a replacement, so a plain stock
# build in the simulator can never load a feed. This installs stock Apollo plus
# only the credential hooks (see ApolloAuthShim.xm), giving an observation
# target whose UI is unmodified — unlike the full Reborn tweak, which adds
# avatars, gallery carousels and other chrome.
#
# Usage:
#   ./install.sh                       # build shim, prepare shell, install, launch
#   ./install.sh --backup ~/x.zip      # also preload a Reborn settings backup
#   ./install.sh --no-build            # reuse the last shim build
#   ./install.sh --fresh               # re-extract and re-patch the shell
#   ./install.sh --bundle-id com.x.Y   # install under a different id (default below)
#
# Options:
#   --ipa PATH        base IPA               (default: ../apollo-base.ipa)
#   --sim NAME|UDID   simulator              (default: the booted one)
#
# Notes:
#   * The app is installed ad-hoc signed and platform-patched, exactly like the
#     Reborn simulator flow; nothing is written to the IPA on disk.
#   * Only an APPLICATION-ONLY Reddit session is possible here. The signed-in
#     user account lives in Valet's keychain, and seeding that is a Reborn
#     feature (it virtualises the keychain in the simulator). An app-only token
#     is enough to load public feeds, which is what UI evidence needs.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WORK="$HERE/build"
APP_DIR="$WORK/shell/Payload/Apollo.app"
BUNDLE_ID="com.omarsalam.ApolloStockLogin"
IPA="$ROOT/apollo-base.ipa"
BACKUP=""
DO_BUILD=1
FRESH=0
SIM="${SIM:-}"
DEPLOY_MIN="15.0"

die()  { printf '\033[0;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ipa)        IPA="$2"; shift ;;
        --backup)     BACKUP="$2"; shift ;;
        --bundle-id)  BUNDLE_ID="$2"; shift ;;
        --sim)        SIM="$2"; shift ;;
        --no-build)   DO_BUILD=0 ;;
        --fresh)      FRESH=1 ;;
        -h|--help)    sed -n '2,40p' "$0"; exit 0 ;;
        *)            die "unknown option: $1" ;;
    esac
    shift
done

[[ -n "$SIM" ]] || SIM="$(xcrun simctl list devices booted | awk -F '[()]' '/Booted/{print $2; exit}')"
[[ -n "$SIM" ]] || die "no booted simulator; boot one or pass --sim"
[[ -f "$IPA" ]] || die "IPA not found: $IPA"

# ---------------------------------------------------------------------------
# 1. Build the shim
# ---------------------------------------------------------------------------
DYLIB=""
if [[ "$DO_BUILD" == 1 ]]; then
    log "Building ApolloAuthShim for the simulator SDK"
    make -C "$HERE" \
        TARGET="simulator:clang:latest:${DEPLOY_MIN}" \
        ARCHS=arm64 \
        TARGET_CODESIGN_FLAGS="--sign -" \
        LOGOS_DEFAULT_GENERATOR=internal \
        -j"$(sysctl -n hw.ncpu)" >/dev/null
fi
DYLIB="$(find "$HERE/.theos/obj/iphone_simulator" -maxdepth 2 -name 'ApolloAuthShim.dylib' \
          ! -path '*.dSYM*' 2>/dev/null | head -1)"
[[ -n "$DYLIB" ]] || die "shim dylib not found; run without --no-build"
codesign -f -s - "$DYLIB" >/dev/null 2>&1
if ! vtool -show-build "$DYLIB" 2>/dev/null | grep -q 'IOSSIMULATOR'; then
    die "shim is not a simulator binary (stale build?)"
fi
log "Shim ready: $DYLIB"

# ---------------------------------------------------------------------------
# 2. Prepare the stock shell (cached; --fresh to redo)
# ---------------------------------------------------------------------------
if [[ "$FRESH" == 1 ]]; then
    rm -rf "$WORK/shell"
fi
if [[ ! -d "$APP_DIR" ]]; then
    log "Extracting $IPA"
    rm -rf "$WORK/shell"
    mkdir -p "$WORK/shell"
    unzip -q "$IPA" -d "$WORK/shell"

    # Platform patch every Mach-O (main binary, frameworks, appexes).
    log "Patching Mach-O platforms to iOS-Simulator"
    while IFS= read -r -d '' f; do
        if file -b "$f" | grep -q 'Mach-O'; then
            python3 "$HERE/prepare_shell.py" "$f"
        fi
    done < <(find "$APP_DIR" -type f -print0)

    # Rebrand so this coexists with the App Store id and the Reborn build.
    log "Rebranding bundle id to $BUNDLE_ID"
    plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$APP_DIR/Info.plist"
    while IFS= read -r -d '' plist; do
        orig="$(plutil -extract CFBundleIdentifier raw "$plist" 2>/dev/null || echo "")"
        suffix="${orig##*.}"
        if [[ -n "$suffix" && "$suffix" != "$orig" ]]; then
            plutil -replace CFBundleIdentifier -string "$BUNDLE_ID.$suffix" "$plist"
        fi
    done < <(find "$APP_DIR/PlugIns" -name Info.plist -print0 2>/dev/null)

    # Ad-hoc sign innermost first.
    log "Signing"
    while IFS= read -r -d '' bundle; do
        codesign -f -s - "$bundle" >/dev/null 2>&1
    done < <(find "$APP_DIR/Frameworks" -maxdepth 1 -name '*.framework' -print0 2>/dev/null)
    while IFS= read -r -d '' bundle; do
        codesign -f -s - "$bundle" >/dev/null 2>&1
    done < <(find "$APP_DIR/PlugIns" -maxdepth 1 -name '*.appex' -print0 2>/dev/null)
    codesign -f -s - "$APP_DIR" >/dev/null 2>&1
fi

# ---------------------------------------------------------------------------
# 3. Install
# ---------------------------------------------------------------------------
log "Installing to simulator $SIM"
xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIM" "$APP_DIR"

# ---------------------------------------------------------------------------
# 4. Preload credentials from a Reborn settings backup, if given
# ---------------------------------------------------------------------------
if [[ -n "$BACKUP" ]]; then
    [[ -f "$BACKUP" ]] || die "backup not found: $BACKUP"
    log "Preloading settings backup: $(basename "$BACKUP")"
    BK_DIR="$(mktemp -d)"
    unzip -q -o "$BACKUP" -d "$BK_DIR"
    BK_MAIN="$(find "$BK_DIR" -name 'preferences.plist' | head -1)"
    BK_GROUP="$(find "$BK_DIR" -name 'group.plist' | head -1)"
    [[ -n "$BK_MAIN" ]] || die "backup has no preferences.plist"
    DATA="$(xcrun simctl get_app_container "$SIM" "$BUNDLE_ID" data)"
    PREFS="$DATA/Library/Preferences"
    mkdir -p "$PREFS"
    # Copying the Preferences plist alone is not enough: cfprefsd owns that
    # domain and ignores out-of-band edits, and the simulator's `defaults` tool
    # cannot see an app sandbox domain. The shim therefore reads this seed file
    # on load and writes the keys into standard defaults itself.
    mkdir -p "$DATA/Library/Caches"
    cp "$BK_MAIN" "$DATA/Library/Caches/StockLogin.plist"
    [[ -n "$BK_GROUP" ]] && cp "$BK_GROUP" "$PREFS/group.com.christianselig.apollo.plist"
    rm -rf "$BK_DIR"
    log "Credentials seeded (shim imports them on launch)"
fi

# ---------------------------------------------------------------------------
# 5. Launch with the shim injected
# ---------------------------------------------------------------------------
# If the shell already carries an LC_LOAD_DYLIB for @rpath/ApolloReborn.dylib
# (an injected base IPA), DYLD_INSERT alone would still abort on the missing
# rpath load — satisfy it with the shim instead.
INJECT_ENV=1
if otool -L "$APP_DIR/Apollo" 2>/dev/null | grep -q 'ApolloReborn.dylib'; then
    log "Shell links @rpath/ApolloReborn.dylib — placing the shim there"
    cp "$DYLIB" "$APP_DIR/Frameworks/ApolloReborn.dylib"
    codesign -f -s - "$APP_DIR" >/dev/null 2>&1
    INJECT_ENV=0
fi

log "Launching $BUNDLE_ID"
if [[ "$INJECT_ENV" == 1 ]]; then
    SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$DYLIB" xcrun simctl launch "$SIM" "$BUNDLE_ID"
else
    xcrun simctl launch "$SIM" "$BUNDLE_ID"
fi

cat <<EOF

Stock Apollo is running with only the credential shim.

  bundle id : $BUNDLE_ID
  shim      : $DYLIB
  log filter: xcrun simctl spawn $SIM log show --last 2m --predicate 'process == "Apollo"' | grep StockLogin

If the feed stays empty, check the shim's log line: it reports whether the client
id, secret and redirect were found. Re-run with --backup <zip> to load them.
EOF
