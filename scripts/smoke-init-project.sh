#!/usr/bin/env bash
set -euo pipefail

die() {
    printf 'Smoke assertion failed: %s\n' "$*" >&2
    exit 1
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
root=$(cd "$script_dir/.." && pwd -P)
initializer="$script_dir/init-project.sh"
smoke_path="$root/temp/smoke-init-${RANDOM}-${RANDOM}"
occupied_path="$root/temp/smoke-occupied-${RANDOM}-${RANDOM}"
missing_existing_path="$root/temp/smoke-missing-existing-${RANDOM}-${RANDOM}"
invalid_target="$root/temp/smoke-target-file-${RANDOM}-${RANDOM}"
keep_artifacts=false

if [[ "${1:-}" == "--keep-artifacts" ]]; then
    keep_artifacts=true
    shift
fi

[[ $# -eq 0 ]] || die "Unknown option: $1"

cleanup() {
    rm -f "$invalid_target"
    if [[ "$keep_artifacts" != true ]]; then
        rm -rf "$smoke_path"
        rm -rf "$occupied_path"
        rm -rf "$missing_existing_path"
    fi
}
trap cleanup EXIT

bash "$initializer" --target "$smoke_path" --name "AWZ Init Smoke" --dry-run
[[ ! -e "$smoke_path" ]] || die 'DryRun created the target directory'

bash "$initializer" --target "$smoke_path" --name "AWZ Init Smoke"
[[ -d "$smoke_path/.git" ]] || die 'Git repository was not initialized'
[[ "$(git -C "$smoke_path" symbolic-ref --short HEAD)" == 'main' ]] || die 'Git branch is not main'

for path in AGENTS.md CLAUDE.md docs temp .env; do
    git -C "$smoke_path" check-ignore -q -- "$path" || die "$path should be ignored"
done

if git -C "$smoke_path" check-ignore -q -- .env.example; then
    die '.env.example must remain trackable'
fi

printf '%s\n' 'custom local README' > "$smoke_path/README.md"
if bash "$initializer" --target "$smoke_path"; then
    die 'New mode accepted a non-empty initialized target'
fi
[[ "$(<"$smoke_path/README.md")" == 'custom local README' ]] || die 'Existing README was overwritten without --force'

bash "$initializer" --target "$smoke_path" --mode existing
[[ "$(<"$smoke_path/README.md")" == 'custom local README' ]] || die 'Existing mode overwrote README without --force'

printf '%s\n' 'custom local AGENTS' > "$smoke_path/AGENTS.md"
bash "$initializer" --target "$smoke_path" --mode existing --force
[[ "$(<"$smoke_path/README.md")" == 'custom local README' ]] || die '--force overwrote a protected project README'
if grep -Fq 'custom local AGENTS' "$smoke_path/AGENTS.md"; then
    die '--force did not refresh AWZ-managed AGENTS.md'
fi

mkdir -p "$occupied_path"
printf '%s\n' 'preserve me' > "$occupied_path/valuable.txt"
if bash "$initializer" --target "$occupied_path" --name 'Must Not Merge' --dry-run; then
    die 'New mode did not reject a pre-existing non-empty directory'
fi
[[ ! -e "$occupied_path/README.md" ]] || die 'Rejected target was modified'

if bash "$initializer" --target "$occupied_path" --force --dry-run; then
    die '--force bypassed New mode safety'
fi

if bash "$initializer" --target "$missing_existing_path" --mode existing --dry-run; then
    die 'Existing mode accepted a missing directory'
fi

printf '%s\n' 'not a directory' > "$invalid_target"
if bash "$initializer" --target "$invalid_target" --dry-run; then
    die 'File target was not rejected'
fi

if bash "$initializer" --target "$root" --dry-run; then
    die 'AWZ Workflow source directory was not rejected'
fi

printf 'Init smoke passed: %s\n' "$smoke_path"
