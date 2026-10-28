---
name: copy-ipa-to-icloud
description: Copy a built/patched Apollo-Reborn IPA to the user's iCloud Drive when they ask to send, copy, upload, or ship it there. Use for phrases like "copy that to icloud", "put the ipa in icloud drive", "send it to icloud", "upload to my iCloud".
---

# Copy a built IPA to iCloud Drive

The user builds IPAs at arbitrary, self-chosen output paths (`build-ipa.sh -o ...`, `patch.sh -o ...`,
`scripts/rebrand-ipa.sh -o ...`, `scripts/resign-ipa-codesign.sh -o ...`), so there is no single "the build
output" location — figure out which file the user means, then copy it.

iCloud Drive root on this machine:
```
/Users/omarsalam/Library/Mobile Documents/com~apple~CloudDocs
```
It's a plain local folder (macOS syncs it in the background) — a `cp` into it is instant and needs no
special API. Quote the path (it contains spaces and `~`).

## 1. Identify the source IPA

In priority order:
1. **A path just produced in this conversation** — if you (or the user) ran `build-ipa.sh`/`patch.sh`/etc.
   earlier in this session, use that `-o` output path directly. Don't re-derive it.
2. **A path/filename the user names explicitly** in their request.
3. **Otherwise, ask** — don't guess among multiple candidate IPAs. If it's ambiguous, run something like:
   ```bash
   find . -maxdepth 3 -iname '*.ipa' -newer control -exec ls -la {} \;
   ```
   (or check `/tmp`, `./packages/`, `./.sim/` for recently modified `.ipa` files) and confirm with the user
   which one they mean before copying.

Verify the file exists and is a real IPA before copying:
```bash
unzip -l "<source.ipa>" | grep -m1 Payload
```

## 2. Pick a destination filename

Don't blindly copy as the source's basename — this project's build scripts default to generic names
(`Apollo-Tweaked.ipa`, `Final.ipa`, `glass.ipa`, `injected.ipa`) that will silently clobber an earlier test
build already sitting in iCloud Drive under the same generic name. Check for a collision first:
```bash
ls "/Users/omarsalam/Library/Mobile Documents/com~apple~CloudDocs/<name>.ipa" 2>/dev/null
```
- If nothing collides, or the user gave an explicit destination name, use that name as-is.
- If the basename is generic (`*-Tweaked.ipa`, `Final.ipa`, `injected.ipa`, `glass.ipa`, or similar) **and**
  it would collide, propose a more specific name instead of overwriting silently — e.g. derive a version/date
  suffix from `control` (`Version:` field) or the current date, such as `Apollo-Reborn-3.3.0.ipa` or
  `Apollo-Test-2026-07-03.ipa` — and confirm with the user if genuinely unsure, rather than overwriting a
  same-named file that might be their last known-good test build.

## 3. Copy and verify

```bash
cp "<source.ipa>" "/Users/omarsalam/Library/Mobile Documents/com~apple~CloudDocs/<dest-name>.ipa"
```
Then confirm the copy landed intact (size match is sufficient — no need for a checksum):
```bash
ls -la "<source.ipa>" "/Users/omarsalam/Library/Mobile Documents/com~apple~CloudDocs/<dest-name>.ipa"
```
Report the final destination path to the user. Actually syncing to iCloud's servers happens in the
background after this — that's outside your control and not something to wait on or verify.
