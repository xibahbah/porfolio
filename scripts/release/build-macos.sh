#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

release_require_macos
for command_name in clang codesign hdiutil iconutil lipo plutil sips strip; do
    release_require_command "$command_name"
done

app_name="Portfolio"
bundle_identifier="com.datafolio.portfolio"
version="${APP_VERSION:-1.0.0}"
build_number="${APP_BUILD_NUMBER:-1}"
minimum_macos="${MACOSX_DEPLOYMENT_TARGET:-11.0}"
signing_identity="${MACOS_SIGN_IDENTITY:--}"
artifact_stem="${app_name}-${version}-universal"
output_directory="$RELEASE_BUILD_ROOT/release"
reports_directory="$output_directory/reports"
mkdir -p "$RELEASE_BUILD_ROOT"
stage_root="$(mktemp -d "$RELEASE_BUILD_ROOT/.release-stage.XXXXXX")"
app_path="$output_directory/$app_name.app"
dmg_path="$output_directory/$artifact_stem.dmg"
zip_path="$output_directory/$artifact_stem.app.zip"
manifest="$RELEASE_REPO_ROOT/macos/release-assets.txt"

cleanup_stage() {
    if [[ -e "$stage_root" ]]; then
        release_remove_build_path "$stage_root"
    fi
}
trap cleanup_stage EXIT

release_reset_directory "$output_directory"
mkdir -p "$reports_directory"

"$SCRIPT_DIR/secret-scan.sh" \
    >"$reports_directory/SECRET_SCAN.txt"

sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
stage_app="$stage_root/$app_name.app"
stage_contents="$stage_app/Contents"
stage_macos="$stage_contents/MacOS"
stage_resources="$stage_contents/Resources"
stage_web="$stage_resources/Web"
mkdir -p "$stage_macos" "$stage_web"

clang \
    -fobjc-arc \
    -Os \
    -DNDEBUG \
    -arch arm64 \
    -arch x86_64 \
    -mmacosx-version-min="$minimum_macos" \
    -isysroot "$sdk_path" \
    "$RELEASE_REPO_ROOT/macos/Sources/main.m" \
    -framework Cocoa \
    -framework WebKit \
    -o "$stage_macos/$app_name"
strip -S -x "$stage_macos/$app_name"

clang \
    -fobjc-arc \
    -Os \
    -isysroot "$sdk_path" \
    "$RELEASE_REPO_ROOT/macos/Tools/ImageSanitizer.m" \
    -framework Foundation \
    -framework ImageIO \
    -framework CoreGraphics \
    -o "$stage_root/image-sanitizer"

ditto --noqtn "$RELEASE_REPO_ROOT/macos/Info.plist" \
    "$stage_contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$bundle_identifier" \
    "$stage_contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" \
    "$stage_contents/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" \
    "$stage_contents/Info.plist"
plutil -replace LSMinimumSystemVersion -string "$minimum_macos" \
    "$stage_contents/Info.plist"

