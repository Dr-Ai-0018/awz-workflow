#!/usr/bin/env bash
set -euo pipefail

die() {
    printf 'TUI smoke assertion failed: %s\n' "$*" >&2
    exit 1
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
root=$(cd "$script_dir/.." && pwd -P)
tui="$script_dir/awz.sh"
dryrun_path="$root/temp/smoke-tui-dryrun-${RANDOM}-${RANDOM}"
apply_path="$root/temp/smoke-tui-apply-${RANDOM}-${RANDOM}"
occupied_path="$root/temp/smoke-tui-occupied-${RANDOM}-${RANDOM}"
keep_artifacts=false

if [[ "${1:-}" == '--keep-artifacts' ]]; then
    keep_artifacts=true
    shift
fi
[[ $# -eq 0 ]] || die "Unknown option: $1"

cleanup() {
    if [[ "$keep_artifacts" != true ]]; then
        rm -rf "$dryrun_path" "$apply_path" "$occupied_path"
    fi
}
trap cleanup EXIT

bash "$tui" --help >/dev/null

bash "$tui" --action init --target "$dryrun_path" --name 'AWZ TUI DryRun' --dry-run-only
[[ ! -e "$dryrun_path" ]] || die 'DryRunOnly created the target'

bash "$tui" --action init --target "$apply_path" --name 'AWZ TUI Apply' --yes
[[ -d "$apply_path/.git" ]] || die 'TUI apply did not initialize Git'
[[ -f "$apply_path/README.md" ]] || die 'TUI apply did not write README'

mkdir -p "$occupied_path"
printf '%s\n' 'preserve me' > "$occupied_path/valuable.txt"
if bash "$tui" --action init --target "$occupied_path" --name 'Must Not Merge' --dry-run-only; then
    die 'TUI accepted an occupied target in new mode'
fi
[[ ! -e "$occupied_path/README.md" ]] || die 'Rejected TUI target was modified'

printf '%s\n' 'AWZ TUI smoke passed'
