# macOS Release Guide

## Product metadata

- App name: Portfolio
- Bundle identifier: `com.datafolio.portfolio`
- Version: `1.0.0`
- Build: `1`
- Minimum macOS: 11.0
- Architectures: Universal 2 (`arm64` and `x86_64`)
- Category: Business
- Protected permissions: none
- Runtime dependencies: Apple AppKit and WebKit system frameworks only

## Clean local build

From a clean checkout on macOS with Apple Command Line Tools:

```bash
./scripts/release/clean.sh
./scripts/release/build-macos.sh
ALLOW_ADHOC_RELEASE=1 ./scripts/release/verify-release.sh
./scripts/release/test-release.sh
```

The local default uses ad-hoc code signing. It is suitable for integrity and
packaging tests but not for a quarantined public download.

The output is written only under `build/release/`:

- `Portfolio.app`
- `Portfolio-1.0.0-universal.app.zip`
- `Portfolio-1.0.0-universal.dmg`
- `SHA256SUMS.txt`
- `reports/`

The build starts in a unique staging directory and copies web resources using
`macos/release-assets.txt`. It never copies the repository wholesale.

## Developer ID release

Install a valid Developer ID Application certificate in the login Keychain, then
run:

```bash
./scripts/release/clean.sh
MACOS_SIGN_IDENTITY='Developer ID Application: Legal Name (TEAMID)' \
  ./scripts/release/build-macos.sh
./scripts/release/verify-release.sh
```

The signing identity is passed by name only. Certificate files, passwords, API
keys, and profiles must never be placed in the repository.

## Notarization and stapling

Store credentials once in the Keychain using Apple's `notarytool`:

```bash
xcrun notarytool store-credentials PORTFOLIO_NOTARY
```

Then submit the already Developer-ID-signed DMG:

```bash
NOTARY_KEYCHAIN_PROFILE=PORTFOLIO_NOTARY \
  ./scripts/release/notarize.sh \
  build/release/Portfolio-1.0.0-universal.dmg
./scripts/release/verify-release.sh
```

The script references the Keychain profile by name and does not print signing or
notarization secrets.

## Version overrides

Release metadata may be overridden without editing source:

```bash
APP_VERSION=1.1.0 APP_BUILD_NUMBER=2 \
MACOSX_DEPLOYMENT_TARGET=11.0 \
MACOS_SIGN_IDENTITY='Developer ID Application: Legal Name (TEAMID)' \
  ./scripts/release/build-macos.sh
```

`APP_VERSION` is used in the output filenames and `Info.plist`;
`APP_BUILD_NUMBER` is used as `CFBundleVersion`.

## Verification policy

The verification script:

1. checks the app signature and both executable architectures;
2. validates important `Info.plist` fields;
3. runs the release privacy scan;
4. tests the ZIP archive;
5. mounts the DMG read-only;
6. copies its app into a fresh temporary `Applications` directory;
7. rechecks the signature and privacy state;
8. extracts and verifies the ZIP copy;
9. runs Gatekeeper assessment;
10. validates the stapled notarization ticket; and
11. verifies SHA-256 checksums.

`ALLOW_ADHOC_RELEASE=1` permits only the two expected local-development failures:
Gatekeeper public-download acceptance and notarization/stapling. Never use that
override for a production release.

## Clean-machine acceptance

Before publishing, run the final notarized DMG in a separate clean macOS user
account or VM with no development tools. Complete every item in
`docs/CLEAN_MACHINE_CHECKLIST.md`. This repository's automated test uses an
isolated temporary user home and exercises the actual app copied from the mounted
DMG, but it cannot substitute for an independent clean Mac and quarantined
download.
