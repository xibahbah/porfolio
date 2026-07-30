#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

release_require_macos
release_require_command hdiutil
release_require_command open

version="${APP_VERSION:-1.0.0}"
dmg_path="${1:-"$RELEASE_BUILD_ROOT/release/Portfolio-${version}-universal.dmg"}"
[[ -f "$dmg_path" ]] || release_die "DMG not found: $dmg_path"

mount_point="$(mktemp -d "$RELEASE_BUILD_ROOT/.test-mount.XXXXXX")"
test_root="$(mktemp -d "$RELEASE_BUILD_ROOT/.test-安装-Тест-Space.XXXXXX")"

cleanup_test() {
    release_cleanup_mount "$mount_point"
    [[ ! -e "$test_root" ]] || release_remove_build_path "$test_root"
}
trap cleanup_test EXIT

hdiutil attach -nobrowse -readonly -mountpoint "$mount_point" \
    "$dmg_path" >/dev/null
installed_app="$test_root/Applications 测试/Portfolio.app"
clean_user_home="$test_root/Clean User 用户"
result_path="$test_root/smoke-result.txt"
mkdir -p "$(dirname "$installed_app")" "$clean_user_home"
ditto --noqtn "$mount_point/Portfolio.app" "$installed_app"

run_smoke_test() {
    open -W -n \
        --env "CFFIXED_USER_HOME=$clean_user_home" \
        --env "PORTFOLIO_SMOKE_TEST=1" \
        --env "PORTFOLIO_TEST_RESULT=$result_path" \
        "$installed_app"
    [[ -f "$result_path" ]] ||
        release_die "packaged app did not write a smoke-test result"
    grep -F -q 'PASS:' "$result_path" ||
        release_die "packaged workflow smoke test failed"
}

run_smoke_test

application_support="$clean_user_home/Library/Application Support/com.datafolio.portfolio"
caches="$clean_user_home/Library/Caches/com.datafolio.portfolio"
logs="$clean_user_home/Library/Logs/com.datafolio.portfolio"
[[ -d "$application_support" ]] ||
    release_die "Application Support directory was not initialized"
[[ -d "$caches" ]] ||
    release_die "Caches directory was not initialized"
[[ -d "$logs" ]] ||
    release_die "Logs directory was not initialized"

if find "$clean_user_home" -type f \
    \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \
       -o -name '*.log' -o -iname '*history*' -o -iname '*cookie*' \
       -o -iname '*session*' \) -print -quit | grep -q .; then
    release_die "clean launch created forbidden state"
fi

first_result="$(cat "$result_path")"
run_smoke_test
second_result="$(cat "$result_path")"
[[ "$first_result" == PASS:* && "$second_result" == PASS:* ]] ||
    release_die "relaunch workflow test failed"

printf 'PASS: mounted DMG and copied app from a path with spaces, Chinese, and Cyrillic characters.\n'
printf 'PASS: clean first launch and relaunch completed all packaged workflow checks.\n'
printf 'PASS: fresh app-data directories contain no database, history, session, cookie, cache file, or log.\n'
printf '%s\n' "$second_result"
