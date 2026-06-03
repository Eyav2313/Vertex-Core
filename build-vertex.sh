#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVELOPER_NAME="${VERTEX_DEVELOPER_NAME:-Nuren Zarif Haque}"
SUITE="${VERTEX_SUITE:-trixie}"
MIRROR="${VERTEX_MIRROR:-http://deb.debian.org/debian}"
PROFILE="${VERTEX_PROFILE:-desktop}"
ARCH="${VERTEX_ARCH:-amd64}"

BUILD_ROOT="$ROOT_DIR/build"
WORK_DIR="$BUILD_ROOT/work"
LOG_DIR="$BUILD_ROOT/logs"
PACKAGE_OUT_DIR="$BUILD_ROOT/packages"
ROOTFS_DIR="$WORK_DIR/rootfs"
LIVE_BUILD_DIR="$BUILD_ROOT/live-build"
LIVE_INCLUDES_DIR="$LIVE_BUILD_DIR/config/includes.chroot"
LIVE_PACKAGES_DIR="$LIVE_BUILD_DIR/config/packages.chroot"
LIVE_PACKAGE_LIST="$LIVE_BUILD_DIR/config/package-lists/vertex.list.chroot"
NATIVE_BUILD_DIR="$WORK_DIR/native/vertex-sessiond"
OUT_DIR="$ROOT_DIR/out"

BUILD_ID="$(date -u +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/vertex-build-$BUILD_ID.log"

VERTEX_SKIP_HOST_INIT="${VERTEX_SKIP_HOST_INIT:-0}"
VERTEX_SKIP_KERNEL="${VERTEX_SKIP_KERNEL:-0}"
VERTEX_SKIP_NATIVE="${VERTEX_SKIP_NATIVE:-0}"
VERTEX_SKIP_ROOTFS="${VERTEX_SKIP_ROOTFS:-0}"
VERTEX_SKIP_ISO="${VERTEX_SKIP_ISO:-0}"
VERTEX_HYPRLAND_PROFILE="${VERTEX_HYPRLAND_PROFILE:-performance}"
VERTEX_MMDEBSTRAP_MODE="${VERTEX_MMDEBSTRAP_MODE:-auto}"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

info() {
    printf '\033[1;36m[vertex]\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33m[vertex]\033[0m %s\n' "$*"
}

die() {
    printf '\033[1;31m[vertex]\033[0m %s\n' "$*" >&2
    exit 1
}

on_error() {
    local line="$1"
    local code="$2"
    printf '\n\033[1;31m[vertex]\033[0m Build failed at line %s with exit code %s.\n' "$line" "$code" >&2
    printf '\033[1;31m[vertex]\033[0m Detailed log: %s\n' "$LOG_FILE" >&2
}

trap 'on_error "$LINENO" "$?"' ERR

run_step() {
    local name="$1"
    shift

    printf '\n'
    info "==> $name"
    "$@"
    info "<== $name complete"
}

print_usage() {
    cat <<EOF
Vertex OS master build
Developer: $DEVELOPER_NAME

Usage:
  ./build-vertex.sh

Environment options:
  VERTEX_PROFILE=desktop
  VERTEX_SUITE=trixie
  VERTEX_MIRROR=http://deb.debian.org/debian
  VERTEX_HYPRLAND_PROFILE=performance|glass|full
  VERTEX_SKIP_KERNEL=1
  VERTEX_SKIP_NATIVE=1
  VERTEX_SKIP_ROOTFS=1
  VERTEX_SKIP_ISO=1
  VERTEX_KERNEL_TARGETS="bindeb-pkg"

Logs:
  build/logs/
EOF
}

parse_args() {
    if [ "$#" -eq 0 ]; then
        return
    fi

    case "$1" in
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            die "Unknown argument: $1. Use --help for usage."
            ;;
    esac
}

require_command() {
    command -v "$1" >/dev/null 2>&1
}

missing_commands() {
    local required=(
        bash
        bc
        bison
        cmake
        dpkg-buildpackage
        fakeroot
        flex
        g++
        gcc
        git
        lb
        make
        mmdebstrap
        nproc
        realpath
        rsync
    )

    local cmd
    for cmd in "${required[@]}"; do
        if ! require_command "$cmd"; then
            printf '%s\n' "$cmd"
        fi
    done
}

run_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif require_command sudo; then
        sudo "$@"
    else
        die "This step needs root privileges. Install sudo or run build-vertex.sh as root."
    fi
}

