#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

app_path="${1:-}"
[[ -d "$app_path/Contents" ]] ||
    release_die "usage: privacy-scan.sh /path/to/Application.app"

failures=0

privacy_fail() {
    printf 'FAIL %s: %s\n' "$1" "$2" >&2
    failures=$((failures + 1))
}

identity_is_allowed() {
    case "$1" in
        Contents/Info.plist | \
        Contents/Resources/Web/index.html | \
        Contents/Resources/Web/contact/index.html | \
        Contents/Resources/Web/projects/index.html | \
        Contents/Resources/Web/resume/index.html | \
        Contents/Resources/Web/lib/projects.js | \
        Contents/Resources/Web/images/projects/portfolio.svg)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

scan_stream_for_fixed_value() {
    local file="$1"
    local value="$2"
    [[ -n "$value" ]] || return 1
    strings -a "$file" | LC_ALL=C grep -F -i -q "$value"
}

current_user="$(id -un 2>/dev/null || true)"
current_home="$(
    dscl . -read "/Users/$current_user" NFSHomeDirectory 2>/dev/null |
        awk '{print $2}' || true
)"
computer_name="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
public_email='xikeith0901@gmail.com'
email_pattern='[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}'
secret_pattern='(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[0-9A-Za-z_-]{30,}|sk-[A-Za-z0-9_-]{20,}|-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----)'

while IFS= read -r -d '' file; do
    relative_path="${file#"$app_path/"}"
    lower_path="$(printf '%s' "$relative_path" | tr '[:upper:]' '[:lower:]')"
    base_name="${lower_path##*/}"

    case "$lower_path" in
        */.git/* | .git/* | */node_modules/* | node_modules/* | \
        */.env | */.env.* | .env | .env.* | \
        *.db | *.db-* | *.sqlite | *.sqlite-* | *.sqlite3 | *.sqlite3-* | \
        *.log | *.map | *.dSYM/* | \
        *cookies* | *session* | *localstorage* | *indexeddb* | \
        *history* | *recent-files* | *crash-report* | \
        */cache/* | */caches/* | */thumbnails/* | */previews/*)
            privacy_fail "forbidden filename" "$relative_path"
            ;;
    esac

    if [[ "$base_name" == ".ds_store" ]] ||
        [[ "$base_name" == *" alias" ]] ||
        [[ "$base_name" == *.alias ]]; then
        privacy_fail "machine-local metadata" "$relative_path"
    fi

    if strings -a "$file" | LC_ALL=C grep -F -q '/Users/'; then
        privacy_fail "absolute macOS user path" "$relative_path"
    fi

    if [[ -n "$current_home" ]] &&
        scan_stream_for_fixed_value "$file" "$current_home"; then
        privacy_fail "current home directory" "$relative_path"
    fi

    if [[ -n "$computer_name" ]] &&
        scan_stream_for_fixed_value "$file" "$computer_name"; then
        privacy_fail "current computer name" "$relative_path"
    fi

    if [[ ${#current_user} -ge 4 ]] &&
        scan_stream_for_fixed_value "$file" "$current_user" &&
        ! identity_is_allowed "$relative_path"; then
        privacy_fail "current macOS username" "$relative_path"
    fi

    if strings -a "$file" | LC_ALL=C grep -E -i -q "$secret_pattern"; then
        privacy_fail "secret-like value" "$relative_path"
    fi

    if strings -a "$file" |
        LC_ALL=C grep -E -i -q \
            '(https?://(localhost|127\.0\.0\.1|0\.0\.0\.0)|file:///Users/)'; then
        privacy_fail "development URL" "$relative_path"
    fi

    while IFS= read -r email; do
        [[ -n "$email" ]] || continue
        if identity_is_allowed "$relative_path" &&
            [[ "$(printf '%s' "$email" | tr '[:upper:]' '[:lower:]')" == \
                "$public_email" ]]; then
            continue
        fi
        privacy_fail "unapproved email address" "$relative_path"
    done < <(
        strings -a "$file" |
            LC_ALL=C grep -E -i -o "$email_pattern" |
            LC_ALL=C sort -u || true
    )
done < <(find "$app_path" -type f -print0)

if find "$app_path" -type l -print -quit | grep -q .; then
    while IFS= read -r -d '' link; do
        privacy_fail "symlink inside application bundle" \
            "${link#"$app_path/"}"
    done < <(find "$app_path" -type l -print0)
fi

if ((failures > 0)); then
    release_die "$failures release privacy finding(s)"
fi

printf 'PASS: release bundle contains no forbidden personal/runtime data.\n'
printf 'PASS: no user paths, machine name, secrets, databases, histories, sessions, caches, logs, .env files, or development URLs.\n'
printf 'PASS: reviewed public portfolio identity appears only in approved product-content files.\n'
