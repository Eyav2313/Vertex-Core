#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${VERTEX_USB_IMAGE:-$ROOT_DIR/out/usb/Vertex-OS-Live-USB-x86_64-BIOS-UEFI.img}"
GRUB_CFG_TEMPLATE="$ROOT_DIR/config/boot/grub/vertex-usb-grub.cfg"
GRUB_THEME_DIR="$ROOT_DIR/config/boot/grub/themes/vertex"
WORK_DIR="${VERTEX_USB_WORK_DIR:-/var/tmp/vertex-usb-live}"
ESP_MNT="$WORK_DIR/esp-update"
GRUB_WORK="$WORK_DIR/grub-update"
ESP_LABEL="${VERTEX_USB_ESP_LABEL:-VERTEXBOOT}"
KERNEL_IMAGE="${VERTEX_KERNEL_IMAGE:-$ROOT_DIR/out/html-lock/vertex-html-lock-vmlinuz}"
INITRD_IMAGE="${VERTEX_INITRD_IMAGE:-$ROOT_DIR/out/html-lock/vertex-html-lock-initrd.img}"
LOOP_DEV=""

die() {
    printf '[vertex-usb] %s\n' "$*" >&2
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

part_path() {
    case "$1" in
        /dev/loop*) printf '%sp%s' "$1" "$2" ;;
        *) printf '%s%s' "$1" "$2" ;;
    esac
}

cleanup() {
    set +e
    mountpoint -q "$ESP_MNT" && umount "$ESP_MNT"
    if [ -n "$LOOP_DEV" ]; then
        losetup -d "$LOOP_DEV" >/dev/null 2>&1
    fi
}
trap cleanup EXIT

require losetup
require mount
require umount
require grub-install
require grub-mkstandalone

[ -f "$IMAGE" ] || die "Missing USB image: $IMAGE. Run scripts/build-usb-live.sh first."
[ -f "$GRUB_CFG_TEMPLATE" ] || die "Missing GRUB config: $GRUB_CFG_TEMPLATE"
[ -f "$KERNEL_IMAGE" ] || die "Missing kernel image: $KERNEL_IMAGE"
[ -f "$INITRD_IMAGE" ] || die "Missing initrd image: $INITRD_IMAGE"

mkdir -p "$ESP_MNT" "$GRUB_WORK"
LOOP_DEV="$(losetup --show -fP "$IMAGE")"
if [ -b "$(part_path "$LOOP_DEV" 2)" ]; then
    ESP_PART="$(part_path "$LOOP_DEV" 2)"
else
    ESP_PART="$(part_path "$LOOP_DEV" 1)"
fi

for _ in $(seq 1 40); do
    [ -b "$ESP_PART" ] && break
    sleep 0.25
done
[ -b "$ESP_PART" ] || die "Loop partition did not appear: $ESP_PART"

mount "$ESP_PART" "$ESP_MNT"
mkdir -p "$ESP_MNT/EFI/BOOT" "$ESP_MNT/boot/vertex" "$ESP_MNT/boot/grub/fonts" "$ESP_MNT/boot/grub/themes/vertex" "$ESP_MNT/boot/grub/x86_64-efi"
cp "$KERNEL_IMAGE" "$ESP_MNT/boot/vertex/vmlinuz"
cp "$INITRD_IMAGE" "$ESP_MNT/boot/vertex/initrd.img"
cp "$GRUB_CFG_TEMPLATE" "$ESP_MNT/boot/grub/grub.cfg"
if [ -f /usr/share/grub/unicode.pf2 ]; then
    cp /usr/share/grub/unicode.pf2 "$ESP_MNT/boot/grub/fonts/unicode.pf2"
fi
for module in bitmap bufio png; do
    if [ -f "/usr/lib/grub/x86_64-efi/${module}.mod" ]; then
        cp "/usr/lib/grub/x86_64-efi/${module}.mod" "$ESP_MNT/boot/grub/x86_64-efi/${module}.mod"
    fi
done
if [ -d "$GRUB_THEME_DIR" ]; then
    cp -r "$GRUB_THEME_DIR"/. "$ESP_MNT/boot/grub/themes/vertex/"
fi

cat > "$GRUB_WORK/embedded.cfg" <<EOF
search --no-floppy --label $ESP_LABEL --set=root
set prefix=(\$root)/boot/grub
configfile /boot/grub/grub.cfg
EOF

grub-mkstandalone \
    -O x86_64-efi \
    -o "$ESP_MNT/EFI/BOOT/BOOTX64.EFI" \
    --modules="all_video efi_gop efi_uga font gfxterm gfxmenu png part_gpt fat ext2 normal linux gzio search search_label configfile reboot halt efifwsetup echo sleep read test" \
    "boot/grub/grub.cfg=$GRUB_WORK/embedded.cfg"

if [ -b "$(part_path "$LOOP_DEV" 1)" ] && parted -s "$LOOP_DEV" print 2>/dev/null | grep -q 'bios_grub'; then
    grub-install \
        --target=i386-pc \
        --boot-directory="$ESP_MNT/boot" \
        --modules="all_video vbe vga video_bochs video_cirrus font gfxterm gfxmenu png bitmap bufio part_gpt fat ext2 normal linux gzio search search_label configfile reboot halt echo sleep test" \
        --recheck \
        --force \
        "$LOOP_DEV" >/dev/null
fi

cat > "$ESP_MNT/startup.nsh" <<'EOF'
fs0:
\EFI\BOOT\BOOTX64.EFI
EOF

sync
printf '[vertex-usb] Updated EFI boot files in %s\n' "$IMAGE"
