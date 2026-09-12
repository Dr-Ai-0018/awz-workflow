#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
root=$(cd "$script_dir/.." && pwd -P)
temp_root="$root/temp"
fixture="$temp_root/smoke-safety-${RANDOM}-${RANDOM}"
outside="$root/not-smoke-safety-${RANDOM}-${RANDOM}"
wrong_identity="$temp_root/safety-fixture-${RANDOM}-${RANDOM}"

. "$script_dir/lib/awz-safety.sh"

assert_rejected() {
    local target=$1
    local message=$2

    if awz_assert_safe_removal_target "$target" "$temp_root" >/dev/null 2>&1; then
        printf 'Safety smoke assertion failed: %s\n' "$message" >&2
        exit 1
    fi
}

mkdir -p "$fixture" "$outside" "$wrong_identity"
cleanup() {
    if [[ -d "$fixture" ]]; then
        awz_safe_remove_tree "$fixture" "$temp_root"
    fi
    rmdir "$outside" 2>/dev/null || true
    rmdir "$wrong_identity" 2>/dev/null || true
}
trap cleanup EXIT

assert_rejected '' 'empty path was accepted'
assert_rejected / 'filesystem root was accepted'
assert_rejected "$root" 'repository root was accepted'
assert_rejected "$temp_root" 'temp root was accepted'
assert_rejected "$outside" 'outside path was accepted'
assert_rejected "$wrong_identity" 'wrong directory identity was accepted'
assert_rejected "$fixture/../../not-smoke-safety" 'path traversal was accepted'
assert_rejected "${HOME:-/}" 'user home was accepted'

if awz_safe_remove_tree '' "$temp_root" >/dev/null 2>&1; then
    printf 'Safety smoke assertion failed: empty removal was silently accepted\n' >&2
    exit 1
fi

[[ "$(awz_assert_safe_removal_target "$fixture" "$temp_root")" == "$fixture" ]] || {
    printf 'Safety smoke assertion failed: valid fixture resolved unexpectedly\n' >&2
    exit 1
}
awz_safe_remove_tree "$fixture" "$temp_root"
[[ ! -e "$fixture" ]] || {
    printf 'Safety smoke assertion failed: valid fixture was not removed\n' >&2
    exit 1
}

printf 'Safety smoke passed\n'
