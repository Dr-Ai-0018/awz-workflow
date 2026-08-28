#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
AWZ Workflow Terminal Control Center

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

choose_python() {
    if command -v python3 >/dev/null 2>&1; then
        printf '%s\n' 'python3'
        return
    fi
    if command -v python >/dev/null 2>&1; then
        printf '%s\n' 'python'
        return
    fi
    die 'Python 3 is required for Reference Library and refresh views.'
}

capture_json() {
    if json_output=$("$@"); then
        json_status=0
    else
        json_status=$?
    fi
    [[ -n "$json_output" ]] || die "Structured command returned no JSON: $*"
}

print_json_error() {
    printf '%s' "$json_output" | "$python_cmd" -c '
import json, sys
data = json.load(sys.stdin)
blocked = data.get("blockedBy") or ["exit code {}".format(data.get("exitCode", "unknown"))]
for item in blocked:
    print("  ! {}".format(item))
'
}

wait_back_or_exit() {
    local choice
    while true; do
        read -r -p '输入 B 返回控制中心，Q 退出: ' choice
        case "${choice,,}" in
            b) return 0 ;;
            q) return 10 ;;
        esac
    done
}

reference_list_browser() {
    local -a reference_ids=()
    local choice index reference_id
    [[ -n "${python_cmd:-}" ]] || python_cmd=$(choose_python)
    while true; do
        capture_json bash "$reference_cli" list --json
        if ((json_status != 0)); then
            section 'Reference Library 不可用'
            print_json_error
            if wait_back_or_exit; then return 0; else return $?; fi
        fi

        mapfile -t reference_ids < <(
            printf '%s' "$json_output" | "$python_cmd" -c '
import json, sys
for item in json.load(sys.stdin)["data"]["references"]:
    print(item["id"])
'
        )
        section 'Reference Library'
        printf '%s' "$json_output" | "$python_cmd" -c '
import json, sys
data = json.load(sys.stdin)["data"]
print("Root: {}".format(data["referenceRoot"]))
references = data["references"]
if not references:
    print("尚未登记 reference。")
for index, item in enumerate(references, 1):
    state = item.get("state", {})
    print("  {}. {}  {}  version {}".format(index, item["id"], state.get("status", "unknown"), item.get("version", "unknown")))
'
        if ((${#reference_ids[@]} == 0)); then
            if wait_back_or_exit; then return 0; else return $?; fi
        fi
        printf '%s\n' '  B. 返回控制中心' '  Q. 退出'
        read -r -p '选择条目编号: ' choice
        case "${choice,,}" in
            b) return 0 ;;
            q) return 10 ;;
        esac
        [[ "$choice" =~ ^[0-9]+$ ]] || { printf '%s\n' '无法识别输入，请使用页面显示的编号。'; continue; }
        index=$((choice - 1))
        ((index >= 0 && index < ${#reference_ids[@]})) || { printf '%s\n' '编号超出当前列表范围。'; continue; }
        reference_id=${reference_ids[$index]}
        capture_json bash "$reference_cli" show --id "$reference_id" --json
        if ((json_status != 0)); then
            section 'Reference 详情不可用'
            print_json_error
        else
            section "Reference 详情：$reference_id"
            printf '%s' "$json_output" | "$python_cmd" -c '
import json, sys
reference = json.load(sys.stdin)["data"]["reference"]
state = reference.get("state", {})
rows = (
    ("ID", reference.get("id")),
    ("状态", state.get("status")),
    ("版本", reference.get("version")),
    ("分支", state.get("branch")),
    ("Revision", reference.get("revision")),
    ("License", reference.get("license")),
    ("Trust", reference.get("trust")),
    ("Path", state.get("path")),
    ("Remote", state.get("remote")),
    ("Issues", len(state.get("issues") or [])),
)
for label, value in rows:
    print("{:<10} {}".format(label, value or "-"))
'
        fi
        printf '%s\n' '本页只读；不会 fetch、update 或修改 catalog。'
        if wait_back_or_exit; then
            continue
        else
            return $?
        fi
    done
}

reference_mapping() {
    local project
    [[ -n "${python_cmd:-}" ]] || python_cmd=$(choose_python)
    section '项目 Reference mapping'
    printf '%s\n' '读取 .awz/references.json；本页只读，不会修改 mapping 或 context。'
    read -r -p '项目目录（B 返回，Q 退出）: ' project
    case "${project,,}" in
        b) return 0 ;;
        q) return 10 ;;
    esac
    [[ -n "$project" ]] || { printf '%s\n' '项目目录不能为空。'; return 0; }
    capture_json bash "$reference_cli" status --project "$project" --json
    section '项目 Reference mapping 结果'
    if ((json_status != 0 && json_status != 1)); then
        print_json_error
    else
        printf '%s' "$json_output" | "$python_cmd" -c '
import json, sys
result = json.load(sys.stdin)
data = result.get("data", {})
entries = data.get("projectMappingEntries") or []
unresolved = data.get("unresolved") or []
print("项目      {}".format(sys.argv[1]))
print("映射      {} · unresolved {}".format(len(entries), len(unresolved)))
if not entries:
    print("当前项目没有映射 Reference。")
for entry in entries:
    required = "required" if entry.get("required") else "optional"
    print("{}  {}  [{}]".format(str(entry.get("status", "unknown")).upper(), entry.get("id", "<invalid>"), required))
    if entry.get("purpose"):
        print("    用途：{}".format(entry["purpose"]))
    if entry.get("path"):
        print("    路径：{}".format(entry["path"]))
    for issue in (entry.get("issues") or [])[:1]:
        print("    ! {}".format(issue))
if unresolved:
    print("发现 unresolved mapping；本页不会自动修复。")
else:
    print("只读项目映射状态。")
' "$project"
    fi
    printf '%s\n' '本页只读；不会修改 mapping 或 context。'
    if wait_back_or_exit; then return 0; else return $?; fi
}

reference_configure() {
    local root depth choice plan_hash
    [[ -n "${python_cmd:-}" ]] || python_cmd=$(choose_python)
    section '配置 Reference root'
    read -r -p 'Reference root（B 返回，Q 退出）: ' root
    case "${root,,}" in
        b) return 0 ;;
        q) return 10 ;;
    esac
    [[ -n "$root" ]] || { printf '%s\n' 'Reference root 不能为空。'; return 0; }
    read -r -p '默认 clone depth [1]（B 返回，Q 退出）: ' depth
    case "${depth,,}" in
        b) return 0 ;;
        q) return 10 ;;
    esac
    depth=${depth:-1}
    [[ "$depth" =~ ^[0-9]+$ && "$depth" -ge 1 ]] || { printf '%s\n' 'clone depth 必须是大于等于 1 的整数。'; return 0; }
    capture_json bash "$reference_cli" configure --root "$root" --depth "$depth" --dry-run --json
    section '配置 Reference root · 预览'
    if ((json_status != 0)); then
        print_json_error
        if wait_back_or_exit; then return 0; else return $?; fi
    fi
    plan_hash=$(printf '%s' "$json_output" | "$python_cmd" -c 'import json,sys; print(json.load(sys.stdin)["plan"]["planHash"])')
    printf '%s' "$json_output" | "$python_cmd" -c '
