#!/bin/bash
# Build the ApolloRebuild app as a base IPA and run it in the iOS Simulator.
#
#   scripts/run-in-sim.sh              archive (Release, unsigned) -> IPA -> simulator -> launch
#   scripts/run-in-sim.sh --no-build   reuse the last archive; just re-package, re-stage and relaunch
#   scripts/run-in-sim.sh --regen      run `xcodegen generate` + `pod install` first (needed after
#                                      adding/removing source files; the .xcodeproj is generated)
#   scripts/run-in-sim.sh --reset      uninstall first, wiping the app's data (tokens, settings)
#   scripts/run-in-sim.sh --logs       stream the app's os_log output after launch (Ctrl-C to stop)
#   scripts/run-in-sim.sh --save-settings
#                                      only back up the installed app's settings (API key, secret,
#                                      user agent, signed-in session) to SETTINGS_BACKUP, then exit
#   scripts/run-in-sim.sh --no-restore don't restore that backup after installing
#
#   After every install where the app has no client ID yet (first install, --reset), the
#   backup is imported before launch, so you stay signed in across resets. Values are only
#   copied between files, never printed. Mock runs never restore it.
#   SETTINGS_BACKUP=<path>             default ~/Library/Application Support/ApolloRebuild/sim-settings.plist
#   SIM=<name or UDID>                 simulator to use (default: the booted one; booted if needed)
#   MOCK_REDDIT=http://127.0.0.1:8765/ talk to tests/mock_reddit_server.py instead of Reddit: the
#                                      simulator copy (never the IPA) allows plain-HTTP loads, gets
#                                      RDK_API_BASE_URL / RDK_OAUTH_BASE_URL, and a placeholder
#                                      client ID if none is saved
#
# Outputs:
#   build/release/Apollo.xcarchive          the Release archive
#   build/release/Apollo-Rebuild-base.ipa   the unsigned device IPA (sideload base)
#   build/sim/Payload/Apollo.app            the simulator-converted copy that gets installed
#
# How the device build runs in the simulator (same approach as Apollo-Reborn's
# scripts/run-in-sim.sh): the arm64 code is identical on Apple Silicon, so only the
# platform tag blocks loading. Every Mach-O's LC_BUILD_VERSION is flipped from iOS (2)
# to iOS-Simulator (7) and the bundle is re-signed ad hoc. Two cases need more:
#   * Swift back-deploy dylibs (e.g. libswiftCompatibilitySpan.dylib) ship fat
#     arm64+arm64e for the device; they're swapped for Xcode's own iphonesimulator copies.
#   * Any other fat Mach-O is thinned to arm64 before patching.

set -euo pipefail

REBUILD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REBUILD_DIR"

DO_BUILD=1
DO_REGEN=0
DO_RESET=0
DO_LOGS=0
DO_SAVE_SETTINGS=0
DO_RESTORE=1
for arg in "$@"; do
    case "$arg" in
        --no-build) DO_BUILD=0 ;;
        --regen)    DO_REGEN=1 ;;
        --reset)    DO_RESET=1 ;;
        --logs)     DO_LOGS=1 ;;
        --save-settings) DO_SAVE_SETTINGS=1 ;;
        --no-restore)    DO_RESTORE=0 ;;
        -h|--help)  sed -n '2,38p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 1 ;;
    esac
done

RELEASE_DIR="$REBUILD_DIR/build/release"
ARCHIVE="$RELEASE_DIR/Apollo.xcarchive"
IPA="$RELEASE_DIR/Apollo-Rebuild-base.ipa"
SIM_DIR="$REBUILD_DIR/build/sim"
APP="$SIM_DIR/Payload/Apollo.app"

SETTINGS_BACKUP="${SETTINGS_BACKUP:-$HOME/Library/Application Support/ApolloRebuild/sim-settings.plist}"
DEFAULT_BUNDLE_ID=com.omarsalam.ApolloRebuild

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Sets DEV to SIM (name or UDID) or the booted simulator, booting it if needed
resolve_device() {
    if [[ -n "${SIM:-}" ]]; then
        DEV="$(xcrun simctl list devices available | grep -F "$SIM" | grep -oE '[0-9A-F-]{36}' | head -1 || true)"
        [[ -n "$DEV" ]] || die "no available simulator matching SIM=$SIM"
    else
        DEV="$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1 || true)"
        [[ -n "$DEV" ]] || die "no booted simulator — boot one, or pass SIM=<name or UDID>"
    fi
    if ! xcrun simctl list devices booted | grep -q "$DEV"; then
        log "Booting simulator $DEV"
        xcrun simctl boot "$DEV"
    fi
}

# The app's preferences plist in the simulator (empty if the app isn't installed)
app_prefs_path() {
    local container
    container="$(xcrun simctl get_app_container "$DEV" "$1" data 2>/dev/null || true)"
    [[ -n "$container" ]] && echo "$container/Library/Preferences/$1.plist"
}

