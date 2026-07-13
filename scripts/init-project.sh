#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  bash scripts/init-project.sh --target <path> [options]

Options:
  --target <path>   Target project directory. Required.
  --name <name>     Project name. Defaults to the target directory name.
  --owner <name>    MIT license owner. Defaults to AWZ Workflow contributors.
  --force           Overwrite generated files that already exist.
  --dry-run         Preview changes without writing files or initializing Git.
  -h, --help        Show this help message.
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
root=$(cd "$script_dir/.." && pwd -P)
template_root="$root/templates/project"

target_input=''
project_name=''
owner='AWZ Workflow contributors'
force=false
dry_run=false

while (($# > 0)); do
    case "$1" in
        --target)
            (($# >= 2)) || die '--target requires a path.'
            target_input=$2
            shift 2
            ;;
        --name)
            (($# >= 2)) || die '--name requires a value.'
            project_name=$2
            shift 2
            ;;
        --owner)
            (($# >= 2)) || die '--owner requires a value.'
            owner=$2
            shift 2
            ;;
        --force)
            force=true
            shift
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

[[ -n "$target_input" ]] || die '--target is required.'
[[ -d "$template_root" ]] || die "Template directory not found: $template_root"

if [[ -e "$target_input" && ! -d "$target_input" ]]; then
    die "Target path is not a directory: $target_input"
fi

if [[ -z "$project_name" ]]; then
    project_name=$(basename "${target_input%/}")
fi

target_needs_creation=false
if [[ -d "$target_input" ]]; then
    target_path=$(cd "$target_input" && pwd -P)
else
    target_path=$target_input
    target_needs_creation=true
    if [[ "$dry_run" == true ]]; then
        printf 'DryRun: target directory does not exist; would create %s\n' "$target_path"
    fi
fi

[[ "$target_path" != "$root" ]] || die "Target path cannot be the AWZ Workflow source directory: $root"

needs_git_init=false
if [[ ! -d "$target_path/.git" ]]; then
    needs_git_init=true
fi

if [[ "$needs_git_init" == true ]] && ! command -v git >/dev/null 2>&1; then
    if [[ "$dry_run" == true ]]; then
        printf '%s\n' 'DryRun: git is unavailable; real initialization would stop before writing files.'
    else
        die 'Git is required to initialize a new repository. Install Git, then run the initializer again.'
    fi
fi

if [[ "$target_needs_creation" == true && "$dry_run" != true ]]; then
    mkdir -p "$target_input"
    target_path=$(cd "$target_input" && pwd -P)
fi

current_year=$(date +%Y)

render_template() {
    local source=$1
    local content

    content=$(<"$source")
    content=${content//\{\{PROJECT_NAME\}\}/$project_name}
    content=${content//\{\{YEAR\}\}/$current_year}
    content=${content//\{\{OWNER\}\}/$owner}
    printf '%s\n' "$content"
}

write_generated_file() {
    local source_name=$1
    local dest_name=$2
    local render=$3
    local source="$template_root/$source_name"
    local dest="$target_path/$dest_name"

    [[ -f "$source" ]] || die "Template file not found: $source_name"

    if [[ -e "$dest" && "$force" != true ]]; then
        printf 'Skip existing file: %s\n' "$dest_name"
        return
    fi

    if [[ "$dry_run" == true ]]; then
        if [[ -e "$dest" && "$force" == true ]]; then
            printf 'DryRun: would overwrite %s\n' "$dest_name"
        else
            printf 'DryRun: would write %s\n' "$dest_name"
        fi
        return
    fi

    mkdir -p "$(dirname "$dest")"
    if [[ "$render" == true ]]; then
        render_template "$source" > "$dest"
    else
        cp "$source" "$dest"
    fi
    printf 'Wrote %s\n' "$dest_name"
}

ensure_local_directory() {
    local dir_name=$1
    local path="$target_path/$dir_name"

    [[ -d "$path" ]] && return

    if [[ "$dry_run" == true ]]; then
        printf 'DryRun: would create directory %s\n' "$dir_name"
        return
    fi

    mkdir -p "$path"
    printf 'Created directory %s\n' "$dir_name"
}

root_files=(
    'AGENTS.md|AGENTS.md|false'
    'CLAUDE.md|CLAUDE.md|false'
    'gitignore.template|.gitignore|false'
    'env.example|.env.example|false'
    'README.template.md|README.md|true'
    'LICENSE-MIT|LICENSE|true'
)

for file in "${root_files[@]}"; do
    IFS='|' read -r source dest render <<< "$file"
    write_generated_file "$source" "$dest" "$render"
done

local_dirs=(
    'docs'
    'docs/agent-room'
    'docs/agent-room/guides'
    'docs/agent-room/handoffs'
    'docs/agent-room/reviews'
    'docs/agent-room/decisions'
    'docs/agent-room/notes'
    'docs/plans'
    'temp'
    'temp/scripts'
    'temp/output'
    'temp/assets'
    'temp/screenshots'
    'temp/experiments'
    'temp/logs'
)

for dir in "${local_dirs[@]}"; do
    ensure_local_directory "$dir"
done

local_files=(
    'docs-layout.md|docs/README.md|false'
    'agent-onboarding.md|docs/agent-room/onboarding.md|false'
    'guides/collaboration.md|docs/agent-room/guides/collaboration.md|false'
    'guides/repository-hygiene.md|docs/agent-room/guides/repository-hygiene.md|false'
    'guides/git-workflow.md|docs/agent-room/guides/git-workflow.md|false'
    'guides/verification.md|docs/agent-room/guides/verification.md|false'
    'guides/code-architecture.md|docs/agent-room/guides/code-architecture.md|false'
    'guides/frontend.md|docs/agent-room/guides/frontend.md|false'
    'guides/blockers-and-safety.md|docs/agent-room/guides/blockers-and-safety.md|false'
    'guides/review.md|docs/agent-room/guides/review.md|false'
    'agent-status.template.md|docs/agent-room/status.md|true'
    'handoff.template.md|docs/agent-room/handoffs/handoff.template.md|false'
    'review-checklist.template.md|docs/agent-room/reviews/review-checklist.template.md|false'
    'decision-record.template.md|docs/agent-room/decisions/decision-record.template.md|false'
    'release-checklist.template.md|docs/plans/release-checklist.template.md|false'
    'temp-layout.md|temp/README.md|false'
)

for file in "${local_files[@]}"; do
    IFS='|' read -r source dest render <<< "$file"
    write_generated_file "$source" "$dest" "$render"
done

if [[ "$needs_git_init" == true ]]; then
    if [[ "$dry_run" == true ]]; then
        printf 'DryRun: would run git init -b main\n'
    else
        git -C "$target_path" init -b main >/dev/null
        printf 'Ran git init -b main\n'
    fi
fi

if [[ "$dry_run" == true ]]; then
    printf '%s\n' 'DryRun: will not generate pyproject.toml, package.json, Docker, CI, or deployment config unless a matching project type is chosen later.'
    printf 'DryRun: preview complete; no files were written: %s\n' "$target_path"
else
    printf 'AWZ project baseline initialized: %s\n' "$target_path"
fi
