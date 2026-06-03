#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out/smoke"
INITRAMFS_ROOT="$OUT_DIR/initramfs-root"
ISO_ROOT="$OUT_DIR/iso-root"

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

rm -rf \
    "$INITRAMFS_ROOT" \
    "$ISO_ROOT" \
    "$OUT_DIR/vertexos-smoke-vmlinuz" \
    "$OUT_DIR/vertexos-smoke-initramfs.cpio.gz" \
    "$OUT_DIR/vertexos-smoke-uefi.iso"
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

 VertexOS
 Linux smoke boot
 Developer: Nuren Zarif Haque

BANNER

cpu_model() {
    grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //' || echo unknown
}

cpu_count() {
    grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1
}

mem_mb() {
    awk '/MemTotal/ { printf "%d", $2 / 1024 }' /proc/meminfo
}

disk_report() {
    found=0
    for dev in vda sda nvme0n1; do
        [ -r "/sys/block/$dev/size" ] || continue
        sectors="$(cat "/sys/block/$dev/size")"
        awk -v d="$dev" -v s="$sectors" 'BEGIN {
            gib = s * 512 / 1024 / 1024 / 1024
            printf "%s %.1f GiB\n", d, gib
        }'
        found=1
    done
    [ "$found" = 1 ] || echo "none"
}

if [ -d /sys/firmware/efi ]; then
    boot_mode="UEFI"
else
    boot_mode="direct-kernel"
fi

printf 'Boot:   %s\n' "$boot_mode"
printf 'Kernel: '
uname -r
printf 'CPU:    %s x %s\n' "$(cpu_count)" "$(cpu_model)"
printf 'RAM:    %s MB\n' "$(mem_mb)"
printf 'Disk:   '
disk_report | head -n 1

cat <<'HELP'

Commands: help, perf, disks, reboot, poweroff

HELP

while true; do
    printf 'vertexos# '
    read -r cmd || cmd=poweroff
    case "$cmd" in
        help)
            echo 'help     show commands'
            echo 'perf     show CPU and memory snapshot'
            echo 'disks    show virtual block devices'
            echo 'reboot   reboot QEMU'
            echo 'poweroff power off QEMU'
            ;;
        perf)
            printf 'CPU: '
            echo "$(cpu_count) x $(cpu_model)"
            printf 'Load: '
            cat /proc/loadavg
            echo 'RAM:'
            awk '/MemTotal|MemFree|MemAvailable/ { print }' /proc/meminfo
            ;;
        disks)
            disk_report
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

if command -v grub-mkrescue >/dev/null 2>&1 && [ -d /usr/lib/grub/x86_64-efi ]; then
    mkdir -p "$ISO_ROOT/boot/grub"
    cp "$OUT_DIR/vertexos-smoke-vmlinuz" "$ISO_ROOT/boot/vmlinuz"
    cp "$OUT_DIR/vertexos-smoke-initramfs.cpio.gz" "$ISO_ROOT/boot/initramfs.cpio.gz"

    cat > "$ISO_ROOT/boot/grub/grub.cfg" <<'EOF'
serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
terminal_input console serial
terminal_output console serial
set timeout=0
set default=0

menuentry "VertexOS Smoke" {
    linux /boot/vmlinuz console=tty0 console=ttyS0,115200 quiet loglevel=0 vt.global_cursor_default=0 fbcon=font:VGA8x8 panic=1
    initrd /boot/initramfs.cpio.gz
}
EOF

    grub-mkrescue -o "$OUT_DIR/vertexos-smoke-uefi.iso" "$ISO_ROOT" >/dev/null 2>&1
    info "Created $OUT_DIR/vertexos-smoke-uefi.iso"
else
    info "Skipping UEFI ISO creation; grub-mkrescue or x86_64-efi GRUB modules are missing."
fi

if [ -f /usr/share/OVMF/OVMF_CODE_4M.fd ] && [ -f /usr/share/OVMF/OVMF_VARS_4M.fd ]; then
    cp /usr/share/OVMF/OVMF_CODE_4M.fd "$OUT_DIR/OVMF_CODE_4M.fd"
    cp /usr/share/OVMF/OVMF_VARS_4M.fd "$OUT_DIR/OVMF_VARS_4M.fd"
    info "Copied OVMF UEFI firmware into $OUT_DIR"
fi

cat > "$OUT_DIR/README.txt" <<EOF
VertexOS smoke boot artifacts

Kernel: vertexos-smoke-vmlinuz
Initramfs: vertexos-smoke-initramfs.cpio.gz
UEFI ISO: vertexos-smoke-uefi.iso
UEFI firmware: OVMF_CODE_4M.fd, OVMF_VARS_4M.fd

Run:
  scripts/run-smoke-os.sh
EOF

info "Created $OUT_DIR/vertexos-smoke-vmlinuz"
info "Created $OUT_DIR/vertexos-smoke-initramfs.cpio.gz"
