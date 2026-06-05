#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out/html-lock"
KERNEL="$OUT_DIR/vertex-html-lock-vmlinuz"
INITRD="$OUT_DIR/vertex-html-lock-initrd.img"
ROOTFS="$OUT_DIR/vertex-html-lock-rootfs.ext4"
LOG_DIR="$ROOT_DIR/build/logs"
LOG_FILE="$LOG_DIR/vertex-html-lock-qemu.log"
WIDTH="${VERTEX_QEMU_WIDTH:-1280}"
HEIGHT="${VERTEX_QEMU_HEIGHT:-720}"

die() {
    printf '[vertex-html-lock] %s\n' "$*" >&2
    exit 1
}

command -v qemu-system-x86_64 >/dev/null 2>&1 || die "Missing qemu-system-x86_64"

if [ ! -f "$KERNEL" ] || [ ! -f "$INITRD" ] || [ ! -f "$ROOTFS" ]; then
    die "HTML lock OS artifacts are missing. Run scripts/build-html-lock-os.sh first."
fi

mkdir -p "$LOG_DIR"

if [ -S /mnt/wslg/runtime-dir/wayland-0 ]; then
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/mnt/wslg/runtime-dir}"
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
    export DISPLAY="${DISPLAY:-:0}"
fi

ACCEL_ARGS=()
CPU_ARGS=(-cpu qemu64)
AUDIO_ARGS=()
if [ -e /dev/kvm ]; then
    ACCEL_ARGS=(-enable-kvm)
    CPU_ARGS=(-cpu host)
fi

if [ "${VERTEX_QEMU_AUDIO:-0}" = "1" ]; then
    AUDIO_ARGS=(
        -audiodev "${VERTEX_QEMU_AUDIO_DRIVER:-sdl},id=vertexaudio"
        -device intel-hda
        -device hda-output,audiodev=vertexaudio
    )
fi

exec qemu-system-x86_64 \
    "${ACCEL_ARGS[@]}" \
    "${CPU_ARGS[@]}" \
    "${AUDIO_ARGS[@]}" \
    -name Vertex-HTML-Lock \
    -m "${VERTEX_HTML_LOCK_MEMORY:-3072M}" \
    -smp "${VERTEX_HTML_LOCK_CPUS:-2}" \
    -machine pc \
    -accel tcg,thread=multi \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -append "root=/dev/vda rw quiet loglevel=3 console=ttyS0,115200n8 vt.global_cursor_default=0 video=${WIDTH}x${HEIGHT} systemd.unit=multi-user.target systemd.mask=systemd-udev-settle.service" \
    -drive "file=$ROOTFS,if=virtio,format=raw,cache=writeback" \
    -device "VGA,vgamem_mb=64,xres=${WIDTH},yres=${HEIGHT}" \
    -usb \
    -device usb-kbd \
    -device usb-tablet \
    -net none \
    -display "${VERTEX_QEMU_DISPLAY:-gtk,zoom-to-fit=on}" \
    -full-screen \
    -serial "file:$LOG_FILE.serial" \
    -monitor none \
    -no-reboot
