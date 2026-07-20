#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
AWZ Workflow TUI

Interactive:
  bash scripts/awz.sh

Scriptable:
  bash scripts/awz.sh --action init --target <path> [options]

Options:
  --action init          Run project initialization.
  --target <path>        Target project directory.
  --name <name>          Project name. Defaults to the target directory name.
  --owner <name>         MIT license owner.
  --mode new|existing    Initialization mode. Defaults to new.
  --force                Refresh AWZ-managed files in existing mode.
  --dry-run-only         Stop after the mandatory preview.
  --yes                  Apply after preview without an interactive confirmation.
  -h, --help             Show this help message.
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

section() {
    printf '\n== %s ==\n' "$1"
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
initializer="$script_dir/init-project.sh"

action=''
target=''
project_name=''
owner='AWZ Workflow contributors'
mode=''
force=false
assume_yes=false
dry_run_only=false

while (($# > 0)); do
    case "$1" in
        --action)
            (($# >= 2)) || die '--action requires a value.'
            action=$2
            shift 2
            ;;
        --target)
            (($# >= 2)) || die '--target requires a path.'
            target=$2
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
        --mode)
            (($# >= 2)) || die '--mode requires new or existing.'
            mode=$2
            shift 2
            ;;
        --force)
            force=true
            shift
            ;;
        --yes)
            assume_yes=true
            shift
            ;;
        --dry-run-only)
            dry_run_only=true
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

[[ -f "$initializer" ]] || die "Initializer not found: $initializer"

interactive_menu=false
if [[ -z "$action" ]]; then
    interactive_menu=true
    printf '%s\n' 'AWZ Workflow'
    printf '%s\n\n' '安全初始化与项目接入'
    printf '%s\n' '  1. 创建新项目'
    printf '%s\n' '  2. 接入已有项目'
    printf '%s\n\n' '  Q. 退出'
    read -r -p '请选择: ' choice
    case "${choice,,}" in
        1)
            action='init'
            mode='new'
            ;;
        2)
            action='init'
            mode='existing'
            ;;
        q)
            printf '%s\n' '已退出。'
            exit 0
            ;;
        *)
            die "Unknown menu choice: $choice"
            ;;
    esac
fi

[[ "${action,,}" == 'init' ]] || die "Unsupported action: $action. Current TUI supports init only."
[[ -n "$mode" ]] || mode='new'
mode=${mode,,}
[[ "$mode" == 'new' || "$mode" == 'existing' ]] || die "Mode must be new or existing: $mode"

if [[ -z "$target" ]]; then
    read -r -p '目标目录: ' target
fi
[[ -n "$target" ]] || die 'Target path cannot be empty.'

if [[ -z "$project_name" ]]; then
    project_name=$(basename "${target%/}")
fi
[[ -n "$project_name" ]] || die "Cannot infer project name from target path: $target"

if [[ "$interactive_menu" == true && "$mode" == 'existing' && "$force" != true ]]; then
    printf '\n%s\n' '默认只补充缺失文件，不覆盖已有内容。'
    read -r -p '是否刷新 AWZ 管理的本地指导文件？[y/N] ' refresh_choice
    case "${refresh_choice,,}" in
        y|yes) force=true ;;
    esac
fi

init_args=(
    --target "$target"
    --name "$project_name"
    --owner "$owner"
    --mode "$mode"
)
[[ "$force" != true ]] || init_args+=(--force)

section '变更预览'
printf '目标：%s\n' "$target"
printf '项目：%s\n' "$project_name"
printf '模式：%s\n' "$mode"
printf '刷新 AWZ 文件：%s\n\n' "$force"

# The preview is mandatory. set -e prevents every apply path after a failed preview.
bash "$initializer" "${init_args[@]}" --dry-run

if [[ "$dry_run_only" == true ]]; then
    printf '\n%s\n' 'DryRunOnly：未写入任何文件。'
    exit 0
fi

confirmed=$assume_yes
if [[ "$confirmed" != true ]]; then
    section '执行确认'
    if [[ "$mode" == 'existing' && "$force" == true ]]; then
        printf '%s\n' '将刷新已有项目中的 AWZ 管理文件。项目自有根文件仍受保护。'
        read -r -p '输入 APPLY 继续: ' answer
        [[ "$answer" == 'APPLY' ]] && confirmed=true
    else
        read -r -p '确认执行？[y/N] ' answer
        case "${answer,,}" in
            y|yes) confirmed=true ;;
        esac
    fi
fi

if [[ "$confirmed" != true ]]; then
    printf '%s\n' '已取消，未执行写入。'
    exit 0
fi

section '执行初始化'
bash "$initializer" "${init_args[@]}"

section '完成'
printf '项目已处理：%s\n' "$target"
if [[ -d "$target/.git" ]]; then
    printf '\ngit status --short\n'
    git -C "$target" status --short
fi