import json, sys
data = json.load(sys.stdin)
plan = data.get("plan", {})
config = data.get("data", {}).get("config", {})
print("Root      {}".format(config.get("referenceRoot")))
print("Depth     {}".format(config.get("defaultCloneDepth")))
print("Plan      {}".format(plan.get("planHash")))
for change in plan.get("changes", []):
    print("  {}  {}".format(change.get("kind"), change.get("summary")))
print("输入 A 应用；B 返回；Q 退出。")
'
    while true; do
        read -r -p '输入 A 应用，B 返回或 Q 退出: ' choice
        case "${choice,,}" in
            b) return 0 ;;
            q) return 10 ;;
            a) break ;;
            *) printf '%s\n' '无法识别输入，请输入 A、B 或 Q。' ;;
        esac
    done
    capture_json bash "$reference_cli" configure --root "$root" --depth "$depth" --plan-hash "$plan_hash" --json
    section '配置 Reference root · 完成'
    if ((json_status != 0)); then
        print_json_error
    else
        printf '%s' "$json_output" | "$python_cmd" -c '
import json, sys
data = json.load(sys.stdin)
config = data.get("data", {}).get("config", {})
tx = data.get("data", {}).get("transaction", {})
print("Root         {}".format(config.get("referenceRoot")))
print("Transaction  {}".format(tx.get("path")))
print("状态         {}".format(tx.get("state")))
print("本次未 clone 或更新仓库。")
'
    fi
    if wait_back_or_exit; then return 0; else return $?; fi
}

reference_browser() {
    local choice status
    while true; do
        section 'Reference Library'
        printf '%s\n' \
            '  1. 浏览全局条目  查看列表、详情与本地仓库状态' \
            '  2. 查看项目 mapping  查看用途、required 与 unresolved 状态' \
            '  3. 配置 Reference root  DryRun 预览后按 planHash 应用' \
            '  B. 返回控制中心' \
            '  Q. 退出'
        read -r -p '请选择: ' choice
        case "${choice,,}" in
            1) if reference_list_browser; then status=0; else status=$?; fi; ((status == 10)) && return 10 ;;
            2) if reference_mapping; then status=0; else status=$?; fi; ((status == 10)) && return 10 ;;
            3) if reference_configure; then status=0; else status=$?; fi; ((status == 10)) && return 10 ;;
            b) return 0 ;;
            q) return 10 ;;
            *) printf '%s\n' '无法识别输入，请使用页面显示的编号。' ;;
        esac
    done
}

