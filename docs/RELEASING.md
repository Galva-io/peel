# Releasing Peel

This page is for maintainers. End users should grab the latest build from [Releases](https://github.com/galva/peel/releases/latest); contributors can find development artifacts on the [CI run summary](https://github.com/galva/peel/actions/workflows/ci.yml).

## Release flavors

| Flavor | Trigger | Signed | Notarized | DMG | Artifact retention |
|---|---|:---:|:---:|:---:|---|
| **CI build** | Every push to `main` / PR | Ad-hoc | — | — | 30 days |
| **Manual dev build** | `workflow_dispatch` on Release workflow | Only if secrets set | Only if secrets set | ✓ | 90 days |
| **Tagged release** | Push `vX.Y.Z` tag | ✓ (if secrets set) | ✓ (if secrets set) | ✓ | Permanent (GH Release) |

The Release workflow is intentionally tolerant: forks without the Apple Developer secrets still produce a downloadable, ad-hoc-signed `.app` and `.dmg`. Users see a Gatekeeper warning on first launch and right-click → Open.

## Required secrets for signed releases

Set these on the repo (or org) in GitHub → Settings → Secrets and variables → Actions:

| Secret | What it is |
|---|---|
| `APPLE_DEVELOPER_ID_CERT_BASE64` | Base64 of a `Developer ID Application` `.p12` certificate exported from Keychain Access. `base64 -i cert.p12 \| pbcopy`. |
| `APPLE_DEVELOPER_ID_CERT_PASSWORD` | The export password for that `.p12`. |
| `APPLE_NOTARIZATION_USER` | The Apple ID email used for notarization (typically the account holder). |
| `APPLE_NOTARIZATION_PASSWORD` | An app-specific password generated at [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords. |
| `APPLE_TEAM_ID` | 10-character Team ID from [developer.apple.com/account](https://developer.apple.com/account). |

If any of these are missing the workflow falls back to ad-hoc signing — the build still succeeds and the artifacts still upload, just without notarization.

## Cutting a release

1. **Update `CHANGELOG.md`.** Move items from `[Unreleased]` into a new dated section for the version.
2. **Tag.** `git tag v1.2.3 && git push origin v1.2.3`.
3. **Wait ~10 minutes.** The Release workflow:
   - Runs the full test suite.
   - Stamps `CFBundleShortVersionString` and `CFBundleVersion` from the tag and the run number.
   - Builds + ad-hoc-signs locally via `./scripts/bundle.sh release`.
   - Imports the Developer ID cert into a fresh ephemeral keychain.
   - Re-signs `Peel.app` and the wrapping `.dmg` with the Developer ID identity.
   - Submits the `.dmg` to Apple's notarization service via `notarytool` and waits for the result (typically 1–4 minutes).
   - Staples the notarization ticket to the DMG.
   - Builds a `ditto`-packaged `Peel.zip` (preserves resource forks; `zip` doesn't).
   - Creates a GitHub Release with auto-generated notes and uploads both `.dmg` and `.zip`.

You can watch the run live on the [Actions tab](https://github.com/galva/peel/actions).

## Verifying a signed release locally

```bash
# 1. Download the DMG from the release.
gh release download v1.2.3 --pattern '*.dmg'

# 2. Confirm the signature.
codesign --verify --strict --deep --verbose=2 Peel.app
spctl --assess --verbose=4 --type execute Peel.app
# Should print: "accepted, source=Notarized Developer ID"
```

## Triggering an ad-hoc dev DMG without a tag

Maintainers can build a dev DMG without cutting a tag:

1. Go to **Actions → Release → Run workflow**.
2. Optionally fill in a version label (e.g. `1.2.3-rc1`).
3. The DMG and ZIP land in the run's artifacts.

These ad-hoc DMGs are signed/notarized if the secrets exist, but they're not published to the GitHub Releases page — they live in the run's artifact bucket for 90 days.

## Local release rehearsal

You can reproduce the whole release pipeline locally without the workflow:

```bash
# Build the signed bundle (ad-hoc signing — not Developer ID).
./scripts/bundle.sh release

# Stage and build the DMG the same way the workflow does.
mkdir -p build/dmg-stage
cp -R build/Peel.app build/dmg-stage/
ln -s /Applications build/dmg-stage/Applications
hdiutil create \
    -volname "Peel 1.2.3-local" \
    -srcfolder build/dmg-stage \
    -ov -format UDZO \
    build/Peel-1.2.3-local.dmg

# If you have Developer ID + notarytool credentials in your environment,
# re-sign and notarize the same way the workflow does.
```
