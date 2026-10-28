---
name: install-via-usb
description: Re-sign a built Apollo-Reborn IPA with the user's own .p12/.mobileprovision via scripts/resign-ipa-codesign.sh, then install it on a USB-connected iPhone. Use for phrases like "install this on my phone", "sideload via USB", "put it on my device", "resign and install".
---

# Re-sign and install over USB

Two steps: (1) re-sign the IPA with `scripts/resign-ipa-codesign.sh` using the user's certificate +
provisioning profile, (2) install the result on a cabled-in iPhone with `ideviceinstaller`. Never re-sign
the OUTPUT of this script through anything else (Sideloadly/AltStore/Cyan) afterward — that undoes the
iOS 26 `CS_EXECSEG_MAIN_BINARY` fix the script exists for.

## 0. Locate the signing files

Default location for this project: `Development.p12` and `Development.mobileprovision` in the repo root
(`/Users/omarsalam/Projects/Apollo-Reborn/`) — both are gitignored (via `.mygitignore`), so `git status`
won't show them. If they're not there, ask the user where they are rather than guessing.

## 1. Import the .p12 into the login keychain (one-time, skip if already done)

Check first:
```bash
security find-identity -v -p codesigning
```
If it lists an identity matching the profile's team/name, skip straight to step 2.

Otherwise import it. **Ask the user for the .p12 password in chat before running this** — don't guess or
reuse a password from elsewhere:
```bash
security import Development.p12 -k ~/Library/Keychains/login.keychain-db -P '<password from user>' \
  -T /usr/bin/codesign -T /usr/bin/security
```
Then grant `codesign`/`security` non-interactive access to the imported key so later signs don't pop a
Keychain GUI prompt each time (needs the *login keychain* password, i.e. the Mac user's own password —
ask for it, don't assume it matches the .p12 password):
```bash
security set-key-partition-list -S apple-tool:,apple: -k '<login keychain password>' \
  ~/Library/Keychains/login.keychain-db
```
Re-run `security find-identity -v -p codesigning` to confirm the identity now appears, and copy its exact
quoted string (e.g. `"Apple Development: someone@example.com (ABCDE12345)"`) for step 2.

## 2. Re-sign the IPA

```bash
./scripts/resign-ipa-codesign.sh <input.ipa> "<signing-identity from step 1>" \
  --profile Development.mobileprovision -o <output-resigned.ipa>
```
- `<input.ipa>` is whichever IPA the user means — prefer one just built earlier in this conversation
  (`build-ipa.sh`/`patch.sh` output) over guessing among files on disk; ask if ambiguous.
- Watch the script's own output for `WARNING: no … provisioning` lines — that means the profile didn't
  match an app/appex (e.g. wrong bundle ID / not a wildcard `TEAMID.*` profile) and that target won't
  install. Don't proceed to install if you see this; surface it to the user instead.
- The script ends with `codesign -v --strict` verification and exits non-zero on failure — treat that as
  a hard stop, not something to retry with `--no-verify`-style bypasses.

## 3. Confirm a device is connected over USB

The target device is **Omars iPhone**, UDID `191E7775-0E62-50E2-A056-21BB5EE0CEE6`, unless the user
explicitly names a different device for this request.

```bash
idevice_id -l
```
- **Empty output** → no device attached via USB (or not yet trusted). Ask the user to plug it in / unlock
  it / tap "Trust This Computer" on the device, then re-run.
- **Contains `191E7775-0E62-50E2-A056-21BB5EE0CEE6`** → use it, no need to ask.
- **Doesn't contain it (one or more other UDIDs listed)** → don't silently install to whatever's plugged
  in; tell the user the expected device isn't connected and confirm before targeting anything else.
- Only skip the UDID check entirely if the user already stated a different specific device to use.

If installs fail with a pairing error, validate/re-pair first:
```bash
idevicepair -u 191E7775-0E62-50E2-A056-21BB5EE0CEE6 validate   # or: ... pair
```

## 4. Install

```bash
ideviceinstaller -u 191E7775-0E62-50E2-A056-21BB5EE0CEE6 install <output-resigned.ipa>
```
Report success/failure from its output. If a same-bundle-ID build is already on the device, this
upgrades it in place — no need to uninstall first (uninstalling first is only needed when the *bundle ID
itself* changed, e.g. a fresh rebrand).

`xcrun devicectl device install app --device <udid> <output-resigned.ipa>` is an equally valid fallback if
`ideviceinstaller` errors for some reason, but default to `ideviceinstaller` since it's the tool already
set up in this environment.
