#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="${VERTEX_KERNEL_DIR:-$ROOT_DIR/src/kernel}"
BUILD_DIR="${VERTEX_KERNEL_BUILD_DIR:-$ROOT_DIR/.vertex-build/kernel}"
OUT_DIR="${VERTEX_KERNEL_OUT_DIR:-$ROOT_DIR/out/kernel}"
PATCH_DIR="${VERTEX_KERNEL_PATCH_DIR:-$ROOT_DIR/patches}"
BASE_CONFIG="${VERTEX_KERNEL_BASE_CONFIG:-}"
DEFCONFIG="${VERTEX_KERNEL_DEFCONFIG:-x86_64_defconfig}"
KERNEL_ARCH="${VERTEX_KERNEL_ARCH:-${ARCH:-x86}}"
JOBS="${VERTEX_KERNEL_JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"
TARGETS="${VERTEX_KERNEL_TARGETS:-bindeb-pkg}"
LOCALVERSION="${VERTEX_KERNEL_LOCALVERSION:--vertex}"
SKIP_PATCHES="${VERTEX_KERNEL_SKIP_PATCHES:-0}"

info() {
    printf '\033[1;36m[vertex-kernel]\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33m[vertex-kernel]\033[0m %s\n' "$*"
}

die() {
    printf '\033[1;31m[vertex-kernel]\033[0m %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

ensure_kernel_source() {
    if [ ! -d "$KERNEL_DIR/.git" ]; then
        info "Kernel source not found. Fetching it first."
        bash "$ROOT_DIR/scripts/fetch-kernel.sh"
    fi
}

collect_patches() {
    if [ ! -d "$PATCH_DIR" ]; then
        return
    fi

    find "$PATCH_DIR" -maxdepth 2 -type f -name '*.patch' | sort
}

apply_kernel_patches() {
    if [ "$SKIP_PATCHES" = "1" ]; then
        warn "Skipping kernel patches because VERTEX_KERNEL_SKIP_PATCHES=1."
        return
    fi

    local patch
    local patch_count=0

    while IFS= read -r patch; do
        [ -n "$patch" ] || continue
        patch_count=$((patch_count + 1))

        if git -C "$KERNEL_DIR" apply --check "$patch"; then
            info "Applying patch: ${patch#$ROOT_DIR/}"
            git -C "$KERNEL_DIR" apply "$patch"
        elif git -C "$KERNEL_DIR" apply --reverse --check "$patch"; then
            warn "Patch already applied, skipping: ${patch#$ROOT_DIR/}"
        else
            die "Patch failed to apply cleanly: ${patch#$ROOT_DIR/}"
        fi
    done < <(collect_patches)

    if [ "$patch_count" -eq 0 ]; then
        info "No kernel patches found under ${PATCH_DIR#$ROOT_DIR/}."
    fi
}

prepare_base_config() {
    mkdir -p "$BUILD_DIR" "$OUT_DIR"

    if [ -n "$BASE_CONFIG" ]; then
        [ -f "$BASE_CONFIG" ] || die "Base config not found: $BASE_CONFIG"
        info "Using base config: $BASE_CONFIG"
        cp "$BASE_CONFIG" "$BUILD_DIR/.config"
    else
        info "Generating base config with $DEFCONFIG."
        make -C "$KERNEL_DIR" O="$BUILD_DIR" ARCH="$KERNEL_ARCH" "$DEFCONFIG"
    fi
}

merge_vertex_fragments() {
    local merge_script="$KERNEL_DIR/scripts/kconfig/merge_config.sh"
    [ -f "$merge_script" ] || die "merge_config.sh not found in kernel source."

    mapfile -t fragments < <(find "$ROOT_DIR/config/kernel" -maxdepth 1 -type f -name '*.fragment' | sort)
    [ "${#fragments[@]}" -gt 0 ] || die "No kernel fragments found in config/kernel/*.fragment"

    info "Merging Vertex kernel fragments:"
    printf '  %s\n' "${fragments[@]#$ROOT_DIR/}"

    bash "$merge_script" -m -O "$BUILD_DIR" "$BUILD_DIR/.config" "${fragments[@]}"

    info "Finalizing kernel config with olddefconfig."
    make -C "$KERNEL_DIR" O="$BUILD_DIR" ARCH="$KERNEL_ARCH" olddefconfig
}

build_kernel() {
    read -r -a target_array <<< "$TARGETS"

    local make_args=(
        -C "$KERNEL_DIR"
        O="$BUILD_DIR"
        ARCH="$KERNEL_ARCH"
        LOCALVERSION="$LOCALVERSION"
        KBUILD_BUILD_USER=vertex
        KBUILD_BUILD_HOST=Vertex
    )

    if [ -n "${CROSS_COMPILE:-}" ]; then
        make_args+=(CROSS_COMPILE="$CROSS_COMPILE")
    fi

    info "Building kernel targets: ${target_array[*]}"
    info "Using $JOBS parallel jobs."

    make "${make_args[@]}" -j"$JOBS" "${target_array[@]}"

    info "Kernel build complete."
    info "Build directory: $BUILD_DIR"
    info "Final config: $BUILD_DIR/.config"

    if printf ' %s ' "${target_array[@]}" | grep -q ' bindeb-pkg '; then
        info "Debian package artifacts are emitted by the kernel build system near the build tree parent."
    fi
}

main() {
    require_command git
    require_command make

    ensure_kernel_source
    apply_kernel_patches
    prepare_base_config
    merge_vertex_fragments
    build_kernel
}

main "$@"
