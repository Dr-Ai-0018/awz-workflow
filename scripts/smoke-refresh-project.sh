#!/usr/bin/env bash
set -euo pipefail

die() {
    printf 'Refresh smoke assertion failed: %s\n' "$*" >&2
    exit 1
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
root=$(cd "$script_dir/.." && pwd -P)
initializer="$script_dir/init-project.sh"
refresh="$script_dir/refresh-project.sh"
smoke_root="$root/temp/smoke-refresh-${RANDOM}-${RANDOM}"
project="$smoke_root/project"
keep_artifacts=false

if command -v python3 >/dev/null 2>&1; then
    python_bin=python3
elif command -v python >/dev/null 2>&1; then
    python_bin=python
else
    die 'Python 3 is required for refresh smoke'
fi

if [[ "${1:-}" == '--keep-artifacts' ]]; then
    keep_artifacts=true
    shift
fi
[[ $# -eq 0 ]] || die "Unknown option: $1"

cleanup() {
    if [[ "$keep_artifacts" != true ]]; then
        rm -rf "$smoke_root"
    fi
}
trap cleanup EXIT

bash "$initializer" --target "$project" --name 'Refresh Smoke Project' >/dev/null

preview=$(bash "$refresh" --target "$project" --dry-run --json)
plan_hash=$($python_bin -c 'import json,sys; data=json.load(sys.stdin); assert data["operation"] == "project.refresh"; assert not data["plan"]["blockedBy"]; assert len(data["plan"]["changes"]) == 1; print(data["plan"]["planHash"])' <<< "$preview")

applied=$(bash "$refresh" --target "$project" --apply --plan-hash "$plan_hash" --json)
$python_bin -c 'import json,sys; data=json.load(sys.stdin); assert data["data"]["transaction"]["state"] == "completed"' <<< "$applied"
[[ -f "$project/docs/agent-room/.awz-manifest.json" ]] || die 'Refresh manifest was not written'

second=$(bash "$refresh" --target "$project" --dry-run --json)
$python_bin -c 'import json,sys; data=json.load(sys.stdin); assert not data["plan"]["changes"]' <<< "$second"

printf '%s\n' 'local project rule' >> "$project/AGENTS.md"
set +e
conflict=$(bash "$refresh" --target "$project" --dry-run --json)
conflict_code=$?
set -e
[[ $conflict_code -eq 2 ]] || die 'Local modification did not return the blocked exit code'
$python_bin -c 'import json,sys; data=json.load(sys.stdin); assert data["plan"]["blockedBy"]' <<< "$conflict"

printf 'AWZ refresh smoke passed: %s\n' "$smoke_root"
