# Release Data-Exclusion Audit

Audit date: 2026-07-30

This audit records the repository state before the macOS distribution work began.
It distinguishes intentional, reviewed portfolio content from development metadata
and runtime user data. The release is assembled in a new staging directory from an
explicit allowlist; it never copies the repository wholesale or deletes the
developer's local files.

## Application inventory

| Item | Pre-change finding |
| --- | --- |
| Framework | Static HTML, CSS, and browser JavaScript |
| Language | HTML, CSS, JavaScript |
| Entry point | `index.html` |
| Package manager | npm, used only for a development analyzer |
| Build system | None |
| Runtime dependencies | A browser engine; the projects page also imported D3 from a CDN |
| Development dependencies | `elocuent@0.0.4` and its locked transitive npm dependencies |
| Database | None |
| Desktop packaging | None |

The macOS release uses a native Objective-C/AppKit host and the WebKit framework supplied
by macOS. It does not distribute or require Node.js, npm, Python, Homebrew, FFmpeg,
or a local server.

## Storage and data-location map

| Location or mechanism | What it contains before this work | Ship it? | Exclusion or runtime policy | New-user location | Verification |
| --- | --- | --- | --- | --- | --- |
| Repository root `.DS_Store` | Finder view metadata | No | Never present in the allowlist | None | Bundle filename scan |
| `contact/.DS_Store` | Finder view metadata | No | Never present in the allowlist | None | Bundle filename scan |
| `images/.DS_Store` | Finder view metadata | No | Never present in the allowlist | None | Bundle filename scan |
| `contact/index.html alias` | Finder alias with `/Users/keith/...` and a file/device identifier | No | Never present in the allowlist | None | Bundle filename, path, and strings scans |
| `.git/` | Full source history and repository metadata | No | Staging is populated file-by-file; `.git` is forbidden | None | Bundle filename scan |
| `node_modules/` | Development analyzer and transitive npm packages | No | Not a release input | None | Bundle filename scan |
| `package.json`, `package-lock.json` | Development tooling configuration and dependency lock | No | Not a runtime input | None | Bundle manifest inspection |
| `meta/loc.csv` | Git author handle, commit hashes, dates, time zones, filenames, and work-pattern history | No | Entire `meta/` feature is omitted | None | Allowlist comparison and strings scan |
| `meta/index.html`, `meta/main.js` | UI and code that expose the development-history dataset and repository URL | No | Entire `meta/` feature is omitted | None | Allowlist comparison and bundle scan |
| `images/selfie*.{jpg,png}` | Intentional public portrait content; files also contain image metadata | Reviewed product content | Only required release renditions are copied; staged copies are metadata-sanitized | Read-only in the app bundle | Metadata inspection and approved-resource manifest |
| `images/projects/*.{png,svg}` | Intentional project artwork; the PNG may contain image metadata | Reviewed product content | Explicit filename allowlist; staged raster copy is metadata-sanitized | Read-only in the app bundle | Approved-resource manifest and metadata inspection |
| `index.html`, `resume/index.html`, `contact/index.html`, `lib/projects.json` | Intentional public portfolio biography, résumé, email, URLs, and project descriptions | Reviewed product content | Explicit allowlist. Public identity strings are allowed only in these reviewed web assets | Read-only in the app bundle | Context-aware release privacy scan |
| Browser Local Storage | Not used | No persistent copy | Native host uses `WKWebsiteDataStore.nonPersistent()` | None | Source scan and runtime WebKit configuration test |
| Browser IndexedDB/WebSQL | Not used | No persistent copy | Native host uses a nonpersistent WebKit data store | None | Source scan and runtime WebKit configuration test |
| Cookies and sessions | Not used | No persistent copy | Native host uses a nonpersistent WebKit data store | None | Source scan and bundle scan |
| Service-worker/cache storage | Not used | No persistent copy | No service worker is bundled; WebKit data store is nonpersistent | None | Source and bundle scans |
| Import/recent/search/navigation history | Not implemented | No | No document-recents API or history store is implemented | None | Source scan and clean-profile launch test |
| User library/projects/collections | Not implemented | No | No writable product-content store is implemented | None | Source scan and clean-profile launch test |
| User preferences | Not implemented | Defaults only | The host does not copy developer defaults or ship a preferences file | macOS may create an empty domain for the bundle identifier | Bundle scan and clean-profile launch test |
| Application database | Not implemented and not required for this read-only app | No | No database or template is bundled or created | None | Extension scan; any `.db`, `.sqlite`, or `.sqlite3` fails the release |
| Application Support | No pre-change app directory | No developer data | Created empty on first launch for future versioned app state | `~/Library/Application Support/com.datafolio.portfolio/` | Clean-home launch test |
| Disposable caches | No pre-change app directory | No developer data | Created empty on first launch; WebKit is nonpersistent | `~/Library/Caches/com.datafolio.portfolio/` | Clean-home launch test and source scan |
| Diagnostic logs | No pre-change app directory | No developer data | Directory is created on first launch; sanitized errors may be appended without secrets or absolute user paths | `~/Library/Logs/com.datafolio.portfolio/` | Clean-home launch test and log-content test |
| Environment variables | No source references and no `.env` files found | No | No environment file is copied; known secret filenames and token patterns fail the release | None | Secret and filename scans |
| Signing/notarization credentials | No valid code-signing identity found; no credential files found | No | Supplied only through Keychain identity/profile names at release time | Login Keychain and notarytool credential store | Bundle scan and build-log review |

