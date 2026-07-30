# Clean-Machine macOS Release Checklist

Record Pass or Fail for the exact notarized DMG intended for publication.

| Test | Status | Notes |
| --- | --- | --- |
| Download DMG through a browser so quarantine is applied | Not run | Requires final hosted artifact |
| Open DMG | Not run | Requires clean Mac/VM |
| Drag app to `/Applications` | Not run | Requires clean Mac/VM |
| First launch by clicking the icon in Finder | Not run | Requires Developer ID and notarization |
| Gatekeeper accepts without an override | Not run | Requires Developer ID and notarization |
| Initial state contains no history, library, recents, projects, account, cache, or logs | Not run | Requires clean Mac/VM |
| App creates only fresh app-specific user directories | Not run | Requires clean Mac/VM |
| Home, Projects, chart/filter, search, Résumé, and Contact work | Not run | Requires clean Mac/VM |
| External web and email links open in default apps | Not run | Requires clean Mac/VM |
| App launches offline | Not run | Requires clean Mac/VM |
| Denied or unavailable network causes no crash | Not run | Requires clean Mac/VM |
| Missing app content produces a readable error | Not run | Requires destructive test copy |
| Insufficient disk space produces a readable system error | Not run | Requires controlled VM |
| Path with spaces, Chinese, and Cyrillic characters works | Not run | Automated locally; repeat on clean Mac |
| Relaunch works and no browser state is retained | Not run | Requires clean Mac/VM |
| Update from previous version preserves user data | Not applicable | Version 1.0 has no user-generated data store |
| Removing/replacing app does not remove `~/Library` data | Not run | Requires clean Mac/VM |
| Reinstall works | Not run | Requires clean Mac/VM |
| App works outside the source directory | Not run | Automated locally; repeat on clean Mac |
| Recursive app inspection finds no development/personal runtime data | Not run | Requires final notarized artifact |
| Mounted DMG and extracted ZIP match signed app | Not run | Automated locally; repeat for final artifact |
| `codesign --verify`, `spctl`, and `stapler validate` pass | Not run | Requires final notarized artifact |

Tester:

macOS version:

Mac model/architecture:

Artifact SHA-256:

Date:
