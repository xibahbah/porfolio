#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

release_require_macos
release_require_command xcrun

artifact_path="${1:-}"
notary_profile="${NOTARY_KEYCHAIN_PROFILE:-}"

[[ -f "$artifact_path" ]] ||
    release_die "usage: notarize.sh /path/to/signed.dmg"
[[ -n "$notary_profile" ]] ||
    release_die "NOTARY_KEYCHAIN_PROFILE must name a stored notarytool profile"

codesign --verify --verbose=2 "$artifact_path"
xcrun notarytool submit "$artifact_path" \
    --keychain-profile "$notary_profile" \
    --wait
xcrun stapler staple "$artifact_path"
xcrun stapler validate "$artifact_path"
spctl --assess --type open --context context:primary-signature \
    --verbose=4 "$artifact_path"

printf 'Notarized and stapled: %s\n' "$artifact_path"
