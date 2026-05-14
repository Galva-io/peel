# Changelog

All notable changes to Peel are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). Versioning follows [SemVer](https://semver.org).

## [Unreleased]

### Added

- Initial v1.0 release scaffolding:
  - Multi-app sidebar with Keychain-backed `.p8` key storage.
  - Full endpoint coverage for App Store Server API v1 + v2 (subscriptions, transactions, refunds, notifications, identity, mutating actions).
  - Nested JWS auto-decode for `signedPayload`, `signedTransactionInfo`, `signedRenewalInfo`.
  - Compare mode with structural JSON diff + semantic summaries.
  - Local `127.0.0.1` webhook receiver bound to a configurable port.
  - Customer-support workflow: lookups by transaction, order, App Account Token.
  - Menu bar quick-lookup popover.
  - Read-only mode by default, with production-tinted chrome and confirmation dialogs.
  - Local audit log with redaction at write time, JSONL export.
  - Settings tabs for General, Apps, Security, Webhook, History, Updates, Telemetry, Shortcuts, About.

### Security

- Hard-coded network allowlist limited to Apple's App Store Server API hosts and Galva's Sparkle update host.
- Keys stored only in Keychain with `AccessibleAfterFirstUnlockThisDeviceOnly` and `Synchronizable = false`.
