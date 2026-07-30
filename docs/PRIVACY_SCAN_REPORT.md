# Release Privacy and Security Scan Report

Artifact: Portfolio 1.0.0 Universal 2

Scan date: 2026-07-30

Build signing mode: ad-hoc with hardened runtime

## Result

**Pass for bundle privacy.**

The automated privacy gate passed the staged `.app`, the app copied from the
mounted DMG, and the app extracted from the ZIP. The release build is assembled
from `macos/release-assets.txt`; it never copies the repository as a directory.

## Checks performed

| Check | Result |
| --- | --- |
| Current macOS username outside reviewed product content | Pass |
| Current home-directory path and every `/Users/` path | Pass |
| Current computer name | Pass |
| Unapproved email addresses | Pass |
| Strong API-key, access-token, and private-key patterns | Pass |
| `.env` and private signing/configuration files | Pass |
| Databases (`.db`, `.sqlite`, `.sqlite3` and journals) | Pass; none present |
| Import, recent-file, history, cookie, and session files | Pass; none present |
| Local Storage, IndexedDB, browser profiles, and service-worker state | Pass; none bundled |
| Cache, thumbnail, preview, log, crash, and temporary files | Pass; none bundled |
| `.DS_Store`, Finder aliases, and Git metadata | Pass; none bundled |
| Source maps, debug symbols, and local development URLs | Pass; none bundled |
| Symlinks inside the `.app` bundle | Pass; none present |
| Strong-secret patterns in current release source | Pass |
| Strong-secret patterns across existing Git commits | Pass; zero commits matched |
| Production dependency vulnerability audit | Pass; zero dependencies and zero findings |
| Full npm dependency vulnerability audit | Pass; zero dependencies and zero findings |

## Reviewed product-content exception

This is a personal portfolio. The owner's name, portrait, public résumé, contact
email, website, and GitHub handle are intentional published content rather than
development-time state. The scanner permits those known strings only in reviewed
web assets and the `Info.plist` copyright field. It does not permit personal file
paths, device data, sessions, histories, credentials, or those identity strings in
the native executable, logs, or unreviewed bundle files.

## Specifically excluded repository content

- `.git/`
- `node_modules/`
- all `.DS_Store` files
- `contact/index.html alias`, which contains the developer's absolute path and a
  file/device identifier
- the complete `meta/` feature, including `meta/loc.csv` commit author, hashes,
  dates, time zones, filenames, and work-pattern history
- `package.json` and `package-lock.json`
- development source not named in the release asset allowlist
- the unneeded full-resolution source portrait

Raster images are decoded and re-encoded into staging without source metadata.
The originals remain unchanged.

## Runtime privacy

- `WKWebsiteDataStore.nonPersistentDataStore` prevents persistent WebKit cookies,
  HTTP cache, Local Storage, IndexedDB, and service-worker state.
- No database exists because the application has no writable library or
  user-content model.
- Fresh app-specific Application Support, Caches, and Logs directories are
  created on first launch.
- A log file is created only for errors. The missing-content test confirmed the
  diagnostic text is readable and contains no user path or email.
- No protected macOS permissions or entitlements are requested.

Raw machine-readable reports are under `build/release/reports/`.
