# Architecture

Peel is built as a single Swift Package with five targets. AppKit hosts the chrome (windowing, menu, toolbar, services, drag-drop). SwiftUI hosts the content (forms, JSON viewers, diff panels). The boundary is `NSHostingController`.

The same source layout drives **two** build manifests: `Package.swift` (SPM, used by CI and command-line workflows) and `Project.swift` (Tuist, used to generate a runnable Xcode project for development). Both point at the same `Sources/` and `Tests/` directories — no codegen, no duplication. When you add a new file under an existing module, neither manifest needs to change.

```
┌──────────────────────────────────────────────────────────────────────┐
│  PeelApp  (executable)                                               │
│  AppKit: NSApplicationDelegate, NSMainMenu, NSWindowController,      │
│          NSToolbar, NSStatusItem, NSPopover                          │
│   │                                                                  │
│   └─→ embeds NSHostingController(rootView: MainWindowView)           │
└──────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PeelUI                                                              │
│  SwiftUI: MainWindowView, SidebarView, RequestPanel, ResponseViewer, │
│           ComparePanel, SettingsView, AddAppSheet, MenuBarPopover    │
│  Observable: PeelAppStore (single source of truth per process)       │
└──────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PeelAPI                          PeelPersistence                    │
│  Client · EndpointSpec ·          Storage (SwiftData) ·              │
│  Confirmation builder             History · Audit · blobs            │
└──────────────────────────────────────────────────────────────────────┘
            │                              │
            ▼                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PeelCore                                                            │
│  Models · JWTSigner · KeychainStore · JWSDecoder · JSONValue ·       │
│  JSONDiff · Anonymizer · AuthErrorMapper · CountryCatalog ·          │
│  AppStoreLookup · AuditLog · Allowlist · ExampleAppFactory           │
└──────────────────────────────────────────────────────────────────────┘
```

## Why AppKit + SwiftUI

SwiftUI on macOS still loses behavior at the window-management layer: multi-window state, tabs, menu re-creation, drag-drop into title bars, services menu. AppKit handles those rock-solidly. The content panels — request forms, JSON viewers, animated decoded layers — are much faster to iterate in SwiftUI.

The mix is contained: each main window is one `NSWindowController` hosting one SwiftUI root via `NSHostingController`. SwiftUI doesn't own the window lifecycle; AppKit does.

## State management

`PeelAppStore` is an `@Observable` class scoped to the process. It owns:

- The configured apps list.
- The active app and environment.
- The audit log and history caches.
- Per-selection caches: parameters typed in the form, last result, last error.

`PeelAPI.Client` and `PeelPersistence.Storage` are actors. The store talks to them with `await`. UI views observe the store directly via `@Bindable`.

This is intentionally simple — no Redux, no Combine plumbing, no view-models layered on top of view-models. Three layers: store → views, store → actors. Done.

## Persistence

SwiftData for structured records (apps, history index, audit log). Plain files for large response bodies (the SwiftData store stores a pointer; bodies > 64 KB land in `Application Support/Peel/blobs/`).

## Secrets

The `.p8` private key for each app sits in the macOS **Data Protection keychain** only, keyed by the `AppConfig.id` UUID:

```
service:    io.galva.peel
account:    <uuid>.p8
data:       <PEM contents>
attrs:      kSecUseDataProtectionKeychain = true
            AccessibleAfterFirstUnlockThisDeviceOnly
            Synchronizable = false
access-group: $(AppIdentifierPrefix)io.galva.peel
```

The Data Protection keychain is the iOS-style backend that ships on macOS 10.15+. The `keychain-access-groups` entitlement opts our sandboxed app into it — items are bound to Peel's signed identity (Team ID + bundle id) rather than to the user's login keychain, so macOS reads and writes silently with no password prompts. The side effect is that switching signing identities (ad-hoc dev build ↔ Developer-ID-signed release) makes prior items invisible; for a shipped, stably signed release that's exactly the scope we want.

The Storage layer never sees the key. Only `PeelAPI.Client` reads it, on the JWT-signing path.

## Networking

`PeelAPI.Client` is an actor that owns:

- The `URLSession` (or test transport).
- The `JWTCache` (one signed JWT per app per ~20 minutes).
- The `NetworkAllowlist` enforcement.

Every request goes through `dispatch(DispatchInput)`. The input carries the app context, environment, prepared `EndpointSpec`, and the read-only flag. The client signs the JWT (or pulls a cached one), constructs the `URLRequest`, sends it, and returns a typed `APIResponse` with the raw body, headers, decoded diagnosis, and timing.

Tests inject a `Transport` stub. The real implementation is `URLSessionTransport`.

## JWS decoding

`PeelCore.JWSDecoder` walks the JSON tree and replaces any string keyed by `signed*` with a structured envelope:

```json
{
  "signedTransactionInfo": {
    "__peel_jws": true,
    "header": { "alg": "ES256", "x5c": [...] },
    "payload": { "transactionId": "...", ... },
    "x5cPresent": true,
    "raw": "eyJhbGc..."
  }
}
```

This works recursively, so nested JWS payloads (Apple's server notifications carry JWS-within-JWS) decode in one pass.

Full cert-chain validation against Apple's Root CA is a planned v1.1 feature; the decoder already surfaces `x5cPresent` so the UI can show a "not yet verified" badge.

## Adding a new endpoint

Three files, in order:

1. `Sources/PeelCore/EndpointID.swift` — add the case.
2. `Sources/PeelAPI/RequestParameters.swift` — declare its parameter fields in `EndpointCatalog.fields(for:)`.
3. `Sources/PeelAPI/EndpointBuilder.swift` — declare URL template and body.

The UI is data-driven and picks up the new endpoint automatically.

## Performance budgets

Targets enforced by manual review (we don't yet have automated perf tests in CI):

- Cold launch to interactive: < 800 ms on M1.
- Memory idle: < 250 MB RSS.
- 10k-row history scroll: 60 fps.
- Compare diff on 1 MB response: < 200 ms.

## Testing

- Unit tests for every Core, API, and Persistence module.
- SwiftData uses `isStoredInMemoryOnly` so tests don't touch disk.
- The Client uses a `Transport` protocol so tests don't hit the network.
- UI snapshot / XCUITest coverage is a planned addition.