while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    [[ "$relative_path" == \#* ]] && continue
    [[ "$relative_path" != /* ]] ||
        release_die "absolute allowlist path: $relative_path"
    [[ "$relative_path" != *".."* ]] ||
        release_die "parent traversal in allowlist: $relative_path"

    source_path="$RELEASE_REPO_ROOT/$relative_path"
    destination_path="$stage_web/$relative_path"
    [[ -f "$source_path" ]] ||
        release_die "missing allowlisted asset: $relative_path"
    mkdir -p "$(dirname "$destination_path")"

    case "${relative_path##*.}" in
        png | jpg | jpeg)
            "$stage_root/image-sanitizer" \
                "$source_path" "$destination_path"
            ;;
        *)
            ditto --noqtn "$source_path" "$destination_path"
            ;;
    esac
done <"$manifest"

expected_assets="$stage_root/expected-assets.txt"
actual_assets="$stage_root/actual-assets.txt"
grep -v '^[[:space:]]*#' "$manifest" |
    grep -v '^[[:space:]]*$' |
    LC_ALL=C sort >"$expected_assets"
find "$stage_web" -type f -print |
    sed "s#^$stage_web/##" |
    LC_ALL=C sort >"$actual_assets"
cmp -s "$expected_assets" "$actual_assets" ||
    release_die "staged resources differ from the release allowlist"

icon_work="$stage_root/icon-work"
icon_set="$icon_work/AppIcon.iconset"
mkdir -p "$icon_set"
sips -s format png \
    "$RELEASE_REPO_ROOT/images/projects/portfolio.svg" \
    --out "$icon_work/icon-wide.png" >/dev/null
sips -Z 900 "$icon_work/icon-wide.png" >/dev/null
sips -p 1024 1024 --padColor 1f1f1f \
    "$icon_work/icon-wide.png" \
    --out "$icon_work/icon-master.png" >/dev/null 2>&1

while IFS=':' read -r filename pixels; do
    sips -z "$pixels" "$pixels" "$icon_work/icon-master.png" \
        --out "$icon_set/$filename" >/dev/null
done <<'ICON_SIZES'
icon_16x16.png:16
icon_16x16@2x.png:32
icon_32x32.png:32
icon_32x32@2x.png:64
icon_128x128.png:128
icon_128x128@2x.png:256
icon_256x256.png:256
icon_256x256@2x.png:512
icon_512x512.png:512
icon_512x512@2x.png:1024
ICON_SIZES
iconutil -c icns "$icon_set" -o "$stage_resources/AppIcon.icns"

ditto --noqtn "$stage_app" "$app_path"

if [[ "$signing_identity" == "-" ]]; then
    codesign --force --sign - --options runtime --timestamp=none \
        "$app_path/Contents/MacOS/$app_name"
    codesign --force --sign - --options runtime --timestamp=none \
        "$app_path"
    signing_mode="ad-hoc"
else
    codesign --force --sign "$signing_identity" \
        --options runtime --timestamp \
        "$app_path/Contents/MacOS/$app_name"
    codesign --force --sign "$signing_identity" \
        --options runtime --timestamp \
        "$app_path"
    signing_mode="Developer ID"
fi

codesign --verify --deep --strict --verbose=2 "$app_path" 2>&1 |
    tee "$reports_directory/CODESIGN_VERIFY.txt"
lipo -archs "$app_path/Contents/MacOS/$app_name" |
    tee "$reports_directory/ARCHITECTURES.txt"
"$SCRIPT_DIR/privacy-scan.sh" "$app_path" 2>&1 |
    tee "$reports_directory/PRIVACY_SCAN.txt"

find "$app_path" -print |
    sed "s#^$output_directory/##" |
    LC_ALL=C sort >"$reports_directory/BUNDLE_MANIFEST.txt"

ditto -c -k --keepParent "$app_path" "$zip_path"

dmg_root="$stage_root/dmg-root"
mkdir -p "$dmg_root"
ditto --noqtn "$app_path" "$dmg_root/$app_name.app"
ln -s /Applications "$dmg_root/Applications"
hdiutil create \
    -volname "$app_name" \
    -srcfolder "$dmg_root" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$dmg_path" >/dev/null

if [[ "$signing_identity" != "-" ]]; then
    codesign --force --sign "$signing_identity" --timestamp "$dmg_path"
fi

cp "$RELEASE_REPO_ROOT/docs/THIRD_PARTY_LICENSES.md" \
    "$reports_directory/THIRD_PARTY_LICENSES.md"

(
    cd "$output_directory"
    shasum -a 256 \
        "$(basename "$dmg_path")" \
        "$(basename "$zip_path")" \
        >SHA256SUMS.txt
)

{
    printf 'App: %s\n' "$app_name"
    printf 'Version: %s (%s)\n' "$version" "$build_number"
    printf 'Bundle ID: %s\n' "$bundle_identifier"
    printf 'Minimum macOS: %s\n' "$minimum_macos"
    printf 'Architectures: %s\n' \
        "$(lipo -archs "$app_path/Contents/MacOS/$app_name")"
    printf 'Signing mode: %s\n' "$signing_mode"
    printf 'Icon source: images/projects/portfolio.svg\n'
} >"$reports_directory/BUILD_SUMMARY.txt"

printf 'Built %s\n' "$app_path"
printf 'Built %s\n' "$dmg_path"
printf 'Built %s\n' "$zip_path"
printf 'Signing mode: %s\n' "$signing_mode"
