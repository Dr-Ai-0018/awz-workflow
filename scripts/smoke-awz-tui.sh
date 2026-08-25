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
read_only_path="$root/temp/smoke-tui-readonly-${RANDOM}-${RANDOM}"
keep_artifacts=false

if [[ "${1:-}" == '--keep-artifacts' ]]; then
    keep_artifacts=true
    shift
fi
[[ $# -eq 0 ]] || die "Unknown option: $1"

cleanup() {
    if [[ "$keep_artifacts" != true ]]; then
        rm -rf "$dryrun_path" "$apply_path" "$occupied_path" "$read_only_path"
    fi
}
trap cleanup EXIT

bash "$tui" --help >/dev/null

menu_output=$(printf 'q\n' | bash "$tui")
for token in 'AWZ Workflow 控制中心' '1. 创建新项目' '2. 接入已有项目' '3. Reference Library' '4. 安全刷新检查' '5. Doctor'; do
    [[ "$menu_output" == *"$token"* ]] || die "Control center menu is missing: $token"
done

bash "$tui" --action init --target "$dryrun_path" --name 'AWZ TUI DryRun' --dry-run-only
[[ ! -e "$dryrun_path" ]] || die 'DryRunOnly created the target'

bash "$tui" --action init --target "$apply_path" --name 'AWZ TUI Apply' --yes
[[ -d "$apply_path/.git" ]] || die 'TUI apply did not initialize Git'
[[ -f "$apply_path/README.md" ]] || die 'TUI apply did not write README'

mkdir -p "$read_only_path/config" "$read_only_path/references"
reference_output=$(
    printf '3\nb\nq\n' |
        AWZ_CONFIG_DIR="$read_only_path/config" AWZ_REFERENCE_ROOT="$read_only_path/references" bash "$tui"
)
[[ "$reference_output" == *'Reference Library'* ]] || die 'Reference Library view did not open'
[[ "$reference_output" == *'尚未登记 reference'* ]] || die 'Reference Library did not use the isolated structured result'

doctor_output=$(
    printf '5\nb\nq\n' |
        AWZ_CONFIG_DIR="$read_only_path/config" AWZ_REFERENCE_ROOT="$read_only_path/references" bash "$tui"
)
[[ "$doctor_output" == *'AWZ Doctor'* ]] || die 'Doctor view did not open'
[[ "$doctor_output" == *"$read_only_path/references"* ]] || die 'Doctor escaped the isolated reference root'

refresh_output=$(printf '4\n%s\nb\nq\n' "$apply_path" | bash "$tui")
[[ "$refresh_output" == *'安全刷新检查结果'* ]] || die 'Safe refresh view did not open'
[[ "$refresh_output" == *'本页不会 apply'* ]] || die 'Safe refresh view did not preserve DryRun-only semantics'
[[ ! -e "$apply_path/docs/agent-room/.awz-manifest.json" ]] || die 'Safe refresh view wrote a manifest'

mkdir -p "$occupied_path"
printf '%s\n' 'preserve me' > "$occupied_path/valuable.txt"
if bash "$tui" --action init --target "$occupied_path" --name 'Must Not Merge' --dry-run-only; then
    die 'TUI accepted an occupied target in new mode'
fi
[[ ! -e "$occupied_path/README.md" ]] || die 'Rejected TUI target was modified'

printf '%s\n' 'AWZ TUI smoke passed'
