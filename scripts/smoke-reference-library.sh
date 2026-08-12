#!/usr/bin/env bash
set -euo pipefail

die() {
    printf 'Reference smoke assertion failed: %s\n' "$*" >&2
    exit 1
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
root=$(cd "$script_dir/.." && pwd -P)
reference_cli="$script_dir/reference-library.sh"
initializer="$script_dir/init-project.sh"
smoke_root="$root/temp/smoke-reference-${RANDOM}-${RANDOM}"
config_dir="$smoke_root/config"
library_root="$smoke_root/library"
fixture_repo="$smoke_root/fixture-repo"
project_path="$smoke_root/project"
keep_artifacts=false

if [[ "${1:-}" == '--keep-artifacts' ]]; then
    keep_artifacts=true
    shift
fi
[[ $# -eq 0 ]] || die "Unknown option: $1"

cleanup() {
    if [[ "$keep_artifacts" != true && -d "$smoke_root" ]]; then
        rm -rf "$smoke_root"
    fi
}
trap cleanup EXIT

export AWZ_CONFIG_DIR="$config_dir"
mkdir -p "$config_dir"
printf '%s\n' '{invalid-json' > "$config_dir/config.json"
if bash "$reference_cli" list >/dev/null 2>&1; then
    die 'invalid config JSON was accepted'
fi
printf '{"schemaVersion":1,"referenceRoot":"%s"}\n' "$smoke_root/missing-library" > "$config_dir/config.json"
if bash "$reference_cli" doctor >/dev/null 2>&1; then
    die 'doctor accepted a missing reference root'
fi
rm -rf "$config_dir"

mkdir -p "$fixture_repo"
git -C "$fixture_repo" init -b main >/dev/null
git -C "$fixture_repo" config user.name 'AWZ Smoke'
git -C "$fixture_repo" config user.email 'awz-smoke@example.invalid'
printf '%s\n' '# Fixture Reference' > "$fixture_repo/README.md"
printf '%s\n' 'MIT fixture' > "$fixture_repo/LICENSE"
printf '%s\n' '{"name":"fixture-reference","version":"1.2.3"}' > "$fixture_repo/package.json"
git -C "$fixture_repo" add README.md LICENSE package.json
git -C "$fixture_repo" commit -m fixture >/dev/null

bash "$reference_cli" configure --root "$library_root" --dry-run >/dev/null
[[ ! -e "$config_dir" ]] || die 'configure dry-run wrote config'
[[ ! -e "$library_root" ]] || die 'configure dry-run created library root'

bash "$reference_cli" configure --root "$library_root" >/dev/null
[[ -f "$config_dir/config.json" ]] || die 'configure did not write config'
configure_plan=$(bash "$reference_cli" configure --root "$library_root" --dry-run --json)
printf '%s\n' "$configure_plan" | grep -Fq '"operation": "reference.configure"' || die 'configure JSON operation is invalid'
configure_plan_hash=$(printf '%s\n' "$configure_plan" | sed -n 's/^[[:space:]]*"planHash": "\([^"]*\)".*/\1/p')
[[ -n "$configure_plan_hash" ]] || die 'configure JSON plan hash is missing'
printf '%s\n' "$configure_plan" | grep -Fq '"depth": 1' || die 'configure plan omitted validated depth'
changed_configure_plan=$(bash "$reference_cli" configure --root "$library_root" --depth 2 --dry-run --json)
changed_configure_plan_hash=$(printf '%s\n' "$changed_configure_plan" | sed -n 's/^[[:space:]]*"planHash": "\([^"]*\)".*/\1/p')
[[ "$changed_configure_plan_hash" != "$configure_plan_hash" ]] || die 'configure plan hash ignored changed inputs'
if bash "$reference_cli" configure --root "$library_root" --depth 2 --json --plan-hash "$configure_plan_hash" >/dev/null 2>&1; then
    die 'configure accepted a plan hash generated for different inputs'
fi
bash "$reference_cli" configure --root "$library_root" --json --plan-hash "$configure_plan_hash" >/dev/null
grep -Fq '"schemaVersion": 2' "$config_dir/config.json" || die 'configure did not write schema v2'
if bash "$reference_cli" configure --root "$library_root" --json >/dev/null 2>&1; then
    die 'JSON apply accepted a missing plan hash'
fi
for directory in catalog repos context-cache logs; do
    [[ -d "$library_root/$directory" ]] || die "missing library directory: $directory"
done

bash "$reference_cli" add --id fixture --name 'Fixture Reference' --url "$fixture_repo" \
    --category frontend --tag frontend,animation --read-first README.md \
    --use-when '需要 smoke reference' --canonical-url https://example.com/fixture.git --allow-local --dry-run >/dev/null
reference_repo="$library_root/repos/frontend/fixture"
[[ ! -e "$reference_repo" ]] || die 'add dry-run cloned repository'
if bash "$reference_cli" add --id local-without-allow --url "$fixture_repo" --dry-run >/dev/null 2>&1; then
    die 'local path was accepted without --allow-local'
fi
if bash "$reference_cli" add --id credential-url --url 'https://user:secret@example.com/repo.git' --dry-run > "$smoke_root/credential.log" 2>&1; then
    die 'credential-bearing URL was accepted'
fi
! grep -Fq secret "$smoke_root/credential.log" || die 'credential-bearing URL leaked in output'
if bash "$reference_cli" add --id credential-license --url "$fixture_repo" \
    --canonical-url https://example.com/credential-license.git --allow-local \
    --license-url 'https://user:license-secret@example.com/license' --dry-run > "$smoke_root/license-credential.log" 2>&1; then
    die 'credential-bearing license URL was accepted'
fi
! grep -Fq license-secret "$smoke_root/license-credential.log" || die 'credential-bearing license URL leaked in output'
if bash "$reference_cli" add --id escape --url "$fixture_repo" --category ../escape --allow-local --dry-run >/dev/null 2>&1; then
    die 'category traversal was accepted'
fi

bash "$reference_cli" add --id fixture --name 'Fixture Reference' --url "$fixture_repo" \
    --category frontend --tag frontend,animation --read-first README.md \
    --use-when '需要 smoke reference' --canonical-url https://example.com/fixture.git --allow-local >/dev/null
[[ -d "$reference_repo/.git" ]] || die 'reference repository was not cloned'
[[ -f "$library_root/catalog/fixture.json" ]] || die 'catalog was not written'
bash "$reference_cli" list | grep -Fq fixture || die 'list did not show fixture'
bash "$reference_cli" show --id fixture | grep -Fq '"version": "1.2.3"' || die 'show did not detect version'

broken_repo="$library_root/repos/broken"
mkdir -p "$broken_repo/.git"
printf '%s\n' '{"schemaVersion":2,"id":"broken","relativePath":"repos/broken","repositoryUrl":"https://example.com/broken.git","revision":"missing"}' > "$library_root/catalog/broken.json"
broken_status=$(bash "$reference_cli" status --json)
printf '%s\n' "$broken_status" | grep -A8 '"id": "broken"' | grep -Fq '"status": "invalid"' || die 'status treated a broken nested .git directory as the parent repository'
rm -rf "$broken_repo"
rm -f "$library_root/catalog/broken.json"

printf '%s\n' '{"schemaVersion":2,"id":"unsafe-catalog","relativePath":"repos/unsafe-catalog","repositoryUrl":"https://example.com/unsafe.git?token=catalog-secret","revision":"missing"}' > "$library_root/catalog/unsafe-catalog.json"
if bash "$reference_cli" show --id unsafe-catalog > "$smoke_root/unsafe-catalog.log" 2>&1; then
    die 'unsafe catalog URL was accepted'
fi
! grep -Fq catalog-secret "$smoke_root/unsafe-catalog.log" || die 'unsafe catalog URL leaked in output'
rm -f "$library_root/catalog/unsafe-catalog.json"

bash "$initializer" --target "$project_path" --name 'Reference Smoke Project' >/dev/null
mapping_path="$project_path/.awz/references.json"
[[ -f "$mapping_path" ]] || die 'initializer did not create project mapping'

bash "$reference_cli" map --project "$project_path" --id fixture --purpose smoke --dry-run >/dev/null
! grep -Fq fixture "$mapping_path" || die 'map dry-run changed mapping'
map_plan=$(bash "$reference_cli" map --project "$project_path" --id fixture --purpose smoke --dry-run --json)
changed_map_plan=$(bash "$reference_cli" map --project "$project_path" --id fixture --purpose changed --dry-run --json)
map_plan_hash=$(printf '%s\n' "$map_plan" | sed -n 's/^[[:space:]]*"planHash": "\([^"]*\)".*/\1/p')
changed_map_plan_hash=$(printf '%s\n' "$changed_map_plan" | sed -n 's/^[[:space:]]*"planHash": "\([^"]*\)".*/\1/p')
[[ "$map_plan_hash" != "$changed_map_plan_hash" ]] || die 'map plan hash ignored changed purpose'
bash "$reference_cli" map --project "$project_path" --id fixture --purpose smoke >/dev/null

printf '%s\n' '{"schemaVersion":2,"id":"required-missing","relativePath":"repos/missing/required-missing","repositoryUrl":"https://example.com/required-missing.git","revision":"missing"}' > "$library_root/catalog/required-missing.json"
bash "$reference_cli" map --project "$project_path" --id required-missing --required >/dev/null
if bash "$reference_cli" context --project "$project_path" --dry-run > "$smoke_root/required-context.log"; then
    die 'context accepted an unusable required reference'
fi
grep -Fq 'Status: missing' "$smoke_root/required-context.log" || die 'context did not report an unusable required reference'
bash "$reference_cli" unmap --project "$project_path" --id required-missing >/dev/null
rm -f "$library_root/catalog/required-missing.json"

bash "$reference_cli" context --project "$project_path" --dry-run >/dev/null
context_path="$project_path/docs/agent-room/reference-context.md"
[[ ! -e "$context_path" ]] || die 'context dry-run wrote output'
bash "$reference_cli" context --project "$project_path" >/dev/null
grep -Fq 'Fixture Reference' "$context_path" || die 'context did not include mapped reference'

bash "$reference_cli" status --project "$project_path" >/dev/null
bash "$reference_cli" doctor --project "$project_path" >/dev/null
printf '%s\n' dirty >> "$reference_repo/README.md"
if bash "$reference_cli" doctor --project "$project_path" > "$smoke_root/doctor-dirty.log"; then
    die 'doctor accepted dirty reference'
fi
grep -Fq dirty "$smoke_root/doctor-dirty.log" || die 'doctor did not report dirty reference'

bash "$reference_cli" unmap --project "$project_path" --id fixture >/dev/null
[[ -d "$reference_repo" ]] || die 'unmap deleted the global clone'
printf 'Reference Library smoke passed: %s\n' "$smoke_root"
