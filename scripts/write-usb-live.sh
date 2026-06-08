#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${VERTEX_USB_IMAGE:-$ROOT_DIR/out/usb/Vertex-OS-Live-USB-x86_64-UEFI.img}"
DEVICE="${1:-}"

die() {
    printf '[vertex-usb-write] %s\n' "$*" >&2
    exit 1
}

[ -n "$DEVICE" ] || die "Usage: sudo VERTEX_WRITE_USB_CONFIRM=YES scripts/write-usb-live.sh /dev/sdX"
[ -f "$IMAGE" ] || die "Missing image: $IMAGE. Run scripts/build-usb-live.sh first."
[ -b "$DEVICE" ] || die "Not a block device: $DEVICE"
[ "${VERTEX_WRITE_USB_CONFIRM:-}" = "YES" ] || die "Refusing to write without VERTEX_WRITE_USB_CONFIRM=YES"

case "$DEVICE" in
    /dev/sd?|/dev/nvme?n?|/dev/vd?) ;;
    *) die "Pass the whole disk device, not a partition. Example: /dev/sdb" ;;
esac

printf '[vertex-usb-write] Target device:\n'
lsblk "$DEVICE"
printf '[vertex-usb-write] Writing %s to %s. This destroys existing data on the target.\n' "$IMAGE" "$DEVICE"

sync
dd if="$IMAGE" of="$DEVICE" bs=16M status=progress conv=fsync
sync

printf '[vertex-usb-write] Done. Safely eject the USB drive before booting.\n'
