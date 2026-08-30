#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  bash scripts/package-release.sh [options]

Options:
  --output-dir <path>  Directory for the .tar.gz package. Defaults to dist.
  --allow-dirty        Allow packaging committed HEAD from a dirty worktree; dirty changes are excluded.
  -h, --help           Show this help message.
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
root=$(cd "$script_dir/.." && pwd -P)
output_dir="$root/dist"
allow_dirty=false

while (($# > 0)); do
    case "$1" in
        --output-dir)
            (($# >= 2)) || die '--output-dir requires a path.'
            output_dir=$2
            shift 2
            ;;
        --allow-dirty)
            allow_dirty=true
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

command -v git >/dev/null 2>&1 || die 'Git is required to validate the release worktree.'

version=$(git -C "$root" show HEAD:VERSION | tr -d '\r\n') || die 'VERSION is missing from HEAD.'
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]] || die "Invalid VERSION in HEAD: $version"

if [[ "$allow_dirty" != true ]] && [[ -n "$(git -C "$root" status --porcelain)" ]]; then
    die 'Worktree is dirty. Commit or stash changes before packaging, or use --allow-dirty only for a local smoke test.'
fi

mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd -P)
release_dir="awz-workflow-v$version"
package_path="$output_dir/$release_dir.tar.gz"

[[ ! -e "$package_path" ]] || die "Package already exists: $package_path"

release_paths=(VERSION CHANGELOG.md LICENSE README.md requirements style workflows templates scripts)
for path in "${release_paths[@]}"; do
    git -C "$root" cat-file -e "HEAD:$path" || die "Release source is missing from HEAD: $path"
done

if ! git -C "$root" archive \
    --format=tar.gz \
    --prefix="$release_dir/" \
    --output="$package_path" \
    HEAD -- "${release_paths[@]}"; then
    rm -f -- "$package_path"
    die 'git archive failed.'
fi

printf 'Created release package from committed HEAD: %s\n' "$package_path"