# --save-settings: export the installed app's settings and stop. Reads go through
# cfprefsd (defaults export), so unflushed changes are included. Nothing is printed.
if [[ "$DO_SAVE_SETTINGS" == 1 ]]; then
    resolve_device
    BUNDLE_ID="$DEFAULT_BUNDLE_ID"
    [[ -f "$APP/Info.plist" ]] && BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
    PREFS="$(app_prefs_path "$BUNDLE_ID")"
    [[ -n "$PREFS" ]] || die "$BUNDLE_ID isn't installed on $DEV"
    CLIENT_ID="$(xcrun simctl spawn "$DEV" defaults read "$PREFS" redditClientID 2>/dev/null || true)"
    [[ -n "$CLIENT_ID" ]] || die "the app has no client ID saved yet — enter it on the sign-in sheet first"
    [[ "$CLIENT_ID" != "mock-client-id" ]] || die "the app holds the mock server's placeholder client ID; not saving that over a real backup"
    unset CLIENT_ID
    umask 077
    mkdir -p "$(dirname "$SETTINGS_BACKUP")"
    xcrun simctl spawn "$DEV" defaults export "$PREFS" "$SETTINGS_BACKUP.tmp"
    mv -f "$SETTINGS_BACKUP.tmp" "$SETTINGS_BACKUP"
    chmod 600 "$SETTINGS_BACKUP"
    log "Saved $BUNDLE_ID's settings to $SETTINGS_BACKUP (owner-only)"
    exit 0
fi

# CocoaPods crashes under Ruby 4 (Encoding::CompatibilityError) without a UTF-8 locale
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ----------------------------------------------------------------------------
# 1. Regenerate the project (optional) and archive.
# ----------------------------------------------------------------------------
if [[ "$DO_REGEN" == 1 ]]; then
    log "Regenerating ApolloRebuild.xcodeproj (xcodegen) and integrating pods"
    xcodegen generate --quiet
    pod install
fi

if [[ "$DO_BUILD" == 1 ]]; then
    mkdir -p "$RELEASE_DIR"
    log "Archiving Release (unsigned) — log: build/release/archive.log"
    if ! xcodebuild -workspace ApolloRebuild.xcworkspace -scheme Apollo -configuration Release \
            -destination 'generic/platform=iOS' \
            -archivePath "$ARCHIVE" \
            -derivedDataPath build/DerivedData-release \
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
            archive > "$RELEASE_DIR/archive.log" 2>&1; then
        grep -E 'error:' "$RELEASE_DIR/archive.log" | sort -u | head -20 >&2 || true
        die "archive failed (full log: build/release/archive.log). After adding source files, rerun with --regen."
    fi
fi

ARCHIVED_APP="$ARCHIVE/Products/Applications/Apollo.app"
[[ -d "$ARCHIVED_APP" ]] || die "no archive at $ARCHIVE — run without --no-build first"

# ----------------------------------------------------------------------------
# 2. Package the unsigned IPA (exportArchive needs signing, so zip Payload/ by hand).
# ----------------------------------------------------------------------------
log "Packaging $(basename "$IPA")"
mkdir -p "$RELEASE_DIR/ipa/Payload"
rsync -a --delete "$ARCHIVED_APP/" "$RELEASE_DIR/ipa/Payload/Apollo.app/"
(cd "$RELEASE_DIR/ipa" && zip -qry "$IPA.tmp" Payload)
mv -f "$IPA.tmp" "$IPA"

# ----------------------------------------------------------------------------
# 3. Convert a copy for the simulator.
# ----------------------------------------------------------------------------
log "Converting the app for the simulator"
mkdir -p "$SIM_DIR/Payload"
rsync -a --delete "$RELEASE_DIR/ipa/Payload/" "$SIM_DIR/Payload/"

SWIFT_LIB_DIRS=()
while IFS= read -r dir; do SWIFT_LIB_DIRS+=("$dir"); done < <(
    ls -d "$(xcode-select -p)"/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift*/iphonesimulator 2>/dev/null | sort -r
)

MACHOS=()
while IFS= read -r -d '' f; do
    file "$f" 2>/dev/null | grep -q 'Mach-O' || continue
    name="$(basename "$f")"

    if [[ "$name" == libswift*.dylib ]]; then
        replacement=""
        for dir in "${SWIFT_LIB_DIRS[@]}"; do
            [[ -f "$dir/$name" ]] && { replacement="$dir/$name"; break; }
        done
        [[ -n "$replacement" ]] || die "no iphonesimulator copy of $name in the Xcode toolchain"
        cp "$replacement" "$f"
        echo "  $name: replaced with the toolchain's simulator copy"
        continue
    fi

    if lipo -info "$f" 2>/dev/null | grep -q 'Architectures in the fat file'; then
        lipo -thin arm64 "$f" -output "$f.thin" && mv -f "$f.thin" "$f"
        echo "  $name: thinned to arm64"
    fi
    MACHOS+=("$f")
