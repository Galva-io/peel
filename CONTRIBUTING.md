# Contributing to Peel

Peel is open source and we want your help. The project is structured to make incremental contributions easy — every layer is its own Swift Package target with its own test target.

## Quick start

```bash
git clone https://github.com/galva/peel.git
cd peel
swift test                    # 44 tests, takes < 5 s
```

For day-to-day development, generate the Xcode project with Tuist:

```bash
brew install tuist            # one-time
tuist generate                # creates Peel.xcworkspace
open Peel.xcworkspace         # ⌘R to run the .app
```

You can still build from the command line without Tuist — `swift build` produces the executable and `./scripts/bundle.sh debug` wraps it into a runnable `.app`. CI uses the SPM path so PRs don't need Tuist to ship.

The two manifests stay in sync because they read the same `Sources/` and `Tests/` directories. When you add a new file under an existing module, neither manifest needs to change.

## How to add a new endpoint

App Store ships new endpoints periodically. To add one:

1. Add a case to `EndpointID` in [`Sources/PeelCore/EndpointID.swift`](Sources/PeelCore/EndpointID.swift). Include display name, category, mutating flag, and docs URL.
2. Add a field list to `EndpointCatalog.fields(for:)` in [`Sources/PeelAPI/RequestParameters.swift`](Sources/PeelAPI/RequestParameters.swift).
3. Add the URL template and body shape to `EndpointBuilder.build` in [`Sources/PeelAPI/EndpointBuilder.swift`](Sources/PeelAPI/EndpointBuilder.swift).
4. Add tests to `Tests/PeelAPITests/EndpointBuilderTests.swift`.

The UI picks up the new endpoint automatically from `EndpointID.allCases`.

## Style and reviews

- **No new dependencies without discussion.** Peel deliberately depends only on Apple frameworks. Adding a third-party library raises supply-chain questions.
- **Tests required for new logic.** UI changes can ship without unit tests when XCUITest coverage isn't practical, but Core/API/Persistence/Webhook code should always come with tests.
- **Match the existing code style.** Two-space indent, descriptive identifiers, comments only where the *why* isn't obvious.
- **No `force_unwrap` unless safe.** If you find a force-unwrap in existing code, please replace it with explicit error handling.

## Out of scope

- **Telemetry expansion.** What gets reported is intentionally minimal.
- **Cloud sync.** Local-only is the trust contract.
- **Forking distribution channels.** Releases come only from Galva's signing key.

## Reporting security issues

Please see [SECURITY.md](SECURITY.md) — do **not** file public issues for vulnerabilities.

## Code of conduct

We follow the [Contributor Covenant 2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