reference_doctor() {
    [[ -n "${python_cmd:-}" ]] || python_cmd=$(choose_python)
    capture_json bash "$reference_cli" doctor --json
    section 'AWZ Doctor'
    if ((json_status != 0 && json_status != 1)); then
        print_json_error
    else
        printf '%s' "$json_output" | "$python_cmd" -c '
import json, sys
result = json.load(sys.stdin)
data = result["data"]
references = data.get("references") or []
problems = [item for item in references if item.get("status") != "ok"]
print("配置       {}".format(data.get("configured")))
print("Root       {}".format(data.get("referenceRoot")))
print("Root 存在  {}".format(data.get("rootExists")))
print("Reference  {} · 问题 {}".format(len(references), len(problems)))
print("离线检查通过。" if result.get("exitCode") == 0 else "发现需要处理的问题；本页不会自动修复。")
for item in references[:10]:
    marker = "OK" if item.get("status") == "ok" else "!!"
    print("  {} {}  {}".format(marker, item.get("id"), item.get("status")))
    for issue in (item.get("issues") or [])[:2]:
        print("      {}".format(issue))
for warning in (result.get("warnings") or [])[:2]:
    print("  WARN {}".format(warning))
for blocker in (result.get("blockedBy") or [])[:2]:
    print("  BLOCK {}".format(blocker))
if problems:
    print("建议：检查上方问题后重新运行 Doctor；本页不会自动修复。")
'
    fi
    if wait_back_or_exit; then return 0; else return $?; fi
}

refresh_check() {
    local refresh_target
    [[ -n "${python_cmd:-}" ]] || python_cmd=$(choose_python)
    section '安全刷新检查'
    printf '%s\n' '只运行 DryRun，不会修改项目。'
    read -r -p '项目目录（B 返回，Q 退出）: ' refresh_target
    case "${refresh_target,,}" in
        b) return 0 ;;
        q) return 10 ;;
    esac
    [[ -n "$refresh_target" ]] || { printf '%s\n' '项目目录不能为空。'; return 0; }
    capture_json bash "$refresh_cli" --target "$refresh_target" --dry-run --json
    section '安全刷新检查结果'
    if ((json_status != 0 && json_status != 2)); then
        print_json_error
    else
        printf '%s' "$json_output" | "$python_cmd" -c '
import json, sys
result = json.load(sys.stdin)
files = result.get("data", {}).get("files") or []
count = lambda kind: sum(1 for item in files if item.get("classification") == kind)
print("目标      {}".format(result.get("data", {}).get("target")))
print("待更新    {}".format(count("create") + count("update")))
print("首次接管  {}".format(count("adopt")))
print("冲突      {}".format(count("conflict")))
print("Plan      {}".format(result.get("plan", {}).get("planHash")))
for item in [item for item in files if item.get("classification") != "unchanged"][:10]:
    print("  {}  {}".format(item.get("classification", "unknown").upper(), item.get("path")))
print("本页不会 apply。")
'
    fi
    if wait_back_or_exit; then return 0; else return $?; fi
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
initializer="$script_dir/init-project.sh"
reference_cli="$script_dir/reference-library.sh"
refresh_cli="$script_dir/refresh-project.sh"

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
    python_cmd=''
    while [[ -z "$action" ]]; do
        printf '%s\n' 'AWZ Workflow 控制中心'
        printf '%s\n\n' '项目初始化、参考库、刷新检查与离线诊断'
        printf '%s\n' '  1. 创建新项目       安全初始化空目录'
        printf '%s\n' '  2. 接入已有项目     保留项目自有文件'
        printf '%s\n' '  3. Reference Library  浏览参考条目与本地状态'
        printf '%s\n' '  4. 安全刷新检查     manifest DryRun，不执行写入'
        printf '%s\n' '  5. Doctor            离线诊断配置与 reference'
        printf '%s\n\n' '  Q. 退出'
        read -r -p '请选择: ' choice
        case "${choice,,}" in
            1)
                interactive_menu=true
                action='init'
                mode='new'
                ;;
            2)
                interactive_menu=true
                action='init'
                mode='existing'
                ;;
            3)
                if reference_browser; then
                    printf '\n'
                else
                    menu_status=$?
                    ((menu_status == 10)) && exit 0
                    exit "$menu_status"
                fi
                ;;
            4)
                if refresh_check; then
                    printf '\n'
                else
                    menu_status=$?
                    ((menu_status == 10)) && exit 0
                    exit "$menu_status"
                fi
                ;;
            5)
                if reference_doctor; then
                    printf '\n'
                else
                    menu_status=$?
                    ((menu_status == 10)) && exit 0
                    exit "$menu_status"
                fi
                ;;
            q)
                printf '%s\n' '已退出。'
                exit 0
                ;;
            *)
                printf '%s\n\n' '无法识别输入，请使用页面显示的编号。'
                ;;
        esac
    done
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
