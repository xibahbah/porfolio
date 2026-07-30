#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

manifest="$RELEASE_REPO_ROOT/macos/release-assets.txt"
[[ -f "$manifest" ]] || release_die "missing release asset manifest"

files=(
    "$RELEASE_REPO_ROOT/macos/Info.plist"
    "$RELEASE_REPO_ROOT/macos/Sources/main.m"
    "$RELEASE_REPO_ROOT/macos/Tools/ImageSanitizer.m"
)

while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    [[ "$relative_path" == \#* ]] && continue
    files+=("$RELEASE_REPO_ROOT/$relative_path")
done <"$manifest"

strong_secret_pattern='(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[0-9A-Za-z_-]{30,}|sk-[A-Za-z0-9_-]{20,}|-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----)'
failures=0

for file in "${files[@]}"; do
    [[ -f "$file" ]] || release_die "allowlisted source is missing: $file"
    if LC_ALL=C grep -E -a -q "$strong_secret_pattern" "$file"; then
        printf 'FAIL secret-like value: %s\n' \
            "${file#"$RELEASE_REPO_ROOT/"}" >&2
        failures=$((failures + 1))
    fi
done

while IFS= read -r -d '' private_file; do
    printf 'FAIL private configuration filename: %s\n' \
        "${private_file#"$RELEASE_REPO_ROOT/"}" >&2
    failures=$((failures + 1))
done < <(
    find "$RELEASE_REPO_ROOT" \
        -path "$RELEASE_REPO_ROOT/.git" -prune -o \
        -path "$RELEASE_REPO_ROOT/node_modules" -prune -o \
        -path "$RELEASE_BUILD_ROOT" -prune -o \
        -type f \
        \( -name '.env' -o -name '.env.*' -o -name '*.pem' \
           -o -name '*.p12' -o -name '*.mobileprovision' \) \
        -print0
)

if ((failures > 0)); then
    release_die "$failures secret/privacy source finding(s)"
fi

printf 'PASS: no credentials or private configuration in release sources.\n'
