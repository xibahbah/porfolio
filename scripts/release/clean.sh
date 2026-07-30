#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

release_remove_build_path "$RELEASE_BUILD_ROOT"
printf 'Removed generated release output: %s\n' "$RELEASE_BUILD_ROOT"
