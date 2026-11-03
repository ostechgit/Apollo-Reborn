# stock-login — stock Apollo in the simulator, with credentials only

Runs **unmodified** Apollo (apollo-base) in the iOS Simulator with a minimal dylib
that supplies Reddit OAuth credentials. The point is evidence: the full Reborn
tweak adds avatars, gallery carousels and other chrome, so it can't be used to
measure stock layout. This build has none of that.

```
stock-login/
  ApolloAuthShim.xm   the hooks (credentials only)
  Makefile            Theos project, simulator SDK, internal Logos generator
  prepare_shell.py    Mach-O platform patcher (iOS -> iOS-Simulator)
  install.sh          build + prepare + install + seed credentials + launch
```

## Usage

```bash
./install.sh --backup ~/Some-Reborn-Backup.zip   # install and launch
./install.sh --no-build                          # relaunch with the last shim
./install.sh --fresh                             # re-extract and re-patch the shell
```

Default bundle id is `com.omarsalam.ApolloStockLogin`, so it coexists with the
App Store id, the Reborn build and `ApolloStockReference`.

The base IPA is `../apollo-base.ipa` (`--ipa` to override). The prepared shell is
cached under `build/shell/`.

## What the shim does

Only the credential plumbing, taken in behaviour from the Reborn tweak's auth
layer:

1. `-[RDKOAuthCredential clientIdentifier]` / `-redirectURI` — substitute the
   configured client id and redirect URI for Apollo's revoked embedded ones.
2. `-[AFHTTPRequestSerializer setAuthorizationHeaderFieldWithUsername:password:]`
   — Reddit's token endpoint is called with HTTP Basic and an **empty**
   password; a confidential client must send its secret there instead.
3. `-[RDKClient userAgent]` — return the configured UA.

Credentials come from the same defaults keys Reborn uses
(`RedditApiClientId`, `RedditApiClientSecret`, `RedirectURI`, `UserAgent`), and a
Reborn settings backup can be preloaded unchanged.

`install.sh` copies the backup's `preferences.plist` to
`Library/Caches/StockLogin.plist`; the shim imports the four keys from it on
launch. That indirection is deliberate: **writing the app's Preferences plist
directly does not work** — cfprefsd owns the domain and ignores out-of-band
edits, and the simulator's `defaults` tool cannot see an app sandbox domain
either. Letting the app write its own defaults through `NSUserDefaults` is the
only reliable seeding path without a settings UI.

## Status

| Step | State |
|---|---|
| Builds for the simulator | ✅ |
| Installs under its own bundle id | ✅ |
| Shim loads (`[StockLogin] auth shim loaded ...` in the log) | ✅ |
| Reads client id + redirect from the backup | ✅ |
| Reaches stock's own feed screen | ✅ |
| **Completes authentication** | ❌ feed stays on the spinner |

## Why it doesn't authenticate yet

Diagnosis so far:

- The July backup's `RedditApiClientSecret` is **empty**, i.e. it was made with a
  public / installed-app client. Stock's empty-password Basic auth is correct for
  that kind of client, so a missing secret is not by itself the problem.
- Stock caches an **archived `RDKClient`** for the application-only session
  under `RedditApplicationOnlyAccount2` (see `src/ApolloWebJSONIdentity.xm`).
  That key is **not present in the backup's preferences**, so stock builds a
  fresh client — and the three hooks above may not be enough for that path.
- The token exchange presumably 401s, but the simulator's unified log redacts the
  URL and the response body, so the failure isn't visible without more hooks.

Next steps, in order of cheapness:

1. Hook `-[RDKClient setAuthorizationCredential:]` and log the credential's
   client id, plus the token request's status code, to see exactly which value
   and which response stock is getting.
2. If the app-only client is built outside `RDKOAuthCredential`, extend the shim
   to override the client id where that request is assembled
   (`retrieveAccessTokenForApplicationOnlyWithCompletion:`).
3. Failing that, copy Reborn's full credential module
   (`src/ApolloAccountCredentials.{h,m}`) instead of the three-hook version.

Until then, the full-tweak simulator build (`scripts/run-in-sim.sh`) remains the
only *authenticated* target — usable for measurements of classes Reborn does not
touch (e.g. `SlideGestureBuilder`), but not for stock layout evidence.
