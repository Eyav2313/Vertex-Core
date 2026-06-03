#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out/smoke"
KERNEL="$OUT_DIR/vertexos-smoke-vmlinuz"
INITRAMFS="$OUT_DIR/vertexos-smoke-initramfs.cpio.gz"
UEFI_ISO="$OUT_DIR/vertexos-smoke-uefi.iso"
DISK="$OUT_DIR/vertexos-smoke-disk.raw"
OVMF_VARS="$OUT_DIR/OVMF_VARS.fd"
LOG_DIR="$ROOT_DIR/build/logs"
PID_FILE="$LOG_DIR/vertexos-smoke-qemu.pid"
LOG_FILE="$LOG_DIR/vertexos-smoke-qemu.log"

die() {
    printf '[vertexos-smoke] %s\n' "$*" >&2
    exit 1
}

command -v qemu-system-x86_64 >/dev/null 2>&1 || die "Missing qemu-system-x86_64"

if [ ! -f "$KERNEL" ] || [ ! -f "$INITRAMFS" ] || [ ! -f "$UEFI_ISO" ]; then
    bash "$ROOT_DIR/scripts/build-smoke-os.sh"
fi

mkdir -p "$LOG_DIR" "$OUT_DIR"

if [ ! -f "$DISK" ]; then
    truncate -s "${VERTEX_QEMU_DISK_SIZE:-1G}" "$DISK"
fi

if [ -S /mnt/wslg/runtime-dir/wayland-0 ]; then
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/mnt/wslg/runtime-dir}"
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
    export DISPLAY="${DISPLAY:-:0}"
fi

DISPLAY_MODE="${VERTEX_QEMU_DISPLAY:-gtk}"
APPEND="${VERTEX_QEMU_APPEND:-console=tty0 console=ttyS0,115200 quiet loglevel=0 vt.global_cursor_default=0 fbcon=font:VGA8x8 panic=1}"
MACHINE="${VERTEX_QEMU_MACHINE:-pc}"
ACCEL_ARGS=()
CPU_ARGS=(-cpu qemu64)
FIRMWARE_ARGS=()
BOOT_ARGS=()

if [ -e /dev/kvm ]; then
    ACCEL_ARGS=(-enable-kvm)
    CPU_ARGS=(-cpu host)
fi

if [ "${VERTEX_QEMU_FIRMWARE:-direct}" = "uefi" ]; then
    OVMF_CODE="${VERTEX_OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}"
    OVMF_TEMPLATE="${VERTEX_OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}"

    if [ -f "$OVMF_CODE" ] && [ -f "$OVMF_TEMPLATE" ]; then
        [ -f "$OVMF_VARS" ] || cp "$OVMF_TEMPLATE" "$OVMF_VARS"
        FIRMWARE_ARGS=(
            -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
            -drive "if=pflash,format=raw,file=$OVMF_VARS"
        )
        BOOT_ARGS=(
            -cdrom "$UEFI_ISO"
            -boot "order=d,menu=off,strict=on"
        )
    else
        printf '[vertexos-smoke] UEFI firmware not found; falling back to direct BIOS boot.\n'
    fi
fi

if [ "${#BOOT_ARGS[@]}" -eq 0 ]; then
    BOOT_ARGS=(
        -kernel "$KERNEL"
        -initrd "$INITRAMFS"
        -append "$APPEND"
        -boot "menu=off,strict=on"
    )
fi

if [ "$DISPLAY_MODE" = "none" ]; then
    exec qemu-system-x86_64 \
        "${ACCEL_ARGS[@]}" \
        "${CPU_ARGS[@]}" \
        "${FIRMWARE_ARGS[@]}" \
        -m "${VERTEX_QEMU_MEMORY:-768M}" \
        -smp "${VERTEX_QEMU_CPUS:-2}" \
        -machine "$MACHINE" \
        "${BOOT_ARGS[@]}" \
        -drive "file=$DISK,if=virtio,format=raw,cache=writeback,discard=unmap" \
        -net none \
        -display none \
        -serial stdio \
        -monitor none \
        -no-reboot
fi

QEMU_CMD=(
    qemu-system-x86_64
    "${ACCEL_ARGS[@]}"
    "${CPU_ARGS[@]}"
    "${FIRMWARE_ARGS[@]}"
    -m "${VERTEX_QEMU_MEMORY:-768M}"
    -smp "${VERTEX_QEMU_CPUS:-2}"
    -machine "$MACHINE"
    "${BOOT_ARGS[@]}"
    -drive "file=$DISK,if=virtio,format=raw,cache=writeback,discard=unmap"
    -net none
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
printf '[vertexos-smoke] Firmware mode: %s\n' "${VERTEX_QEMU_FIRMWARE:-direct}"
printf '[vertexos-smoke] Disk image: %s\n' "$DISK"
printf '[vertexos-smoke] Log: %s\n' "$LOG_FILE"