done < <(find "$APP" -type f -print0)

# Flip LC_BUILD_VERSION platform iOS (2) -> iOS-Simulator (7) in place
python3 - "${MACHOS[@]}" <<'PY'
import struct, sys
LC_BUILD_VERSION = 0x32
PLATFORM_IOS, PLATFORM_IOSSIMULATOR = 2, 7
for path in sys.argv[1:]:
    data = bytearray(open(path, 'rb').read())
    if struct.unpack('<I', data[0:4])[0] != 0xFEEDFACF:
        sys.exit(f"{path}: not a thin 64-bit Mach-O")
    ncmds = struct.unpack('<I', data[16:20])[0]
    off, patched = 32, False
    for _ in range(ncmds):
        cmd, size = struct.unpack('<II', data[off:off + 8])
        if cmd == LC_BUILD_VERSION and struct.unpack('<I', data[off + 8:off + 12])[0] == PLATFORM_IOS:
            struct.pack_into('<I', data, off + 8, PLATFORM_IOSSIMULATOR)
            patched = True
        off += size
    if not patched:
        sys.exit(f"{path}: no iOS LC_BUILD_VERSION to patch")
    open(path, 'wb').write(data)
print(f"  patched {len(sys.argv) - 1} Mach-O files to iOS-Simulator")
PY

if [[ -n "${MOCK_REDDIT:-}" ]]; then
    # The mock server is plain HTTP on localhost
    /usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity dict' -c 'Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true' "$APP/Info.plist"
    echo "  allowed plain-HTTP loads for the mock server (simulator copy only)"
fi

# Re-sign ad hoc, inside out (frameworks/dylibs, then plugins, then the app)
if [[ -d "$APP/Frameworks" ]]; then
    find "$APP/Frameworks" -maxdepth 1 \( -name '*.framework' -o -name '*.dylib' \) -print0 \
        | while IFS= read -r -d '' item; do codesign -f -s - "$item" 2>/dev/null; done
fi
if [[ -d "$APP/PlugIns" ]]; then
    find "$APP/PlugIns" -maxdepth 1 -name '*.appex' -print0 \
        | while IFS= read -r -d '' item; do codesign -f -s - "$item" 2>/dev/null; done
fi
codesign -f -s - "$APP" 2>/dev/null
codesign -v "$APP" || die "ad-hoc signature didn't verify"

# ----------------------------------------------------------------------------
# 4. Pick (and boot) the simulator, install, launch.
# ----------------------------------------------------------------------------
resolve_device
open -b com.apple.dt.Devices >/dev/null 2>&1 || true

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
xcrun simctl terminate "$DEV" "$BUNDLE_ID" >/dev/null 2>&1 || true
if [[ "$DO_RESET" == 1 ]]; then
    log "Uninstalling $BUNDLE_ID (wipes its data)"
    xcrun simctl uninstall "$DEV" "$BUNDLE_ID" >/dev/null 2>&1 || true
fi

log "Installing and launching $BUNDLE_ID on $DEV"
xcrun simctl install "$DEV" "$APP"
PREFS="$(app_prefs_path "$BUNDLE_ID")"

# Restore the saved settings into a fresh install (before launch, so the app reads them on start)
if [[ -z "${MOCK_REDDIT:-}" && "$DO_RESTORE" == 1 && -s "$SETTINGS_BACKUP" ]] \
   && ! xcrun simctl spawn "$DEV" defaults read "$PREFS" redditClientID >/dev/null 2>&1; then
    xcrun simctl spawn "$DEV" defaults import "$PREFS" "$SETTINGS_BACKUP"
    log "Restored saved settings from $SETTINGS_BACKUP"
fi

if [[ -n "${MOCK_REDDIT:-}" ]]; then
    if ! xcrun simctl spawn "$DEV" defaults read "$PREFS" redditClientID >/dev/null 2>&1; then
        xcrun simctl spawn "$DEV" defaults write "$PREFS" redditClientID mock-client-id
    fi
    log "Using the mock Reddit server at $MOCK_REDDIT"
    SIMCTL_CHILD_RDK_API_BASE_URL="$MOCK_REDDIT" SIMCTL_CHILD_RDK_OAUTH_BASE_URL="$MOCK_REDDIT" \
        xcrun simctl launch "$DEV" "$BUNDLE_ID"
else
    xcrun simctl launch "$DEV" "$BUNDLE_ID"
fi
log "IPA: $IPA"

if [[ "$DO_LOGS" == 1 ]]; then
    log "Streaming logs (subsystem com.omarsalam.apollo) — Ctrl-C to stop"
    xcrun simctl spawn "$DEV" log stream --level debug --predicate 'subsystem == "com.omarsalam.apollo"'
fi
