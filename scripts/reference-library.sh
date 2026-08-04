#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
core="$script_dir/reference-library.py"

[[ -f "$core" ]] || {
    printf 'Error: Reference Library core not found: %s\n' "$core" >&2
    exit 1
}

if command -v python3 >/dev/null 2>&1; then
    exec python3 "$core" "$@"
fi
if command -v python >/dev/null 2>&1; then
    exec python "$core" "$@"
fi

printf '%s\n' 'Error: Python 3 is required for the optional Reference Library commands.' >&2
exit 1
