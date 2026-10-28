# AGENTS.md

## Project Overview

Apollo-Reborn is an iOS tweak for the Apollo for Reddit app that adds in-app configurable API keys and several bug fixes/improvements. Built using the Theos framework, it hooks into Apollo's runtime to provide custom API credential management, sideload fixes, and media handling improvements.

## Build & Development Commands

```bash
# Sync submodules (required before first build)
git submodule update --init --recursive

# Standard build
make package

# Build a local test IPA from the persistent Apollo base IPA
# (--fix-safari-extension packages the manual + legacy Safari extensions;
# release builds always apply it, so local device-test IPAs should too)
./patch.sh ./Apollo-base.ipa --liquid-glass --fix-safari-extension -o /tmp/Apollo-base-liquid-glass.ipa
./build-ipa.sh --ipa /tmp/Apollo-base-liquid-glass.ipa --deb ./packages/<tweak>.deb -o ./packages/Apollo-Test.ipa
```

The Makefile automatically generates `src/Version.h` from the `control` file and links FFmpegKit libraries.
`THEOS` is available at `~/theos`. Do not rely on Azule/Cyan living in `/tmp`; `build-ipa.sh` uses the repo-local `scripts/inject-deb-local.sh` first for this repo's already-injected `Apollo-base.ipa` flow, then falls back to `azule`/`cyan` only for truly stock IPAs.

**macOS 27 / Apple Silicon without Rosetta:** azule's bundled helpers (`~/Azule/bin/darwin/{ldid,insert_dylib,jq}`) are x86_64-only and upstream has not shipped arm64 builds, so azule fails with `Bad CPU type in executable` once Rosetta is gone. Replace them in place with arm64 builds (`brew install ldid jq` and symlink those two; compile `insert_dylib` from Tyilo/insert_dylib `main.c` with `clang -arch arm64`). They must live in that directory because azule prepends it to `PATH`. Separately, Xcode 27's `lipo` only recognizes the bundled CydiaSubstrate's legacy arm64e slice as `arm64e.old`; `scripts/modules/strip-substrate-arm64e.sh` handles both spellings and fails the build (rather than warning) if the slice cannot be removed, since shipping it aborts at launch on arm64e iOS 26 devices.

### Required SDK: iOS 26.0 pinned via `$THEOS/sdks` (device builds only)

Device `make package` defaults to `TARGET := iphone:clang:26.0:14.0`. Keep this SDK pin for release builds so the tweak continues to support iOS 14. Installing a newer Xcode or device SDK does not change that default.

The iOS 27.1 SDK declares `SupportedTargets.iphoneos.MinimumDeploymentTarget = 15.0` in `SDKSettings.json`. Pinning that SDK by name does **not** bypass its minimum. A developer-only newer-SDK build must explicitly select both SDK and a compatible deployment target, for example `make package APOLLO_DEVICE_SDK=27.1 APOLLO_DEVICE_DEPLOY=15.0`; that artifact does not support iOS 14. The Makefile rejects alternate SDK pins without an explicit iOS 15-or-newer deployment target. Check the selected SDK's metadata for any higher minimum. Explicit command-line `TARGET` remains authoritative; the simulator script supplies `TARGET=simulator:clang:latest:15.0` and bypasses device defaults.

Theos merges SDK candidates from `$THEOS_SDKS_PATH` (`$THEOS/sdks`) and the selected Xcode's SDK directory (see `$THEOS/makefiles/targets/_common/darwin_head.mk`). It matches the folder name `iPhoneOS<version>.sdk`. A real `iPhoneOS26.0.sdk` under `$THEOS/sdks` therefore supplies the release SDK without changing the Xcode.app bundle or switching the host's active toolchain. `DEVELOPER_DIR` is respected.

**The simulator needs its current SDK.** A simulator binary links to the host's system libraries. Pairing an old Simulator SDK with a newer compiler is incompatible; see the simulator section below. The simulator uses a local-only iOS 15 deployment floor. This does not change the device release floor.

Because the default device build (14.0) and simulator build (15.0) have different floors, an iOS-15-deprecated API can warn only in the simulator build. Theos enables `-Werror` globally. `ApolloReborn_CFLAGS` includes `-Wno-error=deprecated-declarations`, leaving these warnings visible without failing local simulator builds. Prefer safe non-deprecated replacements where available; retain iOS 14 availability guards for APIs such as `UIButtonConfiguration`.

**If `$THEOS/sdks/iPhoneOS26.0.sdk` is missing**, get a genuine SDK in this order:

1. Extract it from a locally installed Xcode 26.x:
   ```bash
   cp -R "/Applications/Xcode_26.x.x.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk" \
         "$THEOS/sdks/iPhoneOS26.0.sdk"
   ```
