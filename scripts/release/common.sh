#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

RELEASE_SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd -P
)"
RELEASE_REPO_ROOT="$(
    cd "$RELEASE_SCRIPT_DIR/../.."
    pwd -P
)"
RELEASE_BUILD_ROOT="$RELEASE_REPO_ROOT/build"

release_die() {
    printf 'release: %s\n' "$*" >&2
    exit 1
}

release_require_macos() {
    [[ "$(uname -s)" == "Darwin" ]] ||
        release_die "macOS is required."
}

release_require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        release_die "required command not found: $1"
}

release_assert_build_path() {
    local target="${1:-}"
    [[ -n "$target" ]] || release_die "empty build path"
    case "$target" in
        "$RELEASE_BUILD_ROOT" | "$RELEASE_BUILD_ROOT"/*) ;;
        *) release_die "refusing non-build path: $target" ;;
    esac
    [[ "$target" != "/" ]] || release_die "refusing root path"
}

release_remove_build_path() {
    local target="$1"
    release_assert_build_path "$target"
    if [[ -e "$target" ]]; then
        find "$target" -depth -delete
    fi
}

release_reset_directory() {
    local target="$1"
    release_remove_build_path "$target"
    mkdir -p "$target"
}

release_cleanup_mount() {
    local mount_point="${1:-}"
    if [[ -n "$mount_point" ]] && mount | grep -Fq "on $mount_point "; then
        hdiutil detach "$mount_point" -quiet || true
    fi
    if [[ -n "$mount_point" ]] && [[ -e "$mount_point" ]]; then
        release_remove_build_path "$mount_point"
    fi
}
