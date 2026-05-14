# Architecture

Peel is built as a single Swift Package with six targets. AppKit hosts the chrome (windowing, menu, toolbar, services, drag-drop). SwiftUI hosts the content (forms, JSON viewers, diff panels). The boundary is `NSHostingController`.

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
│  PeelAPI       PeelPersistence       PeelWebhook                     │
│  Client        Storage (SwiftData)   LocalListener (NWListener)      │
│  Endpoint…     History · Audit       HTTPParser                      │
└──────────────────────────────────────────────────────────────────────┘
            │              │
            ▼              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  PeelCore                                                            │
│  Models · JWTSigner · KeychainStore · JWSDecoder · JSONValue ·       │
│  JSONDiff · Anonymizer · AuthErrorMapper · AuditLog · Allowlist      │
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
- The webhook listener and incoming notifications.

`PeelAPI.Client`, `PeelPersistence.Storage`, and `PeelWebhook.LocalListener` are actors. The store talks to them with `await`. UI views observe the store directly via `@Bindable`.

This is intentionally simple — no Redux, no Combine plumbing, no view-models layered on top of view-models. Three layers: store → views, store → actors. Done.

## Persistence

SwiftData for structured records (apps, history index, audit log). Plain files for large response bodies (the SwiftData store stores a pointer; bodies > 64 KB land in `Application Support/Peel/blobs/`).

## Secrets

The `.p8` private key for each app sits in the Keychain only, keyed by the `AppConfig.id` UUID:

```
service: io.galva.peel
account: <uuid>.p8
data:    <PEM contents>
attrs:   AccessibleAfterFirstUnlockThisDeviceOnly · Synchronizable = false
```

The Storage layer never sees the key. Only `PeelAPI.Client` reads it, on the JWT-signing path.

## Networking

`PeelAPI.Client` is an actor that owns:

- The `URLSession` (or test transport).
- The `JWTCache` (one signed JWT per app per ~20 minutes).
- The `NetworkAllowlist` enforcement.

Every request goes through `dispatch(DispatchInput)`. The input carries the app context, environment, prepared `EndpointSpec`, and the read-only flag. The client signs the JWT (or pulls a cached one), constructs the `URLRequest`, sends it, and returns a typed `APIResponse` with the raw body, headers, decoded diagnosis, and timing.

Tests inject a `Transport` stub. The real implementation is `URLSessionTransport`.

## Webhook receiver

`PeelWebhook.LocalListener` is an `NWListener`-backed actor. It binds to `127.0.0.1:<port>` with `acceptLocalOnly = true`. It hand-parses HTTP because the receiver only needs to accept `POST` with a JSON body — SwiftNIO would be overkill for one route.

Each received notification is broadcast to registered handlers. The UI registers a handler at app bootstrap that prepends notifications to `PeelAppStore.receivedNotifications`, which the menu bar popover and the receiver-specific view subscribe to.

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

- Unit tests for every Core, API, Persistence, and Webhook module.
- SwiftData uses `isStoredInMemoryOnly` so tests don't touch disk.
- The Client uses a `Transport` protocol so tests don't hit the network.
- UI snapshot / XCUITest coverage is a planned addition.
