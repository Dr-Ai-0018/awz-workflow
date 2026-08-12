#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  bash scripts/package-release.sh [options]

Options:
  --output-dir <path>  Directory for the .tar.gz package. Defaults to dist.
  --allow-dirty        Allow packaging from a dirty worktree for local smoke tests.
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

[[ -f "$root/VERSION" ]] || die 'VERSION is missing.'
[[ -f "$root/CHANGELOG.md" ]] || die 'CHANGELOG.md is missing.'
command -v git >/dev/null 2>&1 || die 'Git is required to validate the release worktree.'
command -v tar >/dev/null 2>&1 || die 'tar is required to create the release package.'

version=$(tr -d '\r\n' < "$root/VERSION")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]] || die "Invalid VERSION: $version"

if [[ "$allow_dirty" != true ]] && [[ -n "$(git -C "$root" status --porcelain)" ]]; then
    die 'Worktree is dirty. Commit or stash changes before packaging, or use --allow-dirty only for a local smoke test.'
fi

mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd -P)
release_dir="awz-workflow-v$version"
package_path="$output_dir/$release_dir.tar.gz"

[[ ! -e "$package_path" ]] || die "Package already exists: $package_path"

mkdir -p "$root/temp"
stage_parent=$(mktemp -d "$root/temp/release-stage.XXXXXX")
trap 'rm -rf "$stage_parent"' EXIT
stage_root="$stage_parent/$release_dir"
mkdir -p "$stage_root"

for path in VERSION CHANGELOG.md LICENSE README.md requirements style workflows templates scripts; do
    [[ -e "$root/$path" ]] || die "Release source is missing: $path"
    cp -R "$root/$path" "$stage_root/$path"
done

find "$stage_root" -type d -name __pycache__ -prune -exec rm -rf -- {} +
find "$stage_root" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

tar -C "$stage_parent" -czf "$package_path" "$release_dir"
printf 'Created release package: %s\n' "$package_path"
