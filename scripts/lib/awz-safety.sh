#!/usr/bin/env bash

awz_assert_safe_removal_target() {
    local target=${1:-}
    local allowed_root=${2:-}
    local top_level_prefix=${3:-smoke-}
    local resolved_target
    local resolved_allowed
    local relative
    local top_level

    [[ -n "$target" ]] || {
        printf 'Refusing an empty filesystem path.\n' >&2
        return 1
    }
    [[ -n "$allowed_root" ]] || {
        printf 'Refusing an empty allowed root.\n' >&2
        return 1
    }
    [[ -d "$allowed_root" ]] || {
        printf 'Allowed root does not exist: %s\n' "$allowed_root" >&2
        return 1
    }
    [[ -d "$target" ]] || {
        printf 'Removal target is not an existing directory: %s\n' "$target" >&2
        return 1
    }

    resolved_allowed=$(cd -P -- "$allowed_root" && pwd -P) || return 1
    resolved_target=$(cd -P -- "$target" && pwd -P) || return 1

    [[ "$resolved_target" != / ]] || {
        printf 'Refusing to remove the filesystem root.\n' >&2
        return 1
    }
    [[ "$resolved_target" != "$resolved_allowed" ]] || {
        printf 'Refusing to remove the allowed root itself: %s\n' "$resolved_target" >&2
        return 1
    }
    case "$resolved_target" in
        "$resolved_allowed"/*) ;;
        *)
            printf 'Removal target is outside the allowed root: %s\n' "$resolved_target" >&2
            return 1
            ;;
    esac

    relative=${resolved_target#"$resolved_allowed"/}
    top_level=${relative%%/*}
    case "$top_level" in
        "$top_level_prefix"*) ;;
        *)
            printf 'Removal target is not inside a %s* directory: %s\n' "$top_level_prefix" "$resolved_target" >&2
            return 1
            ;;
    esac

    printf '%s\n' "$resolved_target"
}

awz_safe_remove_tree() {
    local target=${1:-}
    local allowed_root=${2:-}
    local top_level_prefix=${3:-smoke-}
    local resolved_target

    [[ -n "$target" ]] || {
        printf 'Refusing an empty filesystem path.\n' >&2
        return 1
    }
    [[ -e "$target" ]] || return 0
    resolved_target=$(awz_assert_safe_removal_target "$target" "$allowed_root" "$top_level_prefix") || return 1
    rm -rf -- "$resolved_target"
}
