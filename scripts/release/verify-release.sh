#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

release_require_macos
for command_name in codesign hdiutil lipo plutil spctl unzip; do
    release_require_command "$command_name"
done

version="${APP_VERSION:-1.0.0}"
output_directory="$RELEASE_BUILD_ROOT/release"
app_path="${1:-"$output_directory/Portfolio.app"}"
dmg_path="${2:-"$output_directory/Portfolio-${version}-universal.dmg"}"
zip_path="$output_directory/Portfolio-${version}-universal.app.zip"
allow_adhoc="${ALLOW_ADHOC_RELEASE:-0}"

[[ -d "$app_path/Contents" ]] || release_die "app not found: $app_path"
[[ -f "$dmg_path" ]] || release_die "dmg not found: $dmg_path"
[[ -f "$zip_path" ]] || release_die "zip not found: $zip_path"

codesign --verify --deep --strict --verbose=2 "$app_path"
architectures="$(lipo -archs "$app_path/Contents/MacOS/Portfolio")"
[[ "$architectures" == *arm64* && "$architectures" == *x86_64* ]] ||
    release_die "application is not Universal 2: $architectures"

[[ "$(plutil -extract CFBundleIdentifier raw "$app_path/Contents/Info.plist")" == \
    "com.datafolio.portfolio" ]] ||
    release_die "unexpected bundle identifier"
[[ "$(plutil -extract LSMinimumSystemVersion raw "$app_path/Contents/Info.plist")" == \
    "11.0" ]] ||
    release_die "unexpected minimum macOS version"

"$SCRIPT_DIR/privacy-scan.sh" "$app_path"
unzip -t "$zip_path" >/dev/null
hdiutil verify "$dmg_path" >/dev/null

mount_point="$(mktemp -d "$RELEASE_BUILD_ROOT/.verify-mount.XXXXXX")"
copy_root="$(mktemp -d "$RELEASE_BUILD_ROOT/.verify-copy.XXXXXX")"
zip_root="$(mktemp -d "$RELEASE_BUILD_ROOT/.verify-zip.XXXXXX")"

cleanup_verify() {
    release_cleanup_mount "$mount_point"
    [[ ! -e "$copy_root" ]] || release_remove_build_path "$copy_root"
    [[ ! -e "$zip_root" ]] || release_remove_build_path "$zip_root"
}
trap cleanup_verify EXIT

hdiutil attach -nobrowse -readonly -mountpoint "$mount_point" \
    "$dmg_path" >/dev/null
[[ -d "$mount_point/Portfolio.app" ]] ||
    release_die "DMG does not contain Portfolio.app"
[[ -L "$mount_point/Applications" ]] ||
    release_die "DMG does not contain an Applications shortcut"

mkdir -p "$copy_root/Applications"
ditto --noqtn "$mount_point/Portfolio.app" \
    "$copy_root/Applications/Portfolio.app"
codesign --verify --deep --strict --verbose=2 \
    "$copy_root/Applications/Portfolio.app"
"$SCRIPT_DIR/privacy-scan.sh" \
    "$copy_root/Applications/Portfolio.app"

ditto -x -k "$zip_path" "$zip_root"
[[ -d "$zip_root/Portfolio.app" ]] ||
    release_die "ZIP does not contain Portfolio.app"
codesign --verify --deep --strict --verbose=2 \
    "$zip_root/Portfolio.app"
"$SCRIPT_DIR/privacy-scan.sh" "$zip_root/Portfolio.app"

if spctl --assess --type execute --verbose=4 "$app_path"; then
    printf 'PASS: Gatekeeper accepted the application.\n'
elif [[ "$allow_adhoc" == "1" ]]; then
    printf 'EXPECTED LIMITATION: Gatekeeper rejected the ad-hoc build.\n'
else
    release_die "Gatekeeper rejected the application"
fi

if spctl --assess --type open --context context:primary-signature \
    --verbose=4 "$dmg_path"; then
    printf 'PASS: Gatekeeper accepted the DMG.\n'
elif [[ "$allow_adhoc" == "1" ]]; then
    printf 'EXPECTED LIMITATION: Gatekeeper rejected the unsigned ad-hoc DMG.\n'
else
    release_die "Gatekeeper rejected the DMG"
fi

if xcrun stapler validate "$dmg_path" >/dev/null 2>&1; then
    printf 'PASS: notarization ticket is stapled to the DMG.\n'
elif [[ "$allow_adhoc" == "1" ]]; then
    printf 'EXPECTED LIMITATION: ad-hoc DMG is not notarized or stapled.\n'
else
    release_die "DMG has no valid stapled notarization ticket"
fi

(
    cd "$output_directory"
    shasum -a 256 -c SHA256SUMS.txt
)

printf 'PASS: app, ZIP, and mounted DMG contents verified.\n'
printf 'PASS: Universal 2 architectures: %s\n' "$architectures"
