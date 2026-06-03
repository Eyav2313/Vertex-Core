#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out/smoke"
KERNEL="$OUT_DIR/vertexos-smoke-vmlinuz"
INITRAMFS="$OUT_DIR/vertexos-smoke-initramfs.cpio.gz"
LOG_DIR="$ROOT_DIR/build/logs"
PID_FILE="$LOG_DIR/vertexos-smoke-qemu.pid"
LOG_FILE="$LOG_DIR/vertexos-smoke-qemu.log"

die() {
    printf '[vertexos-smoke] %s\n' "$*" >&2
    exit 1
}

command -v qemu-system-x86_64 >/dev/null 2>&1 || die "Missing qemu-system-x86_64"

if [ ! -f "$KERNEL" ] || [ ! -f "$INITRAMFS" ]; then
    bash "$ROOT_DIR/scripts/build-smoke-os.sh"
fi

mkdir -p "$LOG_DIR"

if [ -S /mnt/wslg/runtime-dir/wayland-0 ]; then
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/mnt/wslg/runtime-dir}"
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
    export DISPLAY="${DISPLAY:-:0}"
fi

DISPLAY_MODE="${VERTEX_QEMU_DISPLAY:-gtk}"
APPEND="${VERTEX_QEMU_APPEND:-console=tty0 console=ttyS0,115200 quiet panic=1}"
ACCEL_ARGS=()
CPU_ARGS=(-cpu qemu64)

if [ -e /dev/kvm ]; then
    ACCEL_ARGS=(-enable-kvm)
    CPU_ARGS=(-cpu host)
fi

if [ "$DISPLAY_MODE" = "none" ]; then
    exec qemu-system-x86_64 \
        "${ACCEL_ARGS[@]}" \
        "${CPU_ARGS[@]}" \
        -m "${VERTEX_QEMU_MEMORY:-768M}" \
        -smp "${VERTEX_QEMU_CPUS:-2}" \
        -kernel "$KERNEL" \
        -initrd "$INITRAMFS" \
        -append "console=ttyS0 panic=1" \
        -display none \
        -serial stdio \
        -monitor none \
        -no-reboot
fi

QEMU_CMD=(
    qemu-system-x86_64
    "${ACCEL_ARGS[@]}"
    "${CPU_ARGS[@]}"
    -m "${VERTEX_QEMU_MEMORY:-768M}"
    -smp "${VERTEX_QEMU_CPUS:-2}"
    -kernel "$KERNEL"
    -initrd "$INITRAMFS"
    -append "$APPEND"
    -display "$DISPLAY_MODE"
    -serial "file:$LOG_FILE.serial"
    -monitor none
    -no-reboot
)

if command -v setsid >/dev/null 2>&1; then
    nohup setsid "${QEMU_CMD[@]}" >"$LOG_FILE" 2>&1 < /dev/null &
else
    nohup "${QEMU_CMD[@]}" >"$LOG_FILE" 2>&1 < /dev/null &
fi

printf '%s\n' "$!" > "$PID_FILE"
printf '[vertexos-smoke] QEMU started. PID: %s\n' "$(cat "$PID_FILE")"
printf '[vertexos-smoke] Log: %s\n' "$LOG_FILE"