2. [theos/sdks](https://github.com/theos/sdks), if the required version is available.
3. [xybp888/iOS-SDKs](https://github.com/xybp888/iOS-SDKs), if the required version is available. This is a third-party SDK dump; prefer an Apple-issued local copy.

Check `SDKSettings.json` → `Version` before copying. Do not rename an older SDK to impersonate a newer one. An iOS 27.1 Simulator runtime is also not a device SDK. For an explicit 27.1 developer build, use the real 27.1 device SDK and its compatible deployment floor described above.

Verify the installed SDKs with:
```bash
xcodebuild -showsdks 2>&1  # Xcode's SDKs; does not show $THEOS/sdks entries
ls "$THEOS/sdks/"
```
The SDK lives outside the repo and must be installed separately on a new development machine.

**CI** selects `/Applications/Xcode_26.0.1.app` before `make package`, which supplies the same pinned iOS 26.0 SDK and iOS 14 release floor directly. Local developers with newer Xcode should keep the 26.0 SDK in Theos instead of changing the global Xcode selection.

### Fast iteration in the iOS Simulator

For UI/settings/nav-bar/Liquid Glass work, `scripts/run-in-sim.sh` runs the tweak inside the iOS Simulator so you can test a change in seconds without building an IPA, signing, or sideloading. **Use this as the default inner loop**; fall back to a device IPA only for the things the simulator can't do (see limits below).

```bash
scripts/run-in-sim.sh              # build the sim tweak, (re)prepare Apollo, launch it injected
scripts/run-in-sim.sh --no-build   # relaunch without rebuilding the tweak
scripts/run-in-sim.sh --logs       # also stream ApolloLog (os_log subsystem "apollofix") after launch
scripts/run-in-sim.sh --drive      # after launch, capture the idb accessibility tree + a screenshot to ./.sim/
scripts/run-in-sim.sh --fresh-app  # re-patch the base IPA from scratch (after a new apollo-base.ipa)
scripts/run-in-sim.sh --dark       # boot the simulator in dark mode (--light forces light)
scripts/run-in-sim.sh --glass      # apply the iOS 26 Liquid Glass patch (--no-glass disables)
scripts/run-in-sim.sh --backup B.zip  # preload an Apollo settings backup (API keys + account)
BUNDLE_ID=com.you.Build scripts/run-in-sim.sh   # run under a custom (rebranded) bundle id
```

How it works (and why each piece is needed):

- **Apollo runs in the sim** because the script patches every Mach-O in `Payload/Apollo.app` (main binary + appex + frameworks) from `LC_BUILD_VERSION` platform iOS (2) to iOS-Simulator (7) and re-signs ad-hoc. The arm64 code is identical on an Apple Silicon Mac; only the platform tag blocks loading. This shell is cached under `./.sim/` and only re-prepared on `--fresh-app`.
- **The tweak is built for the sim** with `make TARGET=simulator:clang:latest:15.0 LOGOS_DEFAULT_GENERATOR=internal APOLLO_SIM_BUILD=1`. Unlike the device build, this deliberately uses `latest` rather than pinning to an older SDK: a simulator binary runs in-process on the build host, dynamically linking against *this Mac's actual* libSystem/Foundation/libc++, not a separate per-version runtime the way a real device has its own matching system libraries. Pairing the iOS 26.0 Simulator SDK with a newer (iOS 27-era) clang hits a hard, intentional block — `module '_c_standard_library_obsolete' requires feature 'found_incompatible_headers__check_search_paths'` — which is Apple's clang correctly refusing a genuinely unsafe combination, not a quirk to route around. So the simulator build's floor was bumped to iOS 15.0 (`DEPLOY_MIN` in `scripts/run-in-sim.sh`) instead of SDK-pinning like the device build does; this only affects local dev/testing convenience, not real iOS 14 device support (which is fully covered by the shipped device build's `iphone:clang:26.0:14.0` target). The *internal* Logos generator swizzles via the ObjC runtime, so the dylib has **no CydiaSubstrate dependency** (the shipped device build links CydiaSubstrate, which can't load in the sim). `APOLLO_SIM_BUILD=1` makes the Makefile skip device-only **FFmpegKit** and the FLEX/openin subprojects, and `ApolloMedia.xm` stubs its FFmpeg v.redd.it audio fix under the same macro. `MSHookIvar` still works (it's a header-only ObjC-runtime template, force-included via `-include substrate.h`).
- **The tweak is injected** via `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES` pointing at `./.sim/ApolloReborn.dylib`. Code-only changes are just `scripts/run-in-sim.sh` again (rebuild + relaunch); no reinstall.
- **The bundle id is configurable** via `BUNDLE_ID=...` (defaults to `com.christianselig.Apollo`). When it differs from the cached shell's id, the script re-prepares and rebrands the app + every appex `CFBundleIdentifier` (mirroring `scripts/rebrand-ipa.sh`; the `apollo://` scheme and the `group.com.christianselig.apollo` app group are left intact). Switching ids forces one re-prep (~15s), then caches. Device/runtime are overridable via `SIM_NAME`, `SIM_DEVICE_TYPE`, `SIM_RUNTIME`.
- **Settings backups preload via `--backup file.zip`** (or `BACKUP_ZIP=...`, or by dropping the zip at `./.sim/backup.zip`, which is auto-loaded when no `--backup` is given): the script uninstalls first (wiping the data container + cfprefsd cache), reinstalls, then copies the backup's `preferences.plist` to `<container>/Library/Preferences/<BUNDLE_ID>.plist`, `group.plist` to `…/group.com.christianselig.apollo.plist`, and (if present) `keychain.plist` to `…/Library/Caches/ApolloKeychainSeed.plist`. In the simulator both the app and app-group domains live in the app data container (the group suite falls back there without full app-group provisioning), matching the tweak's own `NSHomeDirectory()`-based restore path. **A backup contains live account credentials; keep test zips out of the repo** (`./.sim/` is gitignored).
  - **What loads:** the API keys (Reddit/Imgur/Giphy/ImageChest), the app-only OAuth session, **and your signed-in Reddit user account** — so profile, inbox, and voting work, not just browsing.
  - **How the account restore works (and why it used to fail):** Apollo's `AccountManager` loads logged-in accounts on launch from the **keychain via Valet** (key `2RedditAccounts2`), and the *whole* load is gated behind `Valet.canAccessKeychain()`. An ad-hoc-signed simulator app has no `application-identifier`/`keychain-access-groups` entitlement, so securityd rejects every `Sec*` call with `errSecMissingEntitlement` (-34018) even after we strip `kSecAttrAccessGroup` — `canAccessKeychain()` returns NO, the load is skipped, and the restored account is pruned (`RedditAccounts2` ~50KB → ~219-byte empty array). Adding the entitlement is a dead end (the iOS-26 simulator refuses to launch an ad-hoc app carrying it). **Fix:** the tweak virtualizes Valet's keychain in the sim (`#if APOLLO_SIM_BUILD` in `Tweak.xm` — a plist-backed store under `Library/Caches/ApolloSimKeychain.plist` that backs `SecItemAdd/CopyMatching/Update/Delete` for Valet queries, so `canAccessKeychain()` passes and reads/writes work). The account blob can't be synthesized from the NSUserDefaults mirror — Apollo's keychain format is an array of `[String:String]` dicts, not the `[RDKClient]` archive the defaults hold — so `Backup Settings` now **captures Apollo's real Valet keychain items** (`src/settings/ApolloBackupRestore.m` → `keychain.plist`), and the sim seeds the virtual store from them. **Requires a backup exported by a build with this feature**; older backups have no `keychain.plist` and the account won't restore (the script prints a note). Device restore replays the same items into the real keychain.
- **Appearance** is set with `xcrun simctl ui <DEV> appearance dark|light` via `--dark`/`--light` (or `APPEARANCE=`); it persists on the device until changed.
- **Liquid Glass** is off by default (the raw `apollo-base.ipa` links against the iOS 16 SDK, so `IsLiquidGlass()` is NO and both UIKit's iOS-26 chrome and the tweak's LG hooks stay dormant). **This assumes `apollo-base.ipa` is a fresh, unpatched decryption of the Apollo binary** — since it's gitignored and supplied per-developer, if yours has already been run through `patch.sh --liquid-glass` (or came from a pre-patched/glass distribution build) it'll read as glass-linked (`sdk 19.0`+) no matter what flags you pass, and `--no-glass` won't undo it, since the re-prep just re-extracts your already-glass base — re-source a clean, unpatched IPA instead of trying to downgrade it in place. `--glass` (or `GLASS=1`) prepares the shell from a `patch.sh --liquid-glass` base — the canonical glass patcher, reused so it stays in sync: it bumps the main binary's linked SDK to **27.1** (which flips `IsLiquidGlass()` because the major is still >= 19, and is what iPhone Duo needs to stop letterboxing a phone-sized column), drops the duplicate `@executable_path/Frameworks` LC_RPATH (iOS-26 dyld rejects it — otherwise the launch dies with an `SBMainWorkspace` denial), swaps in the prebuilt `Assets.car`, and writes the `CFBundleAlternateIcons` metadata that turns on the in-app icon picker. The glass base is cached at `./.sim/glass-base.ipa` (regenerated when `apollo-base.ipa` changes or the cached stamp is not `27.1`); toggling `--glass`/`--no-glass` re-prepares the app shell (detected from the cached main binary's SDK). A leftover `sdk 19.0` glass shell still counts as glass for `IsLiquidGlass()` but Duo will letterbox it — `--fresh-app` after this bump.

**Verify the tweak actually loaded** (don't assume from a clean launch): check os_log for the `apollofix` subsystem — module load lines and `... hook installed ...` confirm the internal-generator hooks took:

```bash
xcrun simctl spawn "$(cat .sim/device.txt)" log show --last 2m --predicate 'subsystem == "apollofix"' | grep ApolloFix
```

**Driving the UI yourself (idb):** use matching **idb client and companion 1.7.7 or newer** (`brew install facebook/fb/idb` installs both). The current Python client supports Python 3.10+; 1.7.7 was verified with Python 3.14. The Python 3.11 restriction applies to the old 1.1.x client. For a separate client environment, point the script at it with `IDB=/path/to/venv/bin/idb scripts/run-in-sim.sh --drive` and keep the matching companion on `PATH`; direct CLI calls also accept `--companion-path`. Useful commands: `idb ui describe-all --udid <DEV>` (accessibility tree with labels + frames), `idb ui tap <x> <y>`, and `idb ui text "..."`. Prefer native HID input for gesture verification and read screenshots back to confirm results.

**Xcode 27 / Device Hub:** Simulator.app is now Device Hub (`com.apple.dt.Devices`); `run-in-sim.sh` opens Device Hub only and never falls back to Simulator.app. Use Simulator.app only for a specific capability Device Hub cannot provide, explain that special case first, and close it afterward while keeping Device Hub open. Old idb_companion 1.1.8 looks for `SimulatorKit.framework` at `Contents/Developer/Library/PrivateFrameworks/`; Xcode 27 moved it to `Contents/SharedFrameworks/`. idb 1.7.7 supports the new location, so upgrade both components rather than modifying Xcode.app. `--drive` still captures via `simctl io screenshot`. For Duo's multiple displays, explicitly capture the active display with `xcrun simctl io <DEV> screenshot --display=<ID> out.png`: an inactive display can be black while Apollo is running correctly. Use Device Hub's actual posture and rotation controls when verifying folding or orientation changes.

**Simulator limits — use a device IPA for these:** APNs push (so Live Activities push-to-start can't be exercised in the sim), the FFmpeg v.redd.it CMAF/MPEG-TS audio remux (stubbed out), and anything genuinely device-only. (A signed-in user account *does* work in the sim now, via the keychain-capture backup above — provided the backup was exported by a build with that feature.) The sim *is* the same iOS 26.x family as the test device, so Liquid Glass nav-bar/tab-bar behavior reproduces faithfully.

### Sideloading a rebranded real-device test build from a stock Apollo IPA

This is the from-scratch path for when you have no persistent `Apollo-base.ipa` shell yet (the quick-start `patch.sh` → `build-ipa.sh` commands above assume one already exists) and want a device install that coexists with the App Store Apollo.

**1. Get a stock, decrypted Apollo IPA.** This repo does not host or bundle Apollo's IPA — Apollo is Christian Selig's app, delisted from the App Store in 2023. CI's `build-ipa.yml` workflow defaults its `apollo_ipa_url` input to `https://downloads.apolloreborn.app/apollobase.ipa`, a base IPA the Apollo-Reborn project maintains; that's the fastest path if you don't have your own extracted copy, but treat any base-IPA source as something *you* fetch and name explicitly rather than something an agent should infer/download unprompted. Verify integrity after downloading: `unzip -t Apollo.ipa`.

**2. Local device builds may need `ARCHS=arm64` forced.** The Makefile declares `export ARCHS = arm64` at the top, but a stock Theos install's `$THEOS/makefiles/common.mk` unconditionally sets `ARCHS = arm64 arm64e` *after* that (plain `=`, not `?=`), so it silently wins and the build attempts an arm64e slice too. The checked-in FFmpegKit static libs (`modules/ffmpeg-kit/`) are arm64-only by design (per that submodule's own README), so the arm64e slice fails to link with `Undefined symbols ... _OBJC_CLASS_$_FFmpegKit`. Fix: force the arch on the command line, which has the highest precedence over both `?=` and plain `=` in included makefiles:
```bash
make package FINALPACKAGE=1 ARCHS=arm64
```
This isn't a workaround/hack — `arm64` is genuinely the only architecture this project ships, and the only one any current iPhone needs. Apple doesn't require third-party apps or injected tweaks to carry a separate `arm64e` slice even on arm64e-capable hardware (A12+, including the A17 Pro in an iPhone 15 Pro/Pro Max) — `arm64` is the universal 64-bit slice.

**3. Inject the tweak BEFORE patching, for a from-scratch stock IPA — the opposite order from the quick-start above.** The quick-start's `patch.sh` → `build-ipa.sh` order assumes a locally-prepared, pre-injected `Apollo-base.ipa` shell for fast iteration (`build-ipa.sh`'s `inject-deb-local.sh` fast path only works against that shell). Starting from a truly stock IPA, mirror CI's order instead:
```bash
./build-ipa.sh --ipa Apollo.ipa --deb ./packages/<tweak>.deb -o injected.ipa   # falls back to `cyan` (pyzule-rw) for a stock IPA
./patch.sh injected.ipa --liquid-glass -o glass.ipa                           # Liquid Glass AFTER injection, not before
```
`build-ipa.sh` printing `Error: IPA is not already prepared to load: ...` and falling back to `cyan` is expected for a stock IPA, not a failure. Install `cyan` if missing: `pip install "https://github.com/asdfzxcvbn/pyzule-rw/archive/refs/tags/v1.4.4.zip"` (CI does this in a venv). A `unzip: cannot find ... injected.ipa` line mid-run from `build-ipa.sh`'s own slice-fix step is cosmetic — trust `unzip -t injected.ipa` after the run finishes, not that inline warning.

**4. Rebrand to a bundle ID you own** so the test build can coexist on-device with the App Store version:
```bash
./scripts/rebrand-ipa.sh glass.ipa com.yourname.YourAppName -o Final.ipa
```
Rewrites `CFBundleIdentifier` on the app and every `.appex` (suffix preserved, e.g. `.Apollofari`, `.AthenaWidget`), while deliberately leaving `group.com.christianselig.apollo` and the `apollo://` URL scheme untouched (see the script's own header comment for why — the tweak hardcodes the app group regardless of bundle ID, and the URL scheme is a literal, not derived from it).

**5. Sign and install.** Any signer produces a basic working install, but two things vary by signer:
- **Push notifications** require an explicit App ID with Push enabled under a team *you* control. A shared enterprise-cert mass-signing service (Signulous and similar) can't give you that; AltStore/SideStore with your own Apple ID can.
- **The "Open in Apollo" share action** needs the appex main-binary code-signing flag set. AltStore/SideStore, Xcode, and Apple's own `codesign` set it; `zsign`-based signers (many paid mass-signing services, some Sideloadly/Feather configurations) don't, and the appex silently no-ops at launch instead of erroring. Fix after the fact with `scripts/resign-ipa-codesign.sh <input.ipa> "<your signing identity>" -o Resigned.ipa`, then install the **resigned** output directly (`ideviceinstaller`, Apple Configurator drag-install, `xcrun devicectl device install app`) — re-signing it again through the original signer undoes the fix.
- If a previous test build under a different bundle ID is already installed, uninstall it first to avoid an `apollo://` scheme collision between the two.

## Project Structure

### Core Tweak Modules

| Path | Purpose |
|------|---------|
| `src/Tweak.xm` / `src/Tweak.h` | Main tweak entry point and core runtime hooks |
| `src/Apollo*.xm` | Feature-focused Logos modules; see `Makefile` for the current build list |
| `src/ApolloCommon.{h,m}` | Shared utilities, including `ApolloLog` and helper functions |
| `src/ApolloWebTextDecoding.{h,m}` | Charset-aware decode of bytes fetched from arbitrary third-party pages (BOM → `Content-Type` → `<meta charset>`, plus the WHATWG label upgrades). Use this instead of `initWithData:encoding:NSUTF8StringEncoding` for any *foreign* page — a UTF-8 guess mojibakes EUC-KR/Shift_JIS/GB18030/Big5 sites. Foundation-only, so the `.m` compiles straight into a host-side harness |
| `src/ApolloWebJSONWriteRepair.{h,m}` | The comment/self-text write-response repair (legacy old-reddit shape → modern JSON), split out of `ApolloWebJSON.m` so it stays Foundation-only. Network-free by design: it runs inside `RDKResponseSerializer`; edits are filled from the pre-edit model captured at submit time. Host-side harness: `tests/run_web_json_write_repair_tests.sh` |
| `src/ApolloUpdateManifest.{h,m}` + `src/ApolloUpdateChecker.{h,m}` + `src/ApolloUpdatePromptViewController.{h,m}` | In-app update prompt (a half-height form sheet like the account switcher: medium + large detents, grabber; Release Notes expands it to full height and shows the changelog from the variant's source JSON, prefetched when the sheet appears, with Update / Later / Skip pinned underneath, and Update opens a sideloader-chooser page that slides in; the real app icon comes from the shared `ApolloAppIcon.{h,m}`, which What's New also uses, including picked Icon Composer alternates). A sideloaded app can't replace itself, so this reads `release-manifest.json` from `main`, picks the installed variant's entry from the stamped `ARBuildVariant` (`ApolloBuildVariant()`), and hands off to the user's sideloader: that variant's AltStore/SideStore source, `feather://install/` or `flarestore://downloadApp=` with its IPA. A build that can't name its variant (an injected `.deb` with no release stamp, e.g. a `Build IPA` run) only has its sideloader apps opened bare and swaps the IPA download for the release page, because any guess at the variant could silently swap the user's build; dev builds get the release page alone. `ApolloUpdateManifest` is Foundation-only (version normalize/compare, variant mapping, https-only URL parsing, sideloader URLs) with a host harness: `tests/run_update_manifest_tests.sh`. The checker revalidates the manifest every 15 minutes while active (opt-out `UDKeyAutomaticUpdateChecks`), checks on foreground when due, and retries failures after 5 minutes. `ApolloUpdateManifestCache.{h,m}` persists the public manifest and ETag together under Library/Caches; unchanged responses reuse the validated body. Automatic prompts appear only over the base UI; Later (including swipe dismissal and chooser Cancel) snoozes that exact version for 24 hours across launches via `UDKeyUpdateDeferredReminder`, while `UDKeyUpdateSkippedVersion` hides a version indefinitely. A newer version can prompt during a snooze. Jailbroken `.deb` installs do not check. Host harnesses: `tests/run_update_manifest_cache_tests.sh` and `tests/run_update_checker_tests.sh`. The prompt appears as soon as the check finds an update, waiting only while What's New is due. Sim builds accept `APOLLO_UPDATE_MANIFEST_URL` / `APOLLO_UPDATE_NOTES_URL` (incl. `file://`) and `APOLLO_UPDATE_BUILD_VARIANT` env overrides (pass via `SIMCTL_CHILD_`; `unstamped` models an injected IPA with no stamp, any other `deb-*` value a package-manager install) since sim builds have no variant stamp and the live manifest matches the running version |
| `src/ApolloState.{h,m}` | Global state, captured singletons, and feature flags |
| `src/ApolloClasses.{h,m}` | Shared table of the classes looked up by name (`ApolloClass…` globals), resolved once at launch by a constructor that runs before every `%ctor`; plus lazy accessors for the few classes whose image loads later. See "Looking up classes by name" below |

### Settings & UI (`src/settings/`)

Tweak-owned settings screens live under `src/settings/` and are built on a
declarative form layer — rows are data, indices are derived, no index math in
screens. See `docs/settings-form-refactor-plan.md`.

| Path | Purpose |
|------|---------|
| `src/settings/ApolloSettingsForm.{h,m}` | Declarative row/section model + `ApolloSettingsFormViewController` base (visibility snapshot + diff, identity-based reloads, shared "(Current)" picker). Subclass, override `-buildForm`. |
| `src/settings/ApolloSettingsTableViewController.{h,m}` | Theming base (accent walk) all settings screens share |
| `src/settings/CustomAPIViewController.{h,m}` | Root "Apollo Reborn" settings screen (API keys, General, Media, Subreddits, About, ...) — a form subclass |
| `src/settings/ApolloBackupRestore.{h,m}` | Backup/restore engine (zip build, plist replay, Valet keychain capture/replay); the VC keeps only the UI |
| `src/settings/ApolloContributors.{h,m}` + `ApolloThanksTo`/`ApolloBuyUsACoffee` VCs | contributors.json fetch/parse + the two About screens (dynamic lists, hand-rolled) |
| `src/settings/ApolloSettingsGeneralTable.{h,xm}` | Single owner of Apollo's NATIVE Settings > General table geometry (row hide/inject registry + NSProxy remapper) — for the table we don't own |
| `src/settings/SavedCategoriesViewController.{h,m}` | Saved post categories CRUD (add/rename/delete, stored in group NSUserDefaults; not a form — dynamic list) |
| `src/settings/ApolloActionMenuSettingsViewController.{h,m}` + `src/ApolloActionMenuLayout.{h,m}` | Interface → Action Menus: per-menu (feed / post / post-in-comments / comment) ••• item order + hidden set, with a pinned live mock of the menu. The model (contexts, item catalogue keyed by Apollo's Action kinds, saved layouts) uses Foundation and UIKit; `ApolloActionMenu.xm` applies it by permuting the sheet's Swift `actions` buffer in place and filtering/ranking the registered specs |

**Working on settings? Read `src/settings/README.md` first** — it has the 5-step add-a-setting recipe, the form-layer rules, and the Eureka facts. The hard rules: tweak-owned screens declare rows in `-buildForm` (never hand-rolled index math); Apollo's native General screen is modified ONLY through `ApolloSettingsGeneralTable`'s registry (never `%hook` its table methods — one remapper per screen); new settings do NOT get added to `ApolloBackupRestore`'s statics re-sync (restore force-exits; `%ctor` re-reads on relaunch).

**Settings cell primary text is opt-in.** Standard form rows are marked
automatically; normal enabled `customRow` and hand-rolled cells must call
`apollo_applyPrimaryTextColorToCell:` before returning. Do not mark accent,
destructive, disabled/placeholder, or intentionally secondary/tertiary rows.

### Siri & Spotlight (`siri/`, optional iOS 27)

A separate `ApolloSiri.framework` (App Intents entities, Spotlight indexing, onscreen context) injected by `scripts/inject-siri-proof.sh`; not part of `make package` or release builds. Tweak-side hooks live in `src/ApolloIntelligenceBridge.xm` and no-op without the framework. **Read `siri/README.md` before changing it** (packaging, privacy scope, known Siri limitations). Host tests: `bash scripts/test-siri-catalog.sh`.

### Crash Reporting (`src/crash/`)

Local-only crash recording built on KSCrash 2.5.1's **recording layer only** (`modules/KSCrash` submodule, pinned; only Core/RecordingCore/Recording compile — no sinks/filters/installations, so no transmission path exists in the binary). Every public KSCrash symbol AND ObjC class is namespaced via `-DKSCRASH_NAMESPACE=_ApolloReborn` (global CFLAG — required in every TU that imports KSCrash headers). Reports live under `Library/Caches/ApolloReborn/LocalCrashReports` (max 3, cleanup policy Never) and leave the device only through the user-reviewed report-form flow.

| Path | Purpose |
|------|---------|
| `src/crash/ApolloCrashManager.{h,m}` | Installs KSCrash first thing in `%ctor` (privacy-locked: no memory introspection, no queue names, no console log, no `__cxa_throw` swap), fronts the report store (enumerate / load+sanitize / delete) |
| `src/crash/ApolloCrashSanitizer.{h,m}` | **Allowlist** converter: raw KSCrash dict → `apollo_reborn_crash` schema; omits all free-form exception text and permits only known system exception/action identifiers, hex-ifies addresses, hard caps (1MB / 128 threads / 256+64 frames / 512 images, referenced-first). Raw dicts never leave the manager |
| `src/crash/ApolloCrashContext.{h,m}` | Enumerated recent-actions ring buffer (the API takes an enum — free-form strings are impossible by design) published into KSCrash userInfo, debounced |
| `src/crash/ApolloCrashPromptCoordinator.{h,m}` | Once-per-report relaunch prompt (Review & Report / Not Now / Delete). "Not Now" never re-nags — prompted IDs persist in `UDKeyCrashPromptedReportIDs`; the report stays under Settings → Privacy → Crash Reports |
| `src/crash/ApolloCrashReviewViewController.{h,m}` | Consent screen (form subclass): included/never-included lists, exact sanitized-JSON viewer, share-sheet export, optional off-by-default debug-log inclusion, Continue → report form |
| `src/crash/ApolloCrashReportsViewController.{h,m}` | Settings screen: capture toggle (`UDKeyCrashCaptureEnabled`, default ON; KSCrash installs once per process so it takes effect next launch) + pending report list. Registered as route `crash-reports` |
| `src/crash/ApolloCrashBugsnagNeutralize.xm` | No-ops every Bugsnag start entry point so Apollo's embedded (KSCrash-fork) recorder never installs handlers, breadcrumbs activity, or maintains device/user UUIDs — the upload-domain blocklist alone never stopped local capture |

Key invariants: the local KSCrash report is deleted only on explicit user action or after report.apolloreborn.app confirms (via the `reportSubmitted` bridge message in `ApolloReportViewController`) a submission that still included the crash attachment — closing the form, losing connectivity, or removing the attachment keeps it. The report store's fixer returns `report.timestamp` as microseconds OR a 6-digit-fraction UTC string depending on path — the sanitizer normalizes both. The web half of the bridge (`attachTextFile`, filename-level `bridgeFilesChanged`, `reportSubmitted`, the `source=crash-recovery` issue label) lives in the apolloreborn-site repo (`report/form.html` + worker); the native side degrades to the legacy `attachLog` bridge against older site deployments and then never auto-deletes the local report.

Testing: with FLEX debugging enabled, Settings → Privacy → Crash Reports gains a Testing section — "Write Test Report (No Crash)" records a real report via KSCrash's user-reported path (`-[ApolloCrashManager writeTestCrashReport]`, `terminateProgram:NO`) and exercises review/share/submit without killing the app; "Crash Now (NSException)" genuinely crashes for full capture + relaunch-prompt testing. Works on device and sim. The sim debug bridge additionally has `echo "crash <nsexception|abort|badaccess|overflow>" > /tmp/apollofix-tap.txt && xcrun simctl spawn <DEV> notifyutil -p apollofix.debugtap` for scripted crashes. Never test Mach-exception handling under a debugger (it changes exception ownership). Exported sanitized JSON symbolicates with the release-dSYM workflow below (instruction/image addresses + UUIDs are preserved).

### Runtime & Libraries

| Path | Purpose |
|------|---------|
| `src/fishhook.{c,h}` | Facebook's fishhook for C function rebinding (Security framework, `swift_allocObject`) |
| `modules/ffmpeg-kit/` | FFmpegKit static libs for v.redd.it CMAF video processing |
| `modules/ZipArchive/` | SSZipArchive for settings backup/restore zip export |
| `modules/KSCrash/` | KSCrash 2.5.1 (git submodule, pinned) — recording modules only; see Crash Reporting section |
| `modules/FLEXing/` | FLEX debugging tools (git submodule) |

### Reference & Build

| Path | Purpose |
|------|---------|
| `Headers/` | Class-dump headers for Apollo |
| `packages/` | Build output (.deb files) |
| `control` | Debian package metadata (name, version, depends) |
| `Makefile` | Theos build config; auto-generates `src/Version.h`, links FFmpegKit |

## Theos & Logos Conventions

- Use Logos directives (`%hook`, `%orig`, `%group`, `%ctor`) for runtime patches
- Use `%hookf` for C function hooks
- Register new source files in `Makefile` under `ApolloReborn_FILES`
- Keep related hooks grouped together
- **`%orig` passes original arguments**: `%orig;` always calls the original method with the original captured arguments, even if you've reassigned the local parameter variables. To pass modified values, use explicit arguments: `%orig(arg1, modifiedArg2, arg3)`. This matters when normalizing URLs in blocks/callbacks — the ignoreHandler must use `%orig(textNode, attr, val, point, range)` not bare `%orig;` if `val` was modified.
- **`MSHookIvar` is an inline C++ template, not a Logos directive**: it works anywhere in an `.xm` file (Logos output is Objective-C++), including static helpers — but not in plain `.m` files (no templates in Objective-C). It returns a typed lvalue reference into the ivar slot and dereferences NULL (crashes) if the ivar is missing. For by-name reads that must tolerate a renamed/missing ivar, or that live in `.m` files, use the `src/ApolloSwiftRuntime.h` helpers instead: `ApolloObjectIvar` (ObjC object ivars via `object_getIvar`, honors `__weak`), `ApolloReadObjectIvar` (raw pointer load), `ApolloReadBoolIvar` / `ApolloReadSwiftStringIvar` / `ApolloReadSwiftWeakObjectIvar` (Swift value and weak storage), and `ApolloIvarOffset` for anything else. Ivar names must be non-NULL C strings (enforced with `nonnull`). Swift stored properties carry an EMPTY ObjC type encoding, so don't gate Swift ivar reads on `ivar_getTypeEncoding`.
- **Avoid layout-driving writes inside `layoutSubviews` hooks**: Writing `frame`, `bounds`, `layoutMargins`, `separatorInset`, stack spacing, or other Auto Layout inputs from `layoutSubviews` can loop during rotation. Do one-shot row/cell prep from non-layout entry points such as `tableView:willDisplayCell:forRowAtIndexPath:` and clear flags in `prepareForReuse`.
- **Hooked `self` is `__unsafe_unretained`**: under ARC, Logos declares a `%hook` method's `self` as `T *const __unsafe_unretained`, so a block queued from a hook (`dispatch_async`/`dispatch_after`, completion handlers) must capture a strong local or a `__weak` ref, never bare `self`. `__typeof__(self)` carries the same qualifier, so the strong half of a weak/strong pair needs an explicit `__strong` (`__strong __typeof__(self) strongSelf = weakSelf;`) or a concrete type (`UIViewController *strongSelf = weakSelf;`); without it the local is a nil check that owns nothing. Tweak-owned `@implementation` methods are unaffected (their `self` is strong).

## Code Style

- **Indentation**: 4 spaces
- **Braces**: Same line as statement
- **Logging**: Use `ApolloLog` for privacy-friendly diagnostics
- When iterating on a feature, if something isn't working, prefer outright replacing the implementation over adding fallback codepaths. Use generous amount of comments and diagnostic/debug logging.

## Theme Accent in Tweak-Drawn UI

- Any accent color in tweak-drawn UI comes from `ApolloThemeAccentColor()` (`ApolloThemeRuntime.h`): the custom theme's accent when one is active, else the stock Apollo theme's (all 18 themes; `kStockThemes` table in `ApolloThemeRuntime.xm`, values recovered from the binary — see docs/theme-builder-RE.md). Chain as `ApolloThemeAccentColor() ?: someView.tintColor ?: systemBlue`; never hand-roll nav/tab-bar tintColor walks (they only ever approximated the accent).
- `UIView.tintColor` never returns nil for a real view (it inherits, bottoming out at system blue) — a fallback arm after a guaranteed-non-nil tint read is dead code. Nil only arrives via messaging a nil view, which is what the `?: systemBlue` tail covers.
- The returned accent is a dynamic provider color. Before any `.CGColor` use (layer borders, ASDK background-thread layout), resolve it with `resolvedColorWithTraitCollection:` against an in-hierarchy view's traits — ambient resolution can pick the wrong light/dark variant when Apollo overrides the window style.
- Text drawn on an accent fill needs `ApolloColorIsLight()` (ApolloCommon) to choose black vs white — stock monochromatic (dark) and chumbus (light) accents are near-white.

## Testing

No automated test suite, must be validated manually.

## Contributing From This Environment

- `origin` is the upstream `Apollo-Reborn/Apollo-Reborn` repo itself, not a personal fork — pushing a branch directly to `origin` fails with a 403 unless you're an org member with write access. To open a PR: fork it (`gh repo fork Apollo-Reborn/Apollo-Reborn --default-branch-only`), push your branch to the fork, then `gh pr create --repo Apollo-Reborn/Apollo-Reborn --head <your-username>:<branch>`.
- Pushing to a fork over HTTPS can fail here with `git: 'credential-gh' is not a git command` (gh's git credential helper isn't wired up for HTTPS pushes in this environment) — push over SSH (`git@github.com:<user>/Apollo-Reborn.git`) instead, which works via `gh`'s configured SSH key.
- To carve an isolated commit/PR for one fix out of a larger dirty working tree (e.g. several unrelated in-progress features already sitting uncommitted in `src/`), use `git worktree add <path> -b <branch> origin/main` rather than stashing — it's a separate checkout, so editing/building/committing there can't touch or reorder the main working tree's uncommitted changes. `git submodule update --init --recursive` still needs to be re-run inside the new worktree before `make package` will find `modules/`. Remove with `git worktree remove <path> --force` when done; the branch and its commits survive.

## Feature Changelog (agent-added)

Features added via agent-assisted sessions, kept here so they're easy to find without digging through git history.

- **Feed Video Scrubber: GIF fallback strip** — upstream's scrubber (`src/ApolloFeedVideoScrubber.xm`, #938) gates `pointInside:` on Apollo's native `videoGIFProgressView`, which feed GIF-mp4s mostly never get (Apollo's creation of it is async and usually skipped — the finding originally documented in the since-removed `ApolloInlineMediaScrub.xm`). `ApolloFeedScrubFallbackStrip` now stands in: installed by `EnsureScrubStrip` on every media cell, shown only when a playable AVPlayer exists AND the native strip is absent (a 4 Hz weak-self NSTimer tick re-resolves the player each time — feed players churn; nothing cached), hidden the moment the native strip materializes. `pointInside:` accepts either bar; `trackFingerOnNativeStrip:` drives the fallback's fill during a drag (tick suspended via `suspendAutoUpdates`, reset in `finishScrub` + dealloc backstop). Good candidate to PR upstream.

- **Custom Feed Source (`r/customfeed`)** — combines every subreddit in a user-supplied plaintext list into a single feed via Reddit's `/r/sub1+sub2+.../` URL combinator, navigated to by visiting `r/customfeed` in-app. Modeled directly on the existing Random/RandNSFW Source feature (same source-URL format, one subreddit name per line, no `/r/` prefix) but joins the whole list with `+` instead of picking one at random. Unlike a native saved multireddit (which is a real subscription object fetched via `/api/multi/user/<name>/...` and has historically been subject to Reddit's subscriber-count cap), this is a plain ad-hoc combined listing URL with no subscription object behind it — so it isn't subject to that cap. The list is soft-capped at 400 subreddits (truncated with an `ApolloLog` warning, not silently dropped or failed) to keep the resulting request URL a sane length; Reddit's actual limit on the `+` combinator is much higher and undocumented.
  - Setting: **Subreddits → Subreddit Sources → Custom Feed Source**, in `src/settings/CustomAPIViewController.m` (`TagCustomFeedSource`, row `sub.customFeedSource` in upstream's `buildSubredditsSearchSections`; the list-row/label toggles live in `buildSubredditsListRowsSection`, shown right after the "Subreddit List" section). Ported to the ApolloSettingsForm architecture during the v3.6.0 merge; re-placed into upstream's restructured Subreddits screen during the 4.0.0 rebuild (upstream overrides that section's footer by title, so the row carries no footer of its own).
  - State: `UDKeyCustomFeedSource` in `src/UserDefaultConstants.h`, `sCustomFeedSource` in `src/ApolloState.{h,m}`.
  - Interception + combine logic: `src/Tweak.xm`, in the `NSURLSession dataTaskWithRequest:` hook (same request-rewrite site as `/r/random/` and `/r/randnsfw/`), plus prefetched alongside the other two sources in `initializeRandomSources()`.
  - **Subreddits list row**: like Random/RandNSFW, a "CustomFeed" pseudo-row can be appended to the top pseudo-row section of the Subreddits list (alongside Home/Popular/All/Moderator Posts) without needing to be favorited — toggle **Subreddits → Subreddit List Rows → Show Custom Feed Subreddit** (`UDKeyShowCustomFeedInSubredditsList`, row `sub.showCustomFeedRow` in `src/settings/CustomAPIViewController.m`). Injected unconditionally the same way as Random/RandNSFW — no requirement that the combined feed's subreddits be followed. Implemented in `src/ApolloHideSubredditSections.xm`: `ApolloHideSubredditSectionsRandomItems()` appends `"CustomFeed"` when the toggle is on, and `ApolloHideSubredditSectionsGlyphForItem()` draws it a teal `square.stack.3d.up.fill` glyph (vs. purple/orange `shuffle` for Random/RandNSFW). Navigation reuses the same Favorites-row-borrowing trick as Random/RandNSFW — no new navigation code.
  - **Coexisting with upstream's 4.0.0 Subreddits-list modules** (re-verified in the sim during the 4.0.0 rebuild):
    - `ApolloFollowingSection.xm` (FOLLOWING section + section reordering) remaps visible↔native index paths. It is listed AFTER `ApolloHideSubredditSections.xm` in the Makefile, so its hooks install later and are OUTERMOST — this module's hooks therefore always see Apollo's NATIVE section numbers (0 = feed shortcuts, 1 = Favorites, …), which is exactly what the pseudo-row append (section 0) and the Favorites-borrowing navigation (`%orig` with section 1) assume. Keep that Makefile order; reversing it would make a pseudo-row tap open whatever the user's first reordered section is.
    - Feed Shortcuts (`ApolloSubredditIndexPolish.xm`, Grid/Side-by-Side/Icon Dock layouts) infers "this account has no Moderator Posts row" from `-numberOfRowsInSection:0`, which the appended pseudo-rows inflate — so `ApolloSubredditIndexVisibleMetaFeedIndexes` subtracts `ApolloHideSubredditSectionsAppendedSection0RowCount()` (`src/ApolloHideSubredditSections.h`). Without it, on a non-moderator account the first pseudo-row is treated as the Moderator shortcut and collapsed into the grid.
  - **Two request-interception bugs this pseudo-row exposed (fixed in `src/Tweak.xm`), worth remembering before touching Random/RandNSFW/CustomFeed again:**
    1. **Case-sensitive path matching missed some of Apollo's own requests.** Debug-logging every request Apollo made when navigating to a favorited pseudo-subreddit named "CustomFeed" showed it builds *different* requests with *different* casing for the *same* navigation: a `best.json` preview call as `/r/customfeed/best.json` (lowercased), but the `hot`/`about.json` calls that actually populate the feed as `/r/CustomFeed/hot` and `/r/CustomFeed/about.json` (display-name case preserved). The old `hasPrefix:@"/r/customfeed/"` check is case-sensitive, so it silently missed the latter two — the request fell through to `%orig` unmodified, hit real Reddit for a subreddit that doesn't exist, and Apollo showed its native "has been set to private" fallback with no posts. Random/RandNSFW happened to still "work" only because their `best.json` call (which *did* match) was enough to resolve to one real subreddit before anything else mattered. Fixed with `ApolloPathHasCaseInsensitivePrefix`/`ApolloReplaceCaseInsensitive`.
    2. **The rewrite only lived in one of the two `NSURLSession dataTaskWithRequest:` hooks.** Apollo/AFNetworking routes different requests for the same navigation through *both* the plain `dataTaskWithRequest:` (delegate-based — AFNetworking's internal implementation) and `dataTaskWithRequest:completionHandler:` overloads. The random/randnsfw/customfeed rewrite only existed in the plain one; the completion-handler one (also hooked, for unrelated imgur/imgchest/reddit-media rewrites) had no such logic at all. The `hot`/`about.json` calls that actually populate the feed and back the "private" check go through the completion-handler variant, so even with case-insensitive matching this one on its own wouldn't have been enough. Fixed by extracting the whole rewrite into a shared `ApolloRandomFeedRewrittenRequest(NSURLRequest *)` helper and calling it from both hooks. If you add a *third* NSURLSession entry point later (e.g. `dataTaskWithURL:`), check whether Apollo's networking actually goes through it before assuming it's covered — don't assume one hook implies the others are too.
    - **How this was actually diagnosed**: temporary `ApolloLog` calls at the top of both hooks, matching on `rangeOfString:@"customfeed" options:NSCaseInsensitiveSearch`, revealed the real request set (`os_log show --predicate 'subsystem == "apollofix"'` in the simulator). Don't guess at Apollo's request shapes from reading Objective-C call sites alone — Apollo's own networking is Swift and mostly opaque; log the actual URLs.
  - **Per-post subreddit label in the byline** — since a combined feed mixes posts from many real subreddits, but Apollo (thinking it's viewing one named subreddit) never shows which one a given post came from the way it natively does for Home/Popular/All/multireddits. Appends `" • r/<subreddit>"` to the post's own "by `<username>`" byline text node. Implemented in `src/ApolloUserAvatars.xm` (reuses that file's existing byline-resolution/attributed-string machinery built for inline avatars — `ApolloResolveAuthorNodeSubtree`/`ApolloBestAuthorTextNode`/`ApolloAttributedTextForNode`/`ApolloSetAttributedTextForNode`), hooked into the same `_TtC6Apollo17LargePostCellNode`/`_TtC6Apollo19CompactPostCellNode`/`_TtC6Apollo22CommentsHeaderCellNode` classes the avatar feature already hooks (`-didLoad` for the initial apply, `-layout` to catch cell reuse/rebind — mirrors `ApolloTagFilters.xm`'s identical `-layout` re-apply pattern on the same classes, since `-didLoad` alone only fires once per node instance, not per content rebind).
    - Setting: **Subreddits → Subreddit List Rows → Show Subreddit in Combined Feeds** (`UDKeyShowCombinedFeedSubredditLabels`, `sShowCombinedFeedSubredditLabels`, default **YES**). Safe to default on because the gating below makes it a no-op everywhere except a genuine combined feed.
    - **Gating logic (the part worth re-reading before changing)**: reads the containing view controller's `currentPostsType` Swift-enum tag (byte at ivar offset `+0x20`, same technique as `ApolloSubredditHeaders.xm`'s `kApolloPostsTypeTagOffset` — duplicated locally rather than shared via header) and only proceeds when it's tag `0` ("named subreddit" — the same tag a real single subreddit *and* CustomFeed both report, since Apollo can't tell them apart). Within that, it compares the post's own `RDKLink.subreddit` against the view controller's nav title (normalized, case-insensitive) and only injects the label on a **mismatch** — which is structurally impossible for a real single-subreddit view (every post's subreddit trivially equals the view's own) but happens for *every* post in a combined feed (each post's real subreddit is never "CustomFeed"). This mismatch-based design means the feature never needs to hardcode "CustomFeed" anywhere, and automatically stays out of the way for Random/RandNSFW too (tag `5`, excluded outright, and moot anyway since they're resolved to one real subreddit before a post ever renders) and for Home/Popular/All/multireddits (different tags entirely, and already natively labeled by Apollo — this must never double up there).
    - The containing view controller is found from the cell via Texture's own `closestViewController` (minimal local forward-declaration of the property, same pattern as `ApolloTagFilters.xm`'s `ApolloTagDisplayNode`/`ApolloTagPresenterForCell` — not a new technique).

## RE Notes

### Handy Hopper MCP Tools

- `Hopper/list_documents`, `Hopper/set_current_document`: select `Apollo.hop`
- `Hopper/goto_address`: jump to an address (static address Hopper uses)
- `Hopper/current_procedure`: find which function the current address is in
- `Hopper/procedure_pseudo_code`, `Hopper/procedure_assembly`: decompile/disassemble the function
- `Hopper/search_procedures`: find functions by name/regex (works well for ObjC methods)
- `Hopper/search_strings`: search embedded strings (bundle IDs, selectors, product identifiers, URLs)
- `Hopper/xrefs`: find references to a string or address
- `Hopper/list_segments`, `Hopper/list_names`: quick orientation for the binary layout
- `Hopper/procedure_callers`, `Hopper/procedure_callees`: trace call graphs (who calls this? what does this call?)

### REA (Reverse-Engineering MCP) — Hopper & Ghidra Backends

REA (`rea-agents` npm package; official sources are `morluto/rea`, rea.tools — the README warns about lookalike repos) is an MCP server + CLI that drives Hopper or Ghidra and returns pseudocode, assembly, strings, symbols and xrefs. It wraps the same engines as the manual workflows above as agent tools, and is registered for both Claude Code and OpenCode sessions. Use it for targeted questions — which method does X, what does this class's `.cxx_destruct` release, xrefs to a string — instead of driving Hopper by hand.

**Installed components (all present on the owner's Mac):**

| Component | Path / version | Notes |
|---|---|---|
| REA | `npx -y rea-agents@6.8.0 mcp` | needs Node 22.23.4+ / 24.22.1+ / 26.12.1+ |
| Node for REA | `~/.nvm/versions/node/v24.22.1/bin` | must be explicit — `~/.local/bin/node` is Hermes' Node 26.8.1 and PATH-fronts Homebrew node via `.zprofile`, and the MCP registration launches plain `npx` |
| Hopper (demo) | `~/Applications/Hopper Disassembler.app` | `HOPPER_LAUNCHER_PATH` → `…/Contents/MacOS/hopper`; demo is sufficient (30-min sessions, no save/export, debugger off — export never mattered: REA on macOS refuses saved `.hop` files and always re-analyses from scratch) |
| Ghidra | `~/Applications/ghidra_12.1.4_PUBLIC` | REA pins `SUPPORTED_GHIDRA_VERSION = "12.1.4"` (`GhidraReleasePolicy.ts`); newer 12.x is accepted but stamps an "untested" note on every result |
| JDK | `brew openjdk@21` | default `java` is Corretto 17 (too old); `/usr/libexec/java_home` doesn't know the Homebrew JDK — set `JAVA_HOME` explicitly |

**Registration.** The REA entry in `~/.claude.json` carries its own `env` (this is what Claude launches — zshrc is not consulted): `GHIDRA_INSTALL_DIR`, `JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`, `HOPPER_LAUNCHER_PATH`, `PATH` with nvm-24.22.1 first, and `REA_HOPPER_STARTUP_TIMEOUT_MS: "600000"` (default 120,000 ms is under Apollo's ~150 s cold analysis). `~/.claude/settings.json` env has `MCP_TOOL_TIMEOUT: "660000"` so one tool call survives that startup. **Claude Desktop's config deliberately has no `rea` entry** — see the Automation trap below.

Verify with (all vars on the *same line* as the command; a standalone `VAR=…` line never reaches `npx`):

```bash
PATH="$HOME/.nvm/versions/node/v24.22.1/bin:$PATH" GHIDRA_INSTALL_DIR="$HOME/Applications/ghidra_12.1.4_PUBLIC" JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" npx rea-agents@latest doctor --provider ghidra --provider hopper
```

Expect `healthy: true` for node/ghidra/hopper; `missing`/`config_drift` lines for unselected clients and optional engines (IDA, JADX, Kuna) are noise.

**Setup gotchas — each cost a debugging cycle:**

- **macOS Automation/TCC only permits the Code-launched REA server to drive Hopper.** The REA server Claude Desktop spawns runs as its own `node` process (via the `disclaimer` helper); macOS shows no Automation prompt for that kind of process, so every Hopper call fails with "Not authorized to send Apple events to Hopper Disassembler." The Code engine's server (lowercase `claude.app` in System Settings → Privacy & Security → Automation, with the Hopper toggle on) inherits the grant. A Hopper entry only appears under an app after macOS prompts at least once.
- **Ghidra's release zip has no macOS-ARM native decompiler** (only `linux_x86_64`/`win_x86_64` in `Ghidra/Features/Decompiler/os/`). Build it once, **on JDK 21** — Gradle 9.7.1's Groovy dies on Java 27 ("class file major version 71"):
  ```bash
  cd ~/Applications/ghidra_12.1.4_PUBLIC/support/gradle && JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" ./gradlew buildNatives
  ```
  Binaries land in each module's `build/os/mac_arm_64/` (not `os/mac_arm_64/`) — REA accepts that path. sha256 of `ghidra_12.1.4_PUBLIC_20260921.zip`: `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`.
- **Cold Ghidra imports must run through the REA CLI, not MCP tools.** Apollo's 14.5 MB binary imports + analyses in 16–18 min; when an MCP call exceeds the client's per-call timeout the app *restarts the REA server and the import is lost*. The CLI has no deadline and writes a snapshot that `open_binary` loads into the MCP tools in seconds.
- **Hopper demo economics:** ~150 s first analysis per session, then ~2 s per call; the 30-min cap just means the next question after expiry pays the 150 s again.

**Choosing an engine (measured against Apollo, 2026-10-27):**

| | Hopper demo | Ghidra 12.1.4 |
|---|---|---|
| Time to first answer | ~150 s | 941–1,113 s (re-imports every run unless kept in a project) |
| ARC calls in pseudocode | ✅ complete; names ivars via `objc_ivar_offset_*` symbols | ❌ **omits `objc_release` calls** — its ObjC support swaps them for `_objc_release_fixup` injections |
| Naming | weaker on Swift | names weak fields, demangles `class::method` |
| Bulk/export jobs | impossible (demo) | the only option |

Hopper is the default for this repo's frequent `.cxx_destruct`/ivar-layout questions. **Never decide `objc_release` vs `swift_bridgeObjectRelease` from Ghidra pseudocode alone** — that is exactly the question `docs/swift-array-ivar-crash-RE.md` turns on, and Ghidra would make four real `objc_release` fields look unreleased. Cross-check with REA's `procedure_assembly` or with Hopper.

**Validated against known ground truth:** REA+Hopper decompiled `-[RedditListViewController .cxx_destruct]` (`0x10064c234`) and matched every field in `Headers/Swift/RedditListViewController.swift` and the crash doc (arrays on `swift_bridgeObjectRelease`, 4× `objc_release` bar-button fields Ghidra dropped). New detail it surfaced: for `subredditToLoad: String?`, only the second word (`+0x8`) gets the bridge release. Also confirmed `-[_TtC6Apollo21ProfileViewController viewDidLoad]` at `0x1007b0d10`.

**Whole-binary analysis artifacts.** The REA CLI's `decompile-all` route was already run over apollo-base 1.15.11; the results live under `~/Projects/Apollo-Source-Private/` (outside this repo):
- `decompiled/Apollo/functions/<address>.c` — 53,316 functions, one file each, with `decompile-index.json` and a resumable `decompile-journal.jsonl`.
- `decompiled/Apollo-named/` — all 40,975 non-thunk functions re-exported **with 7,806 recovered names applied**, so headers and call sites read e.g. `ServerBuddy.onlyValidateReceipt(lookingFor:allowRetrying:)` instead of `FUN_…`. 163 s for the whole re-export, thanks to the saved project + multi-core decompile.
- `decompiled/ext-*/` — all six appexes (18,843 functions).
- `naming/` — `name-map.json`, `swift-names.json` (4,576 names from Swift class method tables + protocol conformances, via `tools/swift_names.py`), and `source-files.json` mapping Apollo's 97 original Swift files to 596 functions / 90 types.
- `ghidra-project/` — persistent Ghidra project for the main binary; opening it skips the ~17-minute cold analysis. Reusable scripts in `tools/` (`swift_names.py`, `build_name_map.py`, `ghidra_scripts/ExportFacts.java`).
- Remaining unnamed: ~21,700 functions; anything answering from them still goes through REA live.

### Effective Hopper Investigation Patterns

**Discovering class layout via `.cxx_destruct`**: Search for `-[ClassName .cxx_destruct]` and decompile it. This reveals every ivar in the class, their types (ObjC objects use `objc_release`, Swift structs use type metadata accessors, bridged objects use `swift_bridgeObjectRelease`), and their ivar offset symbols. This is the fastest way to understand a Swift class's storage layout from ObjC.

**Tracing from a known entry point**: When you know the ObjC method (e.g. `linkButtonTappedWithSender:`), decompile it to find the `sub_XXXX` helper it delegates to. Then decompile that helper. This "peel the onion" approach is how you find the actual navigation/logic functions buried under Swift thunks.

**Fix transition bugs at the source**: For media/navigation regressions, start from the method that initiates the behavior (`commentsButtonTapped:`, `didExitVisibleState`, reclaim helpers, MediaViewer dismiss callbacks) and trace forward in Hopper before adding new hooks. In this repo, the durable fixes usually came from understanding the native transition or async completion block first, not from stacking more downstream notification hooks.

**Identifying Swift property access patterns**: Swift stored properties on classes don't always have ObjC getters. Check `search_procedures` for the class — if no `-[Class property]` method exists, the property is NOT `@objc`-visible. You'll need alternative access strategies (reading from display nodes, using runtime ivar access, etc.) rather than `objc_msgSend`.

**Reading Swift function calls in pseudocode**: Hopper labels Swift stdlib/Foundation calls like `Foundation.URL.absoluteString.getter()`, `Swift.String._bridgeToObjectiveC()`, etc. These tell you what types are in play even when the pseudocode is hard to follow. Look for these labels to understand data flow.

**Pseudocode constant folding of base registers**: Hopper's decompiler sometimes loses track of a base register and folds it into offset constants, producing misleading absolute-looking addresses. For example, if the assembly is `madd x8, x21, x8, x22` then `str w0, [x8, #0x20]` (meaning `buffer + index*stride + 0x20`), the pseudocode may render this as `*(stride * index + 0x50)` — collapsing `buffer + 0x20` into a single constant `0x50`. This is a critical trap: the pseudocode appears to say elements start at offset 0x50, when they actually start at buffer+0x20. **Always verify struct/array element offsets from the raw assembly** (look for `madd`/`add` base register calculations and `ldr`/`str` displacement operands) rather than trusting the pseudocode constants.

**Decoding Swift small strings from assembly**: Strings <=15 bytes are stored inline in two registers (x0/x1) rather than as heap pointers. Hopper's decompiler hides the actual values behind `_bridgeToObjectiveC()` calls — you must read the raw assembly. Layout: x0 holds bytes 0-7 (little-endian), x1 holds bytes 8-14 in bits 0-55 plus a discriminator byte in bits 56-63 (discriminator = `0xE0 + length`). Each `mov`/`movk` with `#0xXXYY` stores two ASCII bytes in little-endian order (YY first, XX second). Strings >15 bytes use buffer pointers (`x1 = addr | 0x8000000000000000`, UTF-8 at `addr+0x20`) and appear in Hopper's string table. See `docs/sekrit-icon-keys-RE.md` for a worked example.

**Extracting Swift enum metadata from jump tables**: Swift switch helpers for enum titles/icons often compile to a small dispatcher that masks the enum case, loads a jump-table offset, adds it to a code base, then `br`s there. In assembly this looks like `and x8, x0, #0xffff` + `ldrh/ldrsw` from a table + `add x10, base, offset` + `br x10`. To replace a private helper safely, extract the table data and emulate each target block offline instead of calling a hardcoded app address at runtime. For the Apollo action menu metadata this recovered the exact `actionKind -> title/icon asset` mapping used in `ApolloNativeActionMetadata.h`.

**Emulating simple Swift string-returning blocks**: For switch arms that return strings, a tiny ARM64 emulator is often faster and safer than manual transcription. Use the Mach-O `__TEXT` base (`0x100000000` for Apollo) to map `vmaddr -> file offset`, read the jump table bytes, then emulate the small instruction subset used by these blocks: `mov`, `movk`, `adrp`, `adr`, `add`, `sub`, `orr`, `b`, `ret`, and sometimes `bl` to a known Swift/Foundation bridge or image-loading helper. Decode x0/x1 as a Swift small or long string. Validate a few known UI strings via `Hopper/search_strings`/xrefs before trusting the generated table.

**Avoid runtime calls to private binary helper addresses**: Hardcoded Apollo helper addresses like `0x1007xxxxx` can appear to work, but they are version-fragile and can crash or silently mislabel UI when the app binary shifts. Prefer one of: ObjC-visible selectors, stable ivar data, generated metadata tables checked into the tweak, or hook/capture points around the original call path. If a generated table is used, include a source note and spot-check entries whose labels/icons are user-visible.

### iOS 26 Runtime Headers And Decompiled Internals

Two external repos are useful to reference for Liquid Glass / iOS 26 work. Both are gitignored — clone them into the repo root before starting:

```bash
git clone https://github.com/qingralf/iOS26-Runtime-Headers.git

# Full repo is huge; sparse-checkout just UIKitCore.framework.
git clone --depth 1 --filter=blob:none --sparse https://github.com/EthanArbuckle/iPhone18-3_26.1_23B85_Restore.git
cd iPhone18-3_26.1_23B85_Restore
git sparse-checkout set System/Library/PrivateFrameworks/UIKitCore.framework
cd ..
```

- `iOS26-Runtime-Headers/` — RuntimeBrowser-style ObjC headers for every framework. Use to discover ivars, properties, and selectors on private classes (e.g. `_UINavigationBarTitleControl`, `_UINavigationBarContentViewLayout`).
- `iPhone18-3_26.1_23B85_Restore/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore/` — IDA-style decompilation of UIKitCore as one `.mm` file per class. Use to read actual setter/method bodies (e.g. checking whether a setter is a synthesized ivar setter or actually does work). UIKitCore is the most useful framework here for nav bar / tab bar / Liquid Glass investigations.

### Mapping Runtime PCs To Hopper Addresses

Crash logs typically show:

- A loaded image base, e.g. `Apollo 0x10444c000 + 7746680`
- A program counter (PC), e.g. `0x104baf478`

The offset is `PC - imageBase`. Hopper usually uses a Mach-O "file base" of `0x100000000`, so:

- `hopperAddr = 0x100000000 + (PC - imageBase)`

Once you have `hopperAddr`:

- `Hopper/goto_address` -> `Hopper/current_procedure` -> decompile around the trap/crash site.

### Symbolicating User Crash Reports With Release dSYMs

Release IPAs are built with `FINALPACKAGE=1`, so the shipped tweak dylib is optimized and stripped. Public release IPAs always come from the `Apollo-Reborn/Apollo-Reborn` release workflow:

```text
https://github.com/Apollo-Reborn/Apollo-Reborn/actions/workflows/release-ipa-variants.yml
```

That workflow publishes a matching `*-dSYMs.zip` release asset alongside the IPA/deb assets; use that dSYM for `.ips` reports instead of asking users to reproduce on debug builds.

First identify the release that produced the user's IPA from the IPA filename, release tag, or app/tweak version shown in the `.ips`. Then download and unpack symbols with `gh`:

```bash
mkdir -p /tmp/apollo-reborn-symbols
gh release download <release-tag> \
  --repo Apollo-Reborn/Apollo-Reborn \
  --pattern '*-dSYMs.zip' \
  --dir /tmp/apollo-reborn-symbols
unzip -q /tmp/apollo-reborn-symbols/*-dSYMs.zip -d /tmp/apollo-reborn-symbols/unpacked
find /tmp/apollo-reborn-symbols/unpacked -name 'ApolloReborn.dylib.dSYM' -type d
```

If the tag is unknown, inspect recent releases and asset names:

```bash
gh release list --repo Apollo-Reborn/Apollo-Reborn --limit 20
gh release view <release-tag> --repo Apollo-Reborn/Apollo-Reborn --json assets --jq '.assets[].name'
```

For tweak frames like:

```text
ApolloReborn.dylib  0x103bbca90 0x103ad4000 + 952976
```

1. Match the `ApolloReborn.dylib` UUID in the `.ips` `usedImages` / `binaryImages` section against:

```bash
dwarfdump --uuid /tmp/apollo-reborn-symbols/unpacked/symbols/rootful/ApolloReborn.dylib.dSYM
```

2. Symbolicate every `ApolloReborn.dylib` frame from the crashed thread:

```bash
atos -arch arm64 \
  -o /tmp/apollo-reborn-symbols/unpacked/symbols/rootful/ApolloReborn.dylib.dSYM/Contents/Resources/DWARF/ApolloReborn.dylib \
  -l 0x103ad4000 \
  0x103bbca90
```

Use the image load address as `-l` and the frame PC/address as the final argument. If the crash only provides an offset, compute `address = imageLoadAddress + offset`. Once frames resolve to source files/lines, investigate the Logos hook/block at that location and use the rest of the crashed thread plus exception type to infer runtime state.

### Swift Struct Ivars and iOS Version Pitfalls

Swift value types (structs like `Foundation.URL`) stored as ivars in a class are laid out inline — they are NOT object pointers. `MSHookIvar<NSURL *>` on a `URL` ivar works by accident on older iOS (where `URL`'s first field happened to be an `NSURL *`) but breaks when Apple changes the struct layout (e.g. iOS 26 swift-foundation changes). When you need data from a Swift struct ivar:

1. Check if there's an `@objc` getter (search Hopper for `-[Class property]`)
2. If not, look for ObjC display nodes or other ObjC objects that hold the same data (e.g. `urlTextNode.attributedText.string` for a URL shown in a button)
3. As a last resort, study the struct layout via `.cxx_destruct` and the type metadata accessor

### Swift Array/Dictionary/String Ivars Are BridgeObjects — Never Use ObjC Ownership Primitives On Them

Full worked case study: `docs/swift-array-ivar-crash-RE.md` (the Hide Sections → Multireddits launch crash). The distilled rules:

- A Swift `[Element]?` ivar (e.g. `RedditListViewController.multireddits: [RDKMultireddit]?`) stores a single word, but that word is a `Builtin.BridgeObject`: the storage heap pointer with Swift discriminator flag bits OR'd in (observed live: `0x4000000103f7cad0` — bit 62, Swift's arm64 native-storage flag, on top of pointer `0x103f7cad0`). It is NOT a valid ObjC `id`, even though the array's *elements* are ObjC objects.
- `object_getIvar`/`object_setIvar`/`objc_storeStrong`/assigning to an `id` local all hand that word to ARC. objc's arm64 tagged-pointer check looks at bit 63 only, so a bit-62-flagged word is retained/autoreleased as if it were a real object — and the poisoned autorelease pool pops **later**, crashing far from the tweak: `EXC_BAD_ACCESS` in `AutoreleasePoolPage::releaseUntil → objc_release` (at launch, typically at the end of the `FBSWorkspaceScenesClient … sendDidCreateForScene` callout), tweak absent from every thread, while logging at the swap site looks perfectly clean. Recognize that stack shape as "some code handed a non-pointer to ARC earlier in this callout".
- `objc_storeStrong` is only "the ARC-correct primitive" for genuine ObjC references. If an ivar swap crashes and the ivar's declared type (check `Headers/Swift/*.swift`) is a Swift value type, retrying with a different ObjC ownership call is the same mistake restated.
- If such a word must be temporarily swapped (see `src/ApolloHideSubredditSections.xm`), copy it out and back as a raw `uintptr_t` via `ivar_getOffset` + `memcpy` with **zero** refcounting operations: net refcount effect is zero across a synchronous same-thread bracket, and `0` is a valid `nil` for an `Optional<Array>`.
- Exhaust hookable interception points first, in order: ObjC getter on a model object (RDKUser/RDKClient — check the class-dump headers; `RDKUser` has `multireddits`/`subscribedSubreddits`/etc. right next to the already-hooked `moderatedSubreddits`) → NSUserDefaults keys → table-delegate return values → raw ivar word as the last resort. A passive log probe (`%orig` + log, no behavior change) answers in minutes whether Apollo's code path actually reads a candidate getter.
- To confirm what release primitive an ivar slot really uses, decompile `-[Class .cxx_destruct]` in Hopper: `objc_release` on the slot ⇒ ObjC reference; `swift_bridgeObjectRelease` ⇒ BridgeObject, memcpy-only.

### Debugging Delayed / Use-After-Corruption Crashes (the workflow that cracked the case above)

1. **Read the `.ips` before theorizing** — the crashed-thread shape often names the *mechanism* (autorelease pool, dispatch, notification) even when the tweak is on no stack.
2. **Match crash UUIDs to builds**: `dwarfdump --uuid` on the `ApolloReborn.dylib` inside each candidate `.deb`/`.ipa` in `packages/`, compared against the `.ips` `usedImages` entry. This proves exactly which code variant crashes (and which doesn't) before touching anything.
3. **Reproduce in the simulator with a settings backup** (`scripts/run-in-sim.sh --backup <zip>` — the toggle state rides in `preferences.plist`). A device-only "crash on relaunch" becomes a seconds-fast loop; sim crash logs land in `~/Library/Logs/DiagnosticReports/` and should match the device stack frame-for-frame before you trust the repro.
4. **Instrument what enters the deferred mechanism, not the site state.** Clean at-site logging with a later crash means the damage lives in something deferred; for suspected bad pointers, log the raw word (`memcpy` into `uintptr_t`, print top byte / low 3 bits) *before* any ObjC/ARC code touches it.
5. **Verify the fix against the same repro** (survives launch + feature visibly works + no new DiagnosticReports), not just "it builds".

### Hooking a Lazily-Realized Swift Class: Bare Name vs Mangled Name

`%hook ClassName` using Apollo's bare (unmangled) Swift class name can silently fail to install — no crash, no build error, the hook's methods just never fire — if that class hasn't been "realized" by the Swift runtime yet at the moment Logos installs hooks. Swift classes bridged to ObjC are lazily realized; `objc_getClass("ClassName")` (bare) can legitimately return `nil` at that early point even though the class unquestionably exists in the binary, especially under the simulator's `LOGOS_DEFAULT_GENERATOR=internal` build (plain ObjC-runtime swizzling, no CydiaSubstrate) which has no retry/deferral for this.

**Symptom:** a hook (e.g. adding a nav bar button in `viewDidLoad`) compiles and links fine (confirm with `nm -a` on the dylib — the hook's generated trampoline symbol is present), but its effect never appears at runtime, and no log line from inside the hook ever fires.

**How to confirm this is the cause:** add a temporary `%ctor` block that directly compares both resolutions and logs them:
```objc
%ctor {
    Class bareClass = objc_getClass("ProfileViewController");
    Class mangledClass = objc_getClass("_TtC6Apollo21ProfileViewController");
    ApolloLog(@"[Debug] bare->%@ (name=%s) mangled->%@ (name=%s)",
              bareClass, bareClass ? class_getName(bareClass) : "nil",
              mangledClass, mangledClass ? class_getName(mangledClass) : "nil");
}
```
If bare resolves to `nil` while the mangled form resolves fine, that's the bug.

**Fix:** hook the mangled class name directly (e.g. `%hook _TtC6Apollo21ProfileViewController`, not `%hook ProfileViewController`) — this resolves via a compile-time-bound symbol reference, not a runtime string lookup, so it's immune to realization timing entirely. This is already the pattern most hooks on Swift classes in this codebase use (`ApolloNativeActionMenus.xm`, `ApolloAccountSwitcherViewController.xm`, `ApolloSignInSplash.xm`); a handful of older files (`ApolloRecentlyRead.xm`) use the bare name and currently get away with it, likely due to favorable constructor/link ordering on that specific build — not something to rely on for new code.

### Reliably Getting a Profile Screen's Current Username

Don't read `ProfileViewController`'s `userInfo` property via KVC (`[(id)vc valueForKey:@"userInfo"]` then `.username`) to find out whose profile is being shown — `userInfo` can be `nil` in some load states, notably for the **signed-in user's own profile**, since Apollo doesn't always need to fetch profile info the same way it does for other users. A check built on this will falsely treat your own profile as unidentifiable.

Use the existing, already-proven helper instead: `ApolloUsernameFromProfileViewController(UIViewController *viewController)`, defined in `src/ApolloUserAvatars.xm` (exposed as a plain C function rather than `static`, so it can be called from other files). It tries several ivar names in order (`username`, `userName`, `_username`, `account`, `user`, `profile`, `viewModel`) via generic runtime ivar reading (not KVC), then falls back to parsing the nav bar title — with a blocklist of generic titles ("Accounts", "Settings", "Saved", "Hidden", etc.) so a screen showing a section name rather than a username isn't misidentified. This is the mechanism to reuse any time a hook needs to know which profile it's looking at.

### Native "More Options" (3-Dot) Menu Doesn't Render on Your Own Profile

`ApolloNativeActionMenus.xm`'s existing menu-capture/injection machinery (`_TtC6Apollo16ActionController`, `ApolloNativeActionMenuPresent`, etc.) is the right place to add an entry to Apollo's native 3-dot "more options" menu — but that menu simply doesn't exist/render at all on **your own profile** (there's nothing to report, block, or message on yourself), so any feature that must work on your own profile can't be reached through it. For a feature scoped to the signed-in user's own profile, add a dedicated `UIBarButtonItem` to `navigationItem.rightBarButtonItems` from a `viewDidLoad` hook instead (see `ApolloRecentlyRead.xm`'s clock-icon button, and `ApolloHiddenContentMenu.xm`'s eye-slash button) — this renders unconditionally regardless of whether a context menu exists for that particular profile. Reserve the 3-dot-menu injection point for features meant to apply to *other* users' profiles.

### Capturing Swift Singletons via fishhook

Pure Swift classes (no ObjC-visible methods) that use `dispatch_once` singletons can't be accessed through normal hooking. Use `fishhook` to briefly hook `swift_allocObject`, match on the class's type metadata pointer (which equals the `objc_getClass` result for Swift classes), capture the instance, and immediately unhook:

```objc
static __unsafe_unretained id sSingleton = nil;
static void *sTargetMetadata = NULL;
static void *(*orig_swift_allocObject)(void *type, size_t size, size_t alignMask);

static void *hooked_swift_allocObject(void *type, size_t size, size_t alignMask) {
    void *obj = orig_swift_allocObject(type, size, alignMask);
    if (type == sTargetMetadata && !sSingleton) {
        sSingleton = (__bridge id)obj;
        rebind_symbols((struct rebinding[1]){{"swift_allocObject", (void *)orig_swift_allocObject, NULL}}, 1);
    }
    return obj;
}

// In %ctor:
sTargetMetadata = (__bridge void *)objc_getClass("_TtC6Module12ClassName");
if (sTargetMetadata) {
    rebind_symbols((struct rebinding[1]){{"swift_allocObject", (void *)hooked_swift_allocObject, (void **)&orig_swift_allocObject}}, 1);
}
```

Once captured, access ivars via `class_copyIvarList` + `object_getIvar` (by name for robustness, with fallback by type). This avoids hardcoded binary addresses and works across binary versions as long as the class/property names are stable.

### ASVideoNode Player Access — Shareable vs Non-Shareable

Apollo uses two distinct video player paths depending on content type:

**Two player paths:**
- **Shareable** (v.redd.it): player shared via AVPlayerLayer between feed and comments. ASVideoNode's `_player` ivar is nil — player lives on `[[videoNode playerLayer] player]`.
- **Non-shareable** (GIFs, Giphy, Streamable): player on `[videoNode player]` directly.
- **Always use `[[videoNode playerLayer] player]`** (the native mute handler's path), fall back to `[videoNode player]` if playerLayer returns nil.

**Transition-specific behavior:**
- **Compact posts**: feed -> fullscreen -> comments often creates a fresh comments `AVPlayer` asynchronously. Do not assume the fullscreen player and comments player are the same object; expect to retry after async asset/player preparation completes.
- **Non-compact posts**: feed/comments/fullscreen may all be manipulating the same shared player layer. Fixes must update the real player state first, then separately resync the mute button/icon if Apollo's UI falls out of sync.
- **Crossposts**: when scanning visible media or resyncing state, inspect both the cell's `richMediaNode` and `crosspostNode.richMediaNode`.

**Unmuting requires (in order):**
1. `setCategory:AVAudioSessionCategoryPlayback` — Apollo defaults to `Ambient`, which silences audio even when `player.muted=NO`.
2. `[player setMuted:NO]` directly (for shareable, `[videoNode setMuted:NO]` alone won't reach the real player since `_player` is nil) + `[videoNode setMuted:NO]` to sync the internal `_muted` flag.
3. Blocking session reversion to `Ambient` — Apollo resets the session after player setup. Handled by AVAudioSession hooks keyed on `sAutoUnmutedPlayer`.

**Mute dance** (`sub_1003414cc`): Apollo's async mute sequence, fired when a video exits the visible area (`TouchHintVideoNode.didExitVisibleState` → `sub_10058cb30`) or when fullscreen MediaViewer dismisses. T+0: pause all, T+50ms: `setCategory:Ambient` + `setActive:NO`, T+100ms: `setMuted:YES` + unpause all. The native unmute (`sub_100341894`) survives this because it registers the player with `VideoSharingManager.activeAudioPlayer`; our auto-unmute survives via `sAutoUnmutedPlayer` + hook blocking. The native unpause handler only resumes non-shareable videos — shareable comments header videos stay paused, fixed in our `RichMediaNode.unpauseAllAVPlayersNotificationReceivedWithNotification:` hook.

**Mute button:** Icon names `"small-mute"` / `"small-unmute"` on MuteUnmuteVideoButtonNode's `icon` ASImageNode, with `isMuted` Swift Bool ivar. Don't use `muteUnmuteButtonTappedWithSender:` for programmatic unmuting — it's a toggle (mutes if already unmuted) and depends on a weak `actionDelegate` that may be nil.

**Best hook for comments header video:** `RichMediaHeaderCellNode.cellNodeVisibilityEvent:` — event-driven, comments-only (no context check needed). Player may not exist on event=0; use ~500ms retry.

### Debugging "Signed Out After Closing/Backgrounding" on Real-Device Sideloads

A user report of Apollo signing out of Reddit shortly after closing or backgrounding the app (apollo-reborn#567, fixed in PR #579) looked at first like a bundle-ID/entitlement mismatch from sideload signing (rebranding, Signulous, etc.) — it wasn't. Two techniques and the actual root cause, worth remembering before re-treading this ground:

**Capturing live logs from a device with no Xcode pairing.** `xcrun devicectl device console --device <id>` requires Developer Mode + an Xcode-style device pairing ("The device must be paired before it can be connected") that most sideload-only devices don't have. `idevicesyslog` (libimobiledevice, `brew install libimobiledevice`) works over the older lockdown/syslog-relay protocol and only needs "Trust This Computer":
```bash
idevice_id -l                               # get the UDID
idevicesyslog -u <udid> | grep -i ApolloFix # stream the tweak's os_log lines live
```

**Timing rules out network causes.** When a stateful bug's effect follows its trigger by only 1-2ms (measurable from consecutive log timestamps), that's too fast for any HTTPS round-trip — it proves the cause is purely local/synchronous, not a server-side rejection (e.g. Reddit revoking an overused shared client_id). This was the step that ruled out a Reddit-side cause here.

**The actual root cause: a Valet keychain item vs. iCloud Keychain sync.** Apollo's Valet-backed account-secrets keychain item (service contains `com.christianselig.Apollo`, account `2RedditAccounts2`) can come back `errSecItemNotFound` on `SecItemCopyMatching` while the very next `SecItemAdd` for the identical item fails `errSecDuplicateItem` — the signature of an item that's iCloud-Keychain-synced: a plain read without `kSecAttrSynchronizable` only searches non-synced items, but a synced item still collides as a duplicate on add. Apollo's `AccountManager` doesn't retry with an update on that failure, it just wipes the signed-in account. Fixed in `src/Tweak.xm`'s `SecItemCopyMatching_replacement`/`SecItemAdd_replacement` by broadening reads to `kSecAttrSynchronizableAny` and self-healing a stuck duplicate-add by deleting the stale item and retrying (`ApolloQueryByBroadeningSynchronizable`/`ApolloDeleteStaleKeychainItem`). Confirmed via independent reproduction on a second, unrelated user's device with the same setup (Signulous signing + the shared "dystopia" API key) — not a one-off.

**Not the cause (ruled out, don't re-investigate first):** rebranding the bundle ID, the specific enterprise/mass-signing method (Signulous vs. AltStore/SideStore), and this codebase's long-standing `stripGroupAccessAttr` unconditional access-group stripping — none of these reproduced or fixed the symptom when isolated and tested. `stripGroupAccessAttr` was still hardened to try the real access group first and only fall back to stripping on `errSecMissingEntitlement`, which is a legitimate improvement, but it was not what caused this bug.

## Headers And Runtime Introspection Tips

- For methods you only need to call defensively, prefer `objc_getClass` + `@selector(...)` + `objc_msgSend` over adding brittle headers. Write constant selectors as `@selector(name:)`; reserve `NSSelectorFromString` for names built at runtime. For a zero-argument object getter, `ApolloSendObject(object, @selector(name))` (ApolloCommon.h) does the respondsToSelector/objc_msgSend pair.
- Swift class names: look them up in either form, but compare names only in the dotted form. `objc_getClass` and `NSClassFromString` resolve both `_TtC6Apollo22ThickSeparatorCellNode` and `Apollo.ThickSeparatorCellNode` (`%hook` takes the mangled identifier), while `NSStringFromClass`, `class_getName` and `object_getClassName` always return `Apollo.ThickSeparatorCellNode` (verified on the macOS and iOS 26 simulator runtimes), so an `isEqualToString:`/`hasPrefix:`/`strncmp` against `_TtC…` never matches. Prefer `isKindOfClass:`/`isMemberOfClass:` against `objc_getClass("_TtC…")` over comparing names; when a string test is unavoidable, match `Apollo.`.
- **Looking up classes by name** (every `objc_getClass`): `objc_getClass` takes the global runtime lock, hashes the name and probes the class tables on every call, and a miss is worse still (it retries with a Swift-mangled name and calls the Swift hook). A `dispatch_once` fast path is a single load and compare. Use `objc_getClass` rather than `NSClassFromString`, which does the same lookup plus a string conversion, and pick a pattern per class:
  - **A, the default:** add the class to the shared table in `src/ApolloClasses.{h,m}`. Declare `extern Class ApolloClassFoo;` in the header and add one `objc_getClass` line (mangled `_TtC…` name for Swift classes; objc4 tries a dotted name first, misses, then mangles it with a malloc) to the constructor in `ApolloClasses.m`. Then use `ApolloClassFoo` everywhere and nil-check it, falling back to the original behaviour. That constructor runs before every module's `%ctor` (`ApolloClasses.m` is listed first in the Makefile), and every image these classes live in is already mapped by then, so no lazy lookup is needed. A class absent for the whole process simply stays Nil. Use it for anything present at launch: Apollo's binary and bundled frameworks, Texture, RedditKit, UIKit (private ones too), linked system frameworks, and the tweak's own classes. Never write a per-file `dispatch_once` accessor for these, because every file then pays for its own copy.
  - **B:** for a class whose image loads after launch (a framework or bundle that is dlopened or soft-linked later, e.g. TextInputUI's `TUIVariantSelectorView`), use a lazy accessor defined once in `ApolloClasses.m` and declared in the header. Make it an atomic `if (!cached)` retry (`_Atomic(void *)` with acquire/release; ARC won't take `_Atomic(Class)`), only for classes that can appear later: a dlopen'd bundle, or `objc_allocateClassPair`. Never use it for a class that may never exist.
  - **C:** a direct `objc_getClass` call, only in cold or one-shot code (`%ctor`, setup, a user tap, error paths, or inside another one-time initializer) or for names built at runtime. Never call it per frame, per cell, per layout pass or in a loop.
- Apollo and Texture classes live in Apollo's binary, which the dylib is injected into rather than linked against, so `[ApolloClass class]` fails at link time; use `objc_getClass`. Public SDK classes from linked frameworks (UIKit, Photos, PhotosUI, SafariServices, ...) can be referenced directly as `[UIKitClass class]`.
- If a class is only forward-declared, cast `self` to `UIViewController *` (or `id`) before sending UIKit messages to keep clang happy.
- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.
