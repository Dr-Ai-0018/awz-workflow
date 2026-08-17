#!/usr/bin/env bash
set -euo pipefail

die() {
    printf 'Smoke assertion failed: %s\n' "$*" >&2
    exit 1
}

assert_single_trailing_line_break() {
    local path=$1
    local ending

    ending=$(tail -c 2 "$path" | od -An -t x1 | tr -d ' \n')
    [[ "$ending" == *0a ]] || die "$path does not end with a line break"
    [[ "$ending" != '0a0a' ]] || die "$path ends with an extra blank line"
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

bash "$initializer" --target "$smoke_path" --name "Init Smoke Project" --dry-run
[[ ! -e "$smoke_path" ]] || die 'DryRun created the target directory'

bash "$initializer" --target "$smoke_path" --name "Init Smoke Project"
[[ -d "$smoke_path/.git" ]] || die 'Git repository was not initialized'
[[ "$(git -C "$smoke_path" symbolic-ref --short HEAD)" == 'main' ]] || die 'Git branch is not main'

for path in AGENTS.md CLAUDE.md docs docs/references/README.md docs/agent-room/room-ledger.py docs/agent-room/guides/room-ledger.md docs/agent-room/guides/file-search.md docs/agent-room/guides/frontend.md docs/agent-room/guides/frontend/visual-composition.md docs/agent-room/guides/frontend/motion-and-interaction.md docs/agent-room/guides/frontend/responsive-and-verification.md temp .env; do
    git -C "$smoke_path" check-ignore -q -- "$path" || die "$path should be ignored"
done

grep -Fq 'docs/references/README.md' "$smoke_path/AGENTS.md" || die 'AGENTS.md does not expose the reference index entry'
status_line=$(grep -n -m1 'docs/agent-room/status.md' "$smoke_path/AGENTS.md" | cut -d: -f1)
references_line=$(grep -n -m1 'docs/references/README.md' "$smoke_path/AGENTS.md" | cut -d: -f1)
[[ "$status_line" -lt "$references_line" ]] || die 'AGENTS.md does not route through status before optional references'
grep -Fq '# Init Smoke Project' "$smoke_path/README.md" || die 'README.md did not render the project name'
grep -Fq '项目简介 / Overview' "$smoke_path/README.md" || die 'README.md is missing the bilingual placeholder structure'
if grep -Fq 'AWZ' "$smoke_path/README.md"; then
    die 'README.md exposes the initializer identity'
fi
if grep -Fq '.awz/' "$smoke_path/README.md"; then
    die 'README.md exposes internal reference mapping'
fi
grep -Fq '开发环境基线' "$smoke_path/docs/references/README.md" || die 'reference index is missing the development environment baseline'
grep -Fq 'guides/verification.md' "$smoke_path/docs/references/README.md" || die 'reference index is missing the cold verification pointer'
grep -Fq 'executable/version' "$smoke_path/docs/agent-room/guides/verification.md" || die 'verification guide is missing shell environment details'
grep -Fq '项目构建启动顺序' "$smoke_path/docs/agent-room/onboarding.md" || die 'onboarding is missing the probe-before-build route'
grep -Fq '主线与插入请求' "$smoke_path/docs/agent-room/onboarding.md" || die 'onboarding is missing mainline continuity rules'
grep -Fq '主 Checklist' "$smoke_path/docs/agent-room/status.md" || die 'status is missing the primary checklist pointer'
if grep -Fq -- '- [ ]' "$smoke_path/docs/agent-room/status.md"; then
    die 'status contains a competing embedded checklist'
fi
for path in README.md LICENSE docs/agent-room/status.md; do
    assert_single_trailing_line_break "$smoke_path/$path"
done
for mode_label in '单 Agent' '双 Agent' '三 Agent' '四个及以上 Agent'; do
    grep -Fq "$mode_label" "$smoke_path/docs/agent-room/guides/collaboration.md" || die "collaboration strategy is missing mode: $mode_label"
done

if git -C "$smoke_path" check-ignore -q -- .env.example; then
    die '.env.example must remain trackable'
fi
[[ -f "$smoke_path/.awz/references.json" ]] || die '.awz/references.json was not generated'
if git -C "$smoke_path" check-ignore -q -- .awz/references.json; then
    die '.awz/references.json must remain trackable'
fi

printf '%s\n' 'custom local README' > "$smoke_path/README.md"
if bash "$initializer" --target "$smoke_path"; then
    die 'New mode accepted a non-empty initialized target'
fi
[[ "$(<"$smoke_path/README.md")" == 'custom local README' ]] || die 'Existing README was overwritten without --force'

bash "$initializer" --target "$smoke_path" --mode existing
[[ "$(<"$smoke_path/README.md")" == 'custom local README' ]] || die 'Existing mode overwrote README without --force'

printf '%s\n' 'custom local AGENTS' > "$smoke_path/AGENTS.md"
printf '%s\n' '{"schemaVersion":1,"references":[{"id":"custom"}]}' > "$smoke_path/.awz/references.json"
printf '%s\n' 'custom project context' > "$smoke_path/docs/references/README.md"
printf '%s\n' 'custom project status' > "$smoke_path/docs/agent-room/status.md"
printf '%s\n' 'custom collaboration strategy' > "$smoke_path/docs/agent-room/guides/collaboration.md"
printf '%s\n' 'custom frontend profile' > "$smoke_path/docs/agent-room/guides/frontend.md"
bash "$initializer" --target "$smoke_path" --mode existing --force
[[ "$(<"$smoke_path/README.md")" == 'custom local README' ]] || die '--force overwrote a protected project README'
if grep -Fq 'custom local AGENTS' "$smoke_path/AGENTS.md"; then
    die '--force did not refresh AWZ-managed AGENTS.md'
fi
grep -Fq '"id":"custom"' "$smoke_path/.awz/references.json" || die '--force overwrote project-owned .awz/references.json'
grep -Fq 'custom project context' "$smoke_path/docs/references/README.md" || die '--force overwrote project-owned docs/references/README.md'
grep -Fq 'custom project status' "$smoke_path/docs/agent-room/status.md" || die '--force overwrote project-owned status.md'
grep -Fq 'custom collaboration strategy' "$smoke_path/docs/agent-room/guides/collaboration.md" || die '--force overwrote project-owned collaboration strategy'
grep -Fq 'custom frontend profile' "$smoke_path/docs/agent-room/guides/frontend.md" || die '--force overwrote project-owned frontend profile'

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
