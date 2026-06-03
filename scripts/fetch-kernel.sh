#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="${VERTEX_KERNEL_DIR:-$ROOT_DIR/src/kernel}"
KERNEL_REPO="${VERTEX_KERNEL_REPO:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}"
KERNEL_REF="${VERTEX_KERNEL_REF:-linux-6.6.y}"
KERNEL_DEPTH="${VERTEX_KERNEL_DEPTH:-1}"
FULL_CLONE="${VERTEX_KERNEL_FULL_CLONE:-0}"

info() {
    printf '\033[1;36m[vertex-kernel]\033[0m %s\n' "$*"
}

die() {
    printf '\033[1;31m[vertex-kernel]\033[0m %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

clone_kernel() {
    mkdir -p "$(dirname "$KERNEL_DIR")"

    local clone_args=(
        clone
        --branch "$KERNEL_REF"
        --single-branch
    )

    if [ "$FULL_CLONE" != "1" ]; then
        clone_args+=(--depth "$KERNEL_DEPTH")
    fi

    clone_args+=("$KERNEL_REPO" "$KERNEL_DIR")

    info "Cloning Linux LTS source: $KERNEL_REF"
    git "${clone_args[@]}"
}

update_kernel() {
    info "Kernel source already exists at $KERNEL_DIR"

    if ! git -C "$KERNEL_DIR" diff --quiet || ! git -C "$KERNEL_DIR" diff --cached --quiet; then
        die "Kernel tree has local changes. Commit, stash, or clean src/kernel before updating."
    fi

    git -C "$KERNEL_DIR" fetch origin "$KERNEL_REF" --tags

    if git -C "$KERNEL_DIR" rev-parse --verify --quiet "refs/remotes/origin/$KERNEL_REF" >/dev/null; then
        if git -C "$KERNEL_DIR" rev-parse --verify --quiet "$KERNEL_REF" >/dev/null; then
            git -C "$KERNEL_DIR" checkout "$KERNEL_REF"
        else
            git -C "$KERNEL_DIR" checkout -b "$KERNEL_REF" "origin/$KERNEL_REF"
        fi
        git -C "$KERNEL_DIR" pull --ff-only origin "$KERNEL_REF"
    elif git -C "$KERNEL_DIR" rev-parse --verify --quiet "refs/tags/$KERNEL_REF" >/dev/null; then
        git -C "$KERNEL_DIR" checkout "$KERNEL_REF"
    elif git -C "$KERNEL_DIR" rev-parse --verify --quiet FETCH_HEAD >/dev/null; then
        git -C "$KERNEL_DIR" checkout --detach FETCH_HEAD
    elif git -C "$KERNEL_DIR" rev-parse --verify --quiet "$KERNEL_REF" >/dev/null; then
        git -C "$KERNEL_DIR" checkout "$KERNEL_REF"
    else
        die "Unable to resolve kernel ref: $KERNEL_REF"
    fi
}

main() {
    require_command git

    if [ -d "$KERNEL_DIR/.git" ]; then
        update_kernel
    elif [ -e "$KERNEL_DIR" ]; then
        die "$KERNEL_DIR exists but is not a git repository."
    else
        clone_kernel
    fi

    info "Kernel source ready."
    git -C "$KERNEL_DIR" --no-pager log -1 --oneline
}

main "$@"
