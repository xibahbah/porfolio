# macOS Release Test Results

Artifact: Portfolio 1.0.0 Universal 2

Test date: 2026-07-30

Build host: macOS 26.1, Apple Silicon

## Automated and local tests

| Test | Result | Evidence or note |
| --- | --- | --- |
| Clean allowlist build | Pass | New staging directory; 27 final bundle files |
| Apple Silicon executable slice | Pass | `arm64` present |
| Intel executable slice | Pass | `x86_64` present |
| Minimum OS load command | Pass | macOS 11.0 |
| Runtime dependency inspection | Pass | Apple system frameworks only |
| Strict recursive code-sign verification | Pass | Ad-hoc signature with hardened runtime |
| Entitlements inspection | Pass | No entitlements requested |
| App privacy scan | Pass | Staged app |
| DMG integrity | Pass | `hdiutil verify` checksum valid |
| DMG mount and content inspection | Pass | App plus `/Applications` shortcut only |
| App copied from mounted DMG | Pass | Signature and privacy scan repeated |
| ZIP extraction and content inspection | Pass | Signature and privacy scan repeated |
| Real `/Applications` installation path | Pass | Copied from DMG, launched, verified, then temporary copy removed |
| Launch outside source directory | Pass | Launched installed packaged copy |
| Path with spaces | Pass | Packaged app path contained spaces |
| Chinese path characters | Pass | Packaged app path contained `安装`/`测试`/`用户` |
| Cyrillic path characters | Pass | Packaged app path contained `Тест` |
| First launch with isolated clean profile | Pass | Fresh app directories, no inherited state |
| Relaunch using the same profile | Pass | All workflows passed again |
| Home and navigation | Pass | Actual packaged WKWebView content |
| Projects list | Pass | All 13 records rendered |
| Project search | Pass | Filter reduced the rendered result correctly |
| Project chart | Pass | Offline dependency-free SVG chart rendered |
| Résumé page | Pass | All four sections present |
| Contact page | Pass | Form and textarea present |
| Offline resource policy | Pass | No remote scripts, styles, fetches, or development server |
| Database inspection | Pass | No database or database archive exists |
| Cache/history/session/log state after successful launch | Pass | None created |
| Missing application content | Pass | Readable error and redacted error-only log |
| Source secret scan | Pass | No strong credential patterns |
| Git-history strong-secret scan | Pass | Zero commits matched |
| Production npm audit | Pass | Zero dependencies, zero vulnerabilities |
| Full npm audit | Pass | Zero dependencies, zero vulnerabilities |
| SHA-256 verification | Pass | DMG and ZIP match `SHA256SUMS.txt` |
| Gatekeeper acceptance | **Fail / blocked** | Expected for ad-hoc build; no Developer ID identity installed |
| Apple notarization | **Not run / blocked** | Requires Developer ID signing and Apple notary credentials |
| Stapled ticket validation | **Fail / blocked** | No notarization ticket exists on ad-hoc DMG |
| Independent clean Mac/VM | **Not run** | Must be completed on the final notarized download |
| Physical Intel Mac launch | **Not run** | Intel slice exists; no Intel test machine was available |
| Browser-quarantined download | **Not run** | Requires hosted, Developer-ID-signed, notarized artifact |
| External mail/web applications | **Not run** | Avoided sending/opening external content during automated tests |
| Insufficient disk-space handling | **Not run** | Requires a controlled VM or constrained volume |

The generated artifacts are valid local test packages. They are not acceptable for
public download until the Developer ID, notarization, stapling, Gatekeeper, and
independent clean-machine rows pass.

Raw logs:

- `build/release/reports/CODESIGN_VERIFY.txt`
- `build/release/reports/PRIVACY_SCAN.txt`
- `build/release/reports/SECRET_SCAN.txt`
- `build/release/reports/TEST_RELEASE.txt`
- `build/release/reports/VERIFY_RELEASE.txt`
- `build/release/reports/NPM_AUDIT_PRODUCTION.json`
- `build/release/reports/NPM_AUDIT_ALL.json`
