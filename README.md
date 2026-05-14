# Peel

**The App Store Server API workbench for Mac.** Open-source. Native. By [Galva](https://galva.io).

Peel back the App Store Server API. Paste a `.p8` key, pick an endpoint, see the nested JWS responses decoded inline. Native AppKit + SwiftUI, app-sandboxed, keys in Keychain. Nothing leaves your machine except calls to Apple.

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ◉ ◉ ◉   Peel   [App ▾]   [Sandbox · Prod]   [🔒 Read-only]                 │
├──────────┬─────────────────────────────────────┬─────────────────────────────┤
│ Sidebar  │ Endpoint + Request form             │ Response viewer             │
│          │                                     │                             │
│ ▸ App 1  │ ▾ getAllSubscriptionStatuses        │ ┌─ Decoded ──┬─ JSON ─┬HTTP┐│
│ ▸ App 2  │   Transaction ID: __________        │ │ status: ACTIVE       │  ││
│          │   [Show JWT]  [Copy as curl]        │ │ expiresDate: …       │  ││
│          │   [Send]                            │ │ ...                  │  ││
└──────────┴─────────────────────────────────────┴─────────────────────────────┘
```

## Why

iOS subscription debugging usually starts with a `.p8` key, ends with a 30-minute round trip through Postman or a hand-rolled Python script, and produces a screenshot of pretty-printed JSON pasted into a Linear ticket. Peel collapses the round trip into one keystroke: paste key, pick endpoint, send, read decoded response.

- **Native macOS** — AppKit shell, SwiftUI content. No Electron, no web tech.
- **App-sandboxed.** Keys live in the macOS Keychain (never on disk, never in iCloud). Hard-coded host allowlist; nothing leaves your machine except calls to Apple.
- **Full endpoint coverage.** Subscription statuses, transaction history, refunds, renewal-date extensions, test notifications, and identity (App Account Token) — all in one app.
- **Decoded JWS responses.** Every `signed*` field is unwrapped inline so you see actual transaction data, not opaque tokens.
- **Compare mode.** Diff two responses side-by-side; semantic summary highlights "subscription extended by 30 days" etc.
- **Local webhook receiver.** Sends a test notification, catches it on `127.0.0.1`, decodes the payload in the same UI.

## Install

### Homebrew (recommended)

```bash
brew install --cask peel-app/peel/peel
```

### Direct download

Signed, notarized DMG from [Releases](https://github.com/galva/peel/releases).

### Build from source

Requires Xcode 16+ on macOS 14 (Sonoma) or later.

```bash
git clone https://github.com/galva/peel.git
cd peel
swift build -c release
./scripts/bundle.sh release        # produces build/Peel.app
open build/Peel.app
```

## Project layout

```
Sources/
  PeelCore/          Models, JWT signer, Keychain, JWS decoder, diff, anonymizer
  PeelAPI/           Endpoint catalog, request builder, HTTP client
  PeelPersistence/   SwiftData entities, history, audit log, file blobs
  PeelWebhook/       Local NWListener-based HTTP receiver
  PeelUI/            SwiftUI views: sidebar, request, response, compare, settings
  PeelApp/           AppKit shell: AppDelegate, main menu, window controllers, menu bar
Tests/
  PeelCoreTests/
  PeelAPITests/
  PeelPersistenceTests/
  PeelWebhookTests/
scripts/
  bundle.sh          Wraps the SPM executable into a .app bundle
Resources/
  Info.plist         App metadata
  Peel.entitlements  Sandbox + hardened-runtime entitlements
```

## Trust model

- **Hard-coded allowlist.** Peel contacts only `api.storekit.itunes.apple.com`, `api.storekit-sandbox.itunes.apple.com`, plus the Sparkle update URL if you opt in.
- **Keys in Keychain.** `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, `kSecAttrSynchronizable = false`.
- **No telemetry by default.** When opted in, Peel sends anonymous endpoint counts only — never request bodies, transaction IDs, or app names.
- **Audit log.** Every API call is recorded locally with parameter values redacted. Exportable as JSONL.

For more detail: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · [SECURITY.md](SECURITY.md).

## Contributing

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md). The repo is structured so each layer (Core, API, Persistence, Webhook, UI, App) builds and tests on its own — adding a new endpoint usually means editing one file in `PeelAPI/` plus a test.

## License

MIT — see [LICENSE](LICENSE).

## Built by

[Galva](https://galva.io), the team behind [Habitify](https://habitify.me).
