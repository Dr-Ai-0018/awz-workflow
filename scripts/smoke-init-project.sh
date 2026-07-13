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
bash "$initializer" --target "$smoke_path"
[[ "$(<"$smoke_path/README.md")" == 'custom local README' ]] || die 'Existing README was overwritten without --force'

bash "$initializer" --target "$smoke_path" --force
if grep -Fq 'custom local README' "$smoke_path/README.md"; then
    die '--force did not overwrite README'
fi

printf '%s\n' 'not a directory' > "$invalid_target"
if bash "$initializer" --target "$invalid_target" --dry-run; then
    die 'File target was not rejected'
fi

if bash "$initializer" --target "$root" --dry-run; then
    die 'AWZ Workflow source directory was not rejected'
fi

printf 'Init smoke passed: %s\n' "$smoke_path"
