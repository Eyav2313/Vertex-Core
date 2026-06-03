#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${VERTEX_BUILD_DIR:-$ROOT_DIR/.vertex-build}"
OUT_DIR="${VERTEX_OUT_DIR:-$ROOT_DIR/out}"
CACHE_DIR="${VERTEX_CACHE_DIR:-$BUILD_DIR/cache}"
SUITE="${VERTEX_SUITE:-trixie}"
MIRROR="${VERTEX_MIRROR:-http://deb.debian.org/debian}"
SKIP_APT="${VERTEX_SKIP_APT:-0}"

HOST_PACKAGES=(
    apt-transport-https
    bash-completion
    bc
    bison
    build-essential
    ca-certificates
    clang
    cmake
    cpio
    curl
    debhelper
    debian-archive-keyring
    devscripts
    dpkg-dev
    dwarves
    fakeroot
    flex
    gawk
    git
    gnupg
    kmod
    libelf-dev
    libncurses-dev
    libssl-dev
    live-build
    lld
    llvm
    make
    mmdebstrap
    ninja-build
    ovmf
    pkg-config
    python3
    python3-pip
    python3-venv
    qemu-system-x86
    rsync
    rustc
    cargo
    shellcheck
    squashfs-tools
    sudo
    xz-utils
    xorriso
    zstd
)

info() {
    printf '\033[1;36m[vertex]\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33m[vertex]\033[0m %s\n' "$*"
}

run_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        warn "sudo is not available. Re-run as root or install these packages manually:"
        printf '  %s\n' "${HOST_PACKAGES[@]}"
        exit 1
    fi
}

install_host_packages() {
    if [ "$SKIP_APT" = "1" ]; then
        warn "Skipping APT package installation because VERTEX_SKIP_APT=1."
        return
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        warn "apt-get was not found. Use Debian, Ubuntu, or WSL for the first build host."
        warn "Install these packages manually:"
        printf '  %s\n' "${HOST_PACKAGES[@]}"
        return
    fi

    info "Installing host build dependencies."
    run_root apt-get update
    run_root apt-get install -y --no-install-recommends "${HOST_PACKAGES[@]}"
}

prepare_directories() {
    info "Preparing local build directories."
    mkdir -p "$BUILD_DIR" "$CACHE_DIR" "$OUT_DIR"
    mkdir -p "$BUILD_DIR/rootfs" "$BUILD_DIR/live-build" "$BUILD_DIR/packages"
}

prepare_permissions() {
    info "Normalizing executable permissions for scripts and packaging helpers."
    chmod +x "$ROOT_DIR/build-vertex.sh" 2>/dev/null || true
    chmod +x "$ROOT_DIR"/scripts/*.sh 2>/dev/null || true
    chmod +x "$ROOT_DIR/packages/vertex-meta/debian/rules" 2>/dev/null || true
}

prepare_python_env() {
    info "Preparing Python tooling environment."
    python3 -m venv "$BUILD_DIR/venv"
    # shellcheck disable=SC1091
    . "$BUILD_DIR/venv/bin/activate"
    python -m pip install --upgrade pip wheel
    python -m pip install -e "$ROOT_DIR/tools/python"
}

write_local_env() {
    local env_file="$BUILD_DIR/vertex-env.sh"

    info "Writing local environment file: $env_file"
    cat >"$env_file" <<EOF
export VERTEX_ROOT="$ROOT_DIR"
export VERTEX_BUILD_DIR="$BUILD_DIR"
export VERTEX_OUT_DIR="$OUT_DIR"
export VERTEX_CACHE_DIR="$CACHE_DIR"
export VERTEX_SUITE="$SUITE"
export VERTEX_MIRROR="$MIRROR"
export PATH="$BUILD_DIR/venv/bin:\$PATH"
EOF
}

print_summary() {
    info "Vertex build environment initialized."
    printf '\n'
    printf 'Source the environment:\n'
    printf '  . "%s/vertex-env.sh"\n' "$BUILD_DIR"
    printf '\n'
    printf 'Inspect the desktop profile:\n'
    printf '  vertex-build inspect --profile desktop\n'
    printf '\n'
    printf 'Current build settings:\n'
    printf '  suite:  %s\n' "$SUITE"
    printf '  mirror: %s\n' "$MIRROR"
    printf '  out:    %s\n' "$OUT_DIR"
}

main() {
    info "Initializing Vertex OS build environment."
    install_host_packages
    prepare_directories
    prepare_permissions
    prepare_python_env
    write_local_env
    print_summary
}

main "$@"
