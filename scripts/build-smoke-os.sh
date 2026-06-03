#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out/smoke"
INITRAMFS_ROOT="$OUT_DIR/initramfs-root"

info() {
    printf '[vertexos-smoke] %s\n' "$*"
}

die() {
    printf '[vertexos-smoke] %s\n' "$*" >&2
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

find_kernel() {
    local kernel
    kernel="$(ls -1 /boot/vmlinuz-* 2>/dev/null | sort -V | tail -n 1 || true)"
    [ -n "$kernel" ] || die "No host kernel found in /boot. Install linux-image-virtual or linux-image-generic."
    printf '%s\n' "$kernel"
}

require busybox
require cpio
require gzip

KERNEL_IMAGE="$(find_kernel)"
BUSYBOX_PATH="$(command -v busybox)"

info "Using kernel: $KERNEL_IMAGE"
info "Using busybox: $BUSYBOX_PATH"

rm -rf "$OUT_DIR"
mkdir -p \
    "$INITRAMFS_ROOT/bin" \
    "$INITRAMFS_ROOT/dev" \
    "$INITRAMFS_ROOT/etc" \
    "$INITRAMFS_ROOT/proc" \
    "$INITRAMFS_ROOT/root" \
    "$INITRAMFS_ROOT/sys" \
    "$INITRAMFS_ROOT/tmp"

cp "$BUSYBOX_PATH" "$INITRAMFS_ROOT/bin/busybox"

cat > "$INITRAMFS_ROOT/init" <<'EOF'
#!/bin/busybox sh

/bin/busybox --install -s /bin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || {
    mknod /dev/console c 5 1
    mknod /dev/null c 1 3
    mknod /dev/tty c 5 0
}

export PATH=/bin
export HOME=/root
export TERM=linux
hostname VertexOS
clear

cat <<'BANNER'

 __     __        _            ___  ____
 \ \   / /__ _ __| |_ _____  / _ \/ ___|
  \ \ / / _ \ '__| __/ _ \ \/ / | \___ \
   \ V /  __/ |  | ||  __/>  <| |_| |__) |
    \_/ \___|_|   \__\___/_/\_\\___/____/

 VertexOS smoke boot
 Developer: Nuren Zarif Haque
 Base: Linux kernel + minimal initramfs

BANNER

printf 'Kernel: '
uname -r
printf 'CPU: '
grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //'
printf 'Memory: '
awk '/MemTotal/ { printf "%d MB\n", $2 / 1024 }' /proc/meminfo

cat <<'HELP'

This is a real booted OS smoke test, not the browser preview.
Commands: help, perf, reboot, poweroff

HELP

while true; do
    printf 'vertexos# '
    read -r cmd || cmd=poweroff
    case "$cmd" in
        help)
            echo 'help     show commands'
            echo 'perf     show CPU and memory snapshot'
            echo 'reboot   reboot QEMU'
            echo 'poweroff power off QEMU'
            ;;
        perf)
            echo 'Load average:'
            cat /proc/loadavg
            echo 'Memory:'
            awk '/MemTotal|MemFree|MemAvailable/ { print }' /proc/meminfo
            ;;
        reboot)
            sync
            reboot -f
            ;;
        poweroff|exit|halt)
            sync
            poweroff -f
            ;;
        '')
            ;;
        *)
            sh -lc "$cmd"
            ;;
    esac
done
EOF

chmod +x "$INITRAMFS_ROOT/init" "$INITRAMFS_ROOT/bin/busybox"

(
    cd "$INITRAMFS_ROOT"
    find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "$OUT_DIR/vertexos-smoke-initramfs.cpio.gz"
)

cp "$KERNEL_IMAGE" "$OUT_DIR/vertexos-smoke-vmlinuz"

cat > "$OUT_DIR/README.txt" <<EOF
VertexOS smoke boot artifacts

Kernel: vertexos-smoke-vmlinuz
Initramfs: vertexos-smoke-initramfs.cpio.gz

Run:
  scripts/run-smoke-os.sh
EOF

info "Created $OUT_DIR/vertexos-smoke-vmlinuz"
info "Created $OUT_DIR/vertexos-smoke-initramfs.cpio.gz"