## Intentional public-content decision

The application is a personal portfolio. Its source intentionally presents the
owner's name, portrait, public résumé, contact email, website, and GitHub handle.
Those are essential product content rather than development-time user state.
Removing them would turn the product into a different application.

The release scanner therefore uses a narrow exception: reviewed public identity
strings may occur only inside specifically approved web assets and the reviewed
copyright field in `Info.plist`. They remain forbidden in native binaries, paths,
logs, reports, and every other bundle file. `/Users/` paths, the local macOS
username as a path component, machine identifiers, local aliases, credentials,
histories, and unreviewed personal filenames have no exception.

## Clean-build and exclusion strategy

1. Build into a newly created release directory under `build/`.
2. Compile only the reviewed Objective-C source file into the executable.
3. Create `Info.plist` from fixed release metadata.
4. Copy web resources one file at a time from a fixed allowlist.
5. Sanitize copied raster-image metadata in staging, never in the source tree.
6. Do not copy the repository, `.git`, npm packages, development metadata,
   aliases, databases, caches, logs, sessions, temporary files, or environment
   files.
7. Compare the staged web-resource list with the allowlist and fail on any
   difference.
8. Run secret, forbidden-filename, absolute-path, development-URL, debug-data,
   storage-state, and binary-strings scans against the finished app.
9. Inspect any packaged database if one ever appears; the current policy rejects
   all database files because the app has no database.
10. Sign the nested code and app, build the DMG, mount it, re-inspect the copied
    app, verify signatures/Gatekeeper/notarization status, and emit SHA-256
    checksums.

The macOS icon is derived from the existing reviewed
`images/projects/portfolio.svg` artwork. No new icon artwork is introduced.

## Packaging technology and runtime policy

The selected wrapper is native Objective-C/AppKit with `WKWebView`:

- Apple Silicon and Intel slices are produced and combined as Universal 2.
- AppKit, WebKit, and the Objective-C runtime are macOS system components; no
  separate runtime is installed.
- Local assets are resolved from `Bundle.main`, never the current working
  directory.
- External HTTP(S) and mail links open in the user's default application.
- Browser storage is nonpersistent, so cookies, caches, Local Storage, IndexedDB,
  service workers, and navigation state are not inherited or retained.
- No microphone, camera, screen recording, accessibility, contacts, location, or
  other protected permission is requested.
- A standard About panel reports the version and build number.
- Startup failures use a readable alert and a redacted diagnostic log.

## Known pre-build constraint

No valid Developer ID code-signing identity is installed on the build Mac.
Ad-hoc signing can validate bundle integrity locally, but it cannot satisfy
Gatekeeper for a quarantined public download and cannot be notarized. The release
automation supports Developer ID signing, notarization, and stapling when the
required Apple credentials are available; production acceptance remains blocked
until those external credentials are supplied.
