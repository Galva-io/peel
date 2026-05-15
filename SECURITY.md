# Security policy

## Reporting a vulnerability

Please report security issues privately to **security@peel-app.com** or via [GitHub Security Advisories](https://github.com/galva/peel/security/advisories/new). Do **not** open a public issue.

We aim to acknowledge reports within 48 hours and provide a fix or remediation plan within 30 days. Critical issues affecting the trust model (key handling, allowlist bypass, sandbox escape) are prioritized above all other work.

## Threat model summary

Peel handles App Store Connect private keys, which are high-value secrets. The trust model is:

| Threat | Mitigation |
|---|---|
| Key exfiltration | Keys stored in macOS Keychain with `AccessibleAfterFirstUnlockThisDeviceOnly`, `Synchronizable = false`. Never written to disk in plaintext, never synced to iCloud. |
| Accidental production action | Read-only mode is on by default. Production calls require explicit confirmation and a two-step flow for mutating actions. |
| Network exfiltration | Hard-coded host allowlist (`api.storekit.itunes.apple.com`, `api.storekit-sandbox.itunes.apple.com`, plus Sparkle update host). Requests to any other host fail closed. |
| Malicious update | Sparkle 2 EdDSA signature verification against Galva's signing key. Stable and beta channels are signature-separated. |
| Webhook receiver attack surface | Bound to `127.0.0.1` only. Never reachable from another machine. |
| Audit log leaking PII | Sensitive parameters (App Account Token, emails, custom data) are redacted at write time. The log is local-only and never transmitted. |
| Supply chain | Zero third-party Swift dependencies. The full dependency graph is the Swift standard library, CryptoKit, AppKit, SwiftUI, Network, SwiftData. |

## Scope

This policy covers:

- The Peel macOS app (this repository).
- Build, sign, and release infrastructure that produces shipped binaries.

It does **not** cover:

- Third-party services Peel talks to (Apple's App Store Server API itself).
- User-created modifications to a self-built copy of Peel.

## Disclosure

Once a fix is released, we publish a public advisory with:

- A description of the vulnerability and its impact.
- Affected versions.
- The fix and mitigation steps.
- Credit to the reporter (with permission).
