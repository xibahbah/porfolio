# Third-Party Dependency and License Report

Generated for Portfolio 1.0.0 on 2026-07-30.

## Distributed runtime

The macOS application bundle contains no third-party runtime libraries,
frameworks, packages, helper executables, fonts, or JavaScript dependencies.

The native host links only to Apple system frameworks:

- AppKit/Cocoa
- Foundation
- ImageIO is used only by the build-time metadata sanitizer and is not linked by
  the distributed app.
- WebKit

The application content uses HTML, CSS, and dependency-free JavaScript. The
previous CDN-hosted D3 import is not part of the release.

The app icon is rendered from the repository's existing
`images/projects/portfolio.svg` artwork; it is not third-party artwork.

## Development dependencies

There are no current npm runtime or development dependencies. `package-lock.json`
pins an empty dependency graph.

The pre-release repository used `elocuent@0.0.4` to generate the development-only
`meta/loc.csv` history visualization. Its transitive dependency tree became
affected by a high-severity `brace-expansion` denial-of-service advisory with no
compatible fix. Because that analyzer is not required to build, package, or run
the product—and `meta/` is intentionally excluded from distribution—the unused
tool and its entire dependency tree were removed.

This report is an inventory, not legal advice.