safe_remove_dir() {
    local target="$1"
    [ -e "$target" ] || return 0

    local resolved
    resolved="$(realpath -m "$target")"

    case "$resolved" in
        "$WORK_DIR"/*|"$ROOTFS_DIR"|"$LIVE_BUILD_DIR"|"$LIVE_BUILD_DIR"/*|"$PACKAGE_OUT_DIR"|"$PACKAGE_OUT_DIR"/*)
            run_root rm -rf -- "$resolved"
            ;;
        *)
            die "Refusing to remove path outside generated build directories: $resolved"
            ;;
    esac
}

read_manifest_packages() {
    local manifest="$ROOT_DIR/build/profiles/$PROFILE/debian.packages"
    [ -f "$manifest" ] || die "Package manifest not found: $manifest"

    sed 's/#.*$//' "$manifest" | awk 'NF { print $1 }'
}

read_manifest_as_csv() {
    read_manifest_packages | paste -sd, -
}

bootstrap_host_dependencies() {
    if [ "$VERTEX_SKIP_HOST_INIT" = "1" ]; then
        warn "Skipping host bootstrap because VERTEX_SKIP_HOST_INIT=1."
        return
    fi

    if ! require_command apt-get; then
        warn "apt-get not found. Dependency auto-install is only available on Debian/Ubuntu hosts."
        return
    fi

    info "Running host dependency bootstrap."
    bash "$ROOT_DIR/scripts/init-build-env.sh"
}

check_dependencies() {
    local missing
    missing="$(missing_commands || true)"

    if [ -n "$missing" ]; then
        warn "Missing build commands before bootstrap:"
        printf '  %s\n' $missing
        bootstrap_host_dependencies
    fi

    missing="$(missing_commands || true)"
    if [ -n "$missing" ]; then
        warn "Still missing required commands:"
        printf '  %s\n' $missing
        die "Install missing dependencies, then rerun ./build-vertex.sh. See $LOG_FILE for details."
    fi
}

prepare_workspace() {
    mkdir -p "$WORK_DIR" "$PACKAGE_OUT_DIR" "$OUT_DIR"
    info "Build id: $BUILD_ID"
    info "Developer: $DEVELOPER_NAME"
    info "Suite: $SUITE"
    info "Profile: $PROFILE"
    info "Architecture: $ARCH"
    info "Log: $LOG_FILE"
}

build_native_components() {
    if [ "$VERTEX_SKIP_NATIVE" = "1" ]; then
        warn "Skipping native component build because VERTEX_SKIP_NATIVE=1."
        return
    fi

    cmake -S "$ROOT_DIR/src/native/vertex-sessiond" \
        -B "$NATIVE_BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release

    cmake --build "$NATIVE_BUILD_DIR" --parallel "$(nproc)"
}

build_kernel() {
    if [ "$VERTEX_SKIP_KERNEL" = "1" ]; then
        warn "Skipping kernel build because VERTEX_SKIP_KERNEL=1."
        return
    fi

    VERTEX_KERNEL_OUT_DIR="$OUT_DIR/kernel" \
        bash "$ROOT_DIR/scripts/build-kernel.sh"

    local search_dir
    for search_dir in "$ROOT_DIR/.vertex-build" "$OUT_DIR/kernel" "$ROOT_DIR"; do
        [ -d "$search_dir" ] || continue
        find "$search_dir" \
            -maxdepth 2 \
            -type f \
            -name '*.deb' \
            -print0 |
            while IFS= read -r -d '' deb; do
                cp "$deb" "$PACKAGE_OUT_DIR/"
            done
    done
}

build_vertex_metapackage() {
    chmod +x "$ROOT_DIR/packages/vertex-meta/debian/rules" 2>/dev/null || true

    (
        cd "$ROOT_DIR/packages/vertex-meta"
        dpkg-buildpackage -us -uc -b
    )

    find "$ROOT_DIR/packages" \
        -maxdepth 1 \
        -type f \
        -name 'vertex-meta-desktop_*.deb' \
        -print0 |
        while IFS= read -r -d '' deb; do
            cp "$deb" "$PACKAGE_OUT_DIR/"
        done
}

install_tree() {
    local source="$1"
    local target="$2"
    [ -e "$source" ] || return 0
    mkdir -p "$target"
    rsync -a "$source"/ "$target"/
}

selected_hyprland_config() {
    case "$VERTEX_HYPRLAND_PROFILE" in
        performance)
            printf '%s\n' "$ROOT_DIR/config/window-manager/hyprland-performance.conf"
            ;;
        glass)
            printf '%s\n' "$ROOT_DIR/config/window-manager/hyprland.conf"
            ;;
        full)
            printf '%s\n' "$ROOT_DIR/config/window-manager/hyprland/vertex.conf"
            ;;
        *)
            die "Unknown VERTEX_HYPRLAND_PROFILE: $VERTEX_HYPRLAND_PROFILE"
            ;;
    esac
}

inject_vertex_config() {
    local target_root="$1"
    local hyprland_config
    hyprland_config="$(selected_hyprland_config)"

    info "Injecting Vertex configuration into $target_root"

    mkdir -p \
        "$target_root/etc/skel/.config/hypr" \
        "$target_root/etc/skel/.config/waybar" \
        "$target_root/etc/skel/.config/alacritty" \
        "$target_root/etc/sysctl.d" \
        "$target_root/etc/default" \
        "$target_root/etc/udev/rules.d" \
        "$target_root/etc/systemd/system" \
        "$target_root/etc/wayland" \
        "$target_root/usr/share/sddm/themes" \
        "$target_root/usr/share/vertex/branding" \
        "$target_root/usr/libexec/vertex"

    install -m 0644 "$hyprland_config" "$target_root/etc/skel/.config/hypr/hyprland.conf"
    install -m 0644 "$ROOT_DIR/config/window-manager/waybar/style.css" "$target_root/etc/skel/.config/waybar/style.css"

    if [ -f "$ROOT_DIR/config/window-manager/waybar/config.jsonc" ]; then
        install -m 0644 "$ROOT_DIR/config/window-manager/waybar/config.jsonc" "$target_root/etc/skel/.config/waybar/config.jsonc"
    fi

    install -m 0644 "$ROOT_DIR/config/terminal/alacritty/vertex.toml" "$target_root/etc/skel/.config/alacritty/vertex.toml"
    install -m 0644 "$ROOT_DIR/config/shell/zsh/vertex.zshrc" "$target_root/etc/skel/.zshrc"
    install -m 0644 "$ROOT_DIR/config/kernel/sysctl.d/99-vertex-performance.conf" "$target_root/etc/sysctl.d/99-vertex-performance.conf"
    install -m 0644 "$ROOT_DIR/config/performance/zram-tools/zramswap" "$target_root/etc/default/zramswap"
    install -m 0644 "$ROOT_DIR/config/performance/udev/rules.d/60-vertex-io-scheduler.rules" "$target_root/etc/udev/rules.d/60-vertex-io-scheduler.rules"
    install -m 0644 "$ROOT_DIR/config/performance/systemd/vertex-performance.service" "$target_root/etc/systemd/system/vertex-performance.service"

    install_tree "$ROOT_DIR/config/display-manager/sddm/vertex-glass" "$target_root/usr/share/sddm/themes/vertex-glass"

    if [ -f "$ROOT_DIR/assets/branding/vertex-logo.png" ]; then
        install -m 0644 "$ROOT_DIR/assets/branding/vertex-logo.png" "$target_root/usr/share/vertex/branding/vertex-logo.png"
    fi

    if [ "$VERTEX_SKIP_NATIVE" != "1" ] && [ -x "$NATIVE_BUILD_DIR/vertex-sessiond" ]; then
        install -m 0755 "$NATIVE_BUILD_DIR/vertex-sessiond" "$target_root/usr/libexec/vertex/vertex-sessiond"
    fi

    cat > "$target_root/etc/wayland/vertex-session.conf" <<EOF
[Vertex]
Developer=$DEVELOPER_NAME
Session=hyprland
HyprlandProfile=$VERTEX_HYPRLAND_PROFILE
WaybarMetrics=/usr/libexec/vertex/vertex-sessiond --waybar
EOF
}

install_local_debs_into_rootfs() {
    local target_root="$1"
    mapfile -t debs < <(find "$PACKAGE_OUT_DIR" -maxdepth 1 -type f -name '*.deb' | sort)

    if [ "${#debs[@]}" -eq 0 ]; then
        warn "No local Debian packages found in $PACKAGE_OUT_DIR."
        return
    fi

    run_root mkdir -p "$target_root/tmp/vertex-packages"
    run_root cp "${debs[@]}" "$target_root/tmp/vertex-packages/"
    run_root chroot "$target_root" sh -c 'dpkg -i /tmp/vertex-packages/*.deb || apt-get -y -f install'
    run_root rm -rf "$target_root/tmp/vertex-packages"
}

assemble_rootfs() {
    if [ "$VERTEX_SKIP_ROOTFS" = "1" ]; then
        warn "Skipping rootfs assembly because VERTEX_SKIP_ROOTFS=1."
        return
    fi

    safe_remove_dir "$ROOTFS_DIR"
    mkdir -p "$WORK_DIR"

    local include_packages
    include_packages="$(read_manifest_as_csv)"
    [ -n "$include_packages" ] || die "No packages found in profile manifest."

    info "Assembling rootfs with mmdebstrap."
    run_root mmdebstrap \
        --mode="$VERTEX_MMDEBSTRAP_MODE" \
        --variant=minbase \
        --include="$include_packages" \
        "$SUITE" \
        "$ROOTFS_DIR" \
        "$MIRROR"

    run_root bash -c "$(declare -f install_tree selected_hyprland_config inject_vertex_config info die); ROOT_DIR='$ROOT_DIR'; DEVELOPER_NAME='$DEVELOPER_NAME'; VERTEX_HYPRLAND_PROFILE='$VERTEX_HYPRLAND_PROFILE'; VERTEX_SKIP_NATIVE='$VERTEX_SKIP_NATIVE'; NATIVE_BUILD_DIR='$NATIVE_BUILD_DIR'; inject_vertex_config '$ROOTFS_DIR'"
    install_local_debs_into_rootfs "$ROOTFS_DIR"
}

write_live_build_package_list() {
    mkdir -p "$(dirname "$LIVE_PACKAGE_LIST")"
    read_manifest_packages > "$LIVE_PACKAGE_LIST"
}

copy_local_debs_to_live_build() {
    mkdir -p "$LIVE_PACKAGES_DIR"
    find "$PACKAGE_OUT_DIR" -maxdepth 1 -type f -name '*.deb' -print0 |
        while IFS= read -r -d '' deb; do
            cp "$deb" "$LIVE_PACKAGES_DIR/"
        done
}

write_live_build_hooks() {
    local hook_dir="$LIVE_BUILD_DIR/config/hooks/normal"
    mkdir -p "$hook_dir"

    cat > "$hook_dir/010-vertex-enable-services.hook.chroot" <<'EOF'
#!/bin/sh
set -e

systemctl enable NetworkManager.service || true
systemctl enable sddm.service || true
systemctl enable vertex-performance.service || true
EOF

    chmod +x "$hook_dir/010-vertex-enable-services.hook.chroot"
}

build_iso() {
    if [ "$VERTEX_SKIP_ISO" = "1" ]; then
        warn "Skipping ISO creation because VERTEX_SKIP_ISO=1."
        return
    fi

    safe_remove_dir "$LIVE_BUILD_DIR"
    mkdir -p "$LIVE_BUILD_DIR"

    (
        cd "$LIVE_BUILD_DIR"
        lb config \
            --mode debian \
            --distribution "$SUITE" \
            --architectures "$ARCH" \
            --archive-areas "main contrib non-free non-free-firmware" \
            --binary-images iso-hybrid \
            --debian-installer live \
            --apt-recommends false \
            --bootappend-live "boot=live components quiet splash"
    )

    write_live_build_package_list
    inject_vertex_config "$LIVE_INCLUDES_DIR"
    copy_local_debs_to_live_build
    write_live_build_hooks

    (
        cd "$LIVE_BUILD_DIR"
        run_root lb build
    )

    local iso
    iso="$(find "$LIVE_BUILD_DIR" -maxdepth 1 -type f -name '*.iso' | sort | tail -n 1 || true)"
    if [ -n "$iso" ]; then
        cp "$iso" "$OUT_DIR/vertex-os-$BUILD_ID.iso"
        info "ISO ready: $OUT_DIR/vertex-os-$BUILD_ID.iso"
    else
        warn "live-build completed, but no ISO was found in $LIVE_BUILD_DIR."
    fi
}

main() {
    parse_args "$@"

    info "Vertex OS master build started."
    run_step "Prepare workspace" prepare_workspace
    run_step "Check dependencies" check_dependencies
    run_step "Build native components" build_native_components
    run_step "Compile kernel" build_kernel
    run_step "Build vertex-meta-desktop" build_vertex_metapackage
    run_step "Assemble mmdebstrap rootfs" assemble_rootfs
    run_step "Create live-build ISO" build_iso

    printf '\n'
    info "Vertex OS build complete."
    info "Detailed log: $LOG_FILE"
}

main "$@"
