# Modified and New Files

## Modified

- `.gitignore` — excludes release output, secrets, databases, runtime state,
  local metadata, and generated test material.
- `contact/index.html` — loads the offline-safe global script.
- `global.js` — uses bundle-relative URLs, adds complete navigation, removes
  network-dependent helpers, renders projects without HTML injection, and handles
  contact mail links.
- `index.html` — loads the offline-safe global script.
- `package.json` — adds release commands and removes the unused vulnerable
  development analyzer.
- `package-lock.json` — pins the now-empty npm dependency graph.
- `projects/index.html` — loads local project data and dependency-free scripts.
- `projects/projects.js` — replaces CDN-hosted D3 with local SVG chart and filter
  logic.
- `resume/index.html` — loads the offline-safe global script.

## New source and configuration

- `lib/projects.js`
- `macos/Info.plist`
- `macos/Sources/main.m`
- `macos/Tools/ImageSanitizer.m`
- `macos/release-assets.txt`

## New release automation

- `scripts/release/common.sh`
- `scripts/release/clean.sh`
- `scripts/release/build-macos.sh`
- `scripts/release/secret-scan.sh`
- `scripts/release/privacy-scan.sh`
- `scripts/release/verify-release.sh`
- `scripts/release/test-release.sh`
- `scripts/release/notarize.sh`

## New documentation

- `docs/DATA_EXCLUSION_AUDIT.md`
- `docs/MACOS_RELEASE.md`
- `docs/CLEAN_MACHINE_CHECKLIST.md`
- `docs/THIRD_PARTY_LICENSES.md`
- `docs/PRIVACY_SCAN_REPORT.md`
- `docs/TEST_RESULTS.md`
- `docs/MODIFIED_FILES.md`

## Generated, ignored artifacts

- `build/release/Portfolio.app`
- `build/release/Portfolio-1.0.0-universal.app.zip`
- `build/release/Portfolio-1.0.0-universal.dmg`
- `build/release/SHA256SUMS.txt`
- `build/release/reports/*`

The original `.DS_Store` files, Finder alias, `meta/` history, source portraits,
project artwork, and other existing repository files were not deleted or modified.
