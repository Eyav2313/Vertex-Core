#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HTML_OUT="$ROOT_DIR/out/html-lock"
USB_OUT="$ROOT_DIR/out/usb"
WORK_DIR="${VERTEX_USB_WORK_DIR:-/var/tmp/vertex-usb-live}"

ROOTFS_IMAGE="${VERTEX_ROOTFS_IMAGE:-$HTML_OUT/vertex-html-lock-rootfs.ext4}"
KERNEL_IMAGE="${VERTEX_KERNEL_IMAGE:-$HTML_OUT/vertex-html-lock-vmlinuz}"
INITRD_IMAGE="${VERTEX_INITRD_IMAGE:-$HTML_OUT/vertex-html-lock-initrd.img}"
GRUB_CFG_TEMPLATE="$ROOT_DIR/config/boot/grub/vertex-usb-grub.cfg"

IMAGE="${VERTEX_USB_IMAGE:-$USB_OUT/Vertex-live-usb.img}"
IMAGE_WORK="$WORK_DIR/Vertex-live-usb.img"
IMAGE_SIZE="${VERTEX_USB_IMAGE_SIZE:-4G}"
ESP_LABEL="${VERTEX_USB_ESP_LABEL:-VERTEXBOOT}"
ROOT_LABEL="${VERTEX_USB_ROOT_LABEL:-VertexLiveRoot}"

SRC_MNT="$WORK_DIR/source-rootfs"
ESP_MNT="$WORK_DIR/esp"
ROOT_MNT="$WORK_DIR/root"
GRUB_WORK="$WORK_DIR/grub"
LOOP_DEV=""

info() {
    printf '[vertex-usb] %s\n' "$*"
}

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
    mountpoint -q "$ROOT_MNT" && umount "$ROOT_MNT"
    mountpoint -q "$SRC_MNT" && umount "$SRC_MNT"
    if [ -n "$LOOP_DEV" ]; then
        losetup -d "$LOOP_DEV" >/dev/null 2>&1
    fi
}
trap cleanup EXIT

require parted
require losetup
require mkfs.vfat
require mkfs.ext4
require mount
require umount
require rsync
require grub-mkstandalone

[ -f "$ROOTFS_IMAGE" ] || die "Missing rootfs image: $ROOTFS_IMAGE. Run scripts/build-html-lock-os.sh first."
[ -f "$KERNEL_IMAGE" ] || die "Missing kernel image: $KERNEL_IMAGE. Run scripts/build-html-lock-os.sh first."
[ -f "$INITRD_IMAGE" ] || die "Missing initrd image: $INITRD_IMAGE. Run scripts/build-html-lock-os.sh first."
[ -f "$GRUB_CFG_TEMPLATE" ] || die "Missing GRUB config template: $GRUB_CFG_TEMPLATE"

mkdir -p "$USB_OUT" "$WORK_DIR" "$SRC_MNT" "$ESP_MNT" "$ROOT_MNT" "$GRUB_WORK"

info "Creating sparse USB image: $IMAGE ($IMAGE_SIZE)."
rm -f "$IMAGE_WORK" "$IMAGE"
truncate -s "$IMAGE_SIZE" "$IMAGE_WORK"

parted -s "$IMAGE_WORK" mklabel gpt
parted -s "$IMAGE_WORK" mkpart ESP fat32 1MiB 513MiB
parted -s "$IMAGE_WORK" set 1 esp on
parted -s "$IMAGE_WORK" name 1 VertexEFI
parted -s "$IMAGE_WORK" mkpart VertexRoot ext4 513MiB 100%
parted -s "$IMAGE_WORK" name 2 VertexRoot

LOOP_DEV="$(losetup --show -fP "$IMAGE_WORK")"
ESP_PART="$(part_path "$LOOP_DEV" 1)"
ROOT_PART="$(part_path "$LOOP_DEV" 2)"

for _ in $(seq 1 40); do
    [ -b "$ESP_PART" ] && [ -b "$ROOT_PART" ] && break
    sleep 0.25
done
[ -b "$ESP_PART" ] || die "Loop partition did not appear: $ESP_PART"
[ -b "$ROOT_PART" ] || die "Loop partition did not appear: $ROOT_PART"

info "Formatting EFI and root partitions."
mkfs.vfat -F 32 -n "$ESP_LABEL" "$ESP_PART" >/dev/null
mkfs.ext4 -q -F -L "$ROOT_LABEL" "$ROOT_PART"

info "Copying Vertex root filesystem into the USB image."
mount -o loop,ro "$ROOTFS_IMAGE" "$SRC_MNT"
mount "$ROOT_PART" "$ROOT_MNT"
rsync -aH --numeric-ids --delete "$SRC_MNT"/ "$ROOT_MNT"/

mkdir -p "$ROOT_MNT/boot/efi"
cat > "$ROOT_MNT/etc/fstab" <<EOF
LABEL=$ROOT_LABEL / ext4 defaults,noatime 0 1
LABEL=$ESP_LABEL /boot/efi vfat umask=0077 0 1
EOF

info "Installing UEFI boot files."
mount "$ESP_PART" "$ESP_MNT"
mkdir -p "$ESP_MNT/EFI/BOOT" "$ESP_MNT/boot/vertex" "$ESP_MNT/boot/grub/fonts"
cp "$KERNEL_IMAGE" "$ESP_MNT/boot/vertex/vmlinuz"
cp "$INITRD_IMAGE" "$ESP_MNT/boot/vertex/initrd.img"
cp "$GRUB_CFG_TEMPLATE" "$ESP_MNT/boot/grub/grub.cfg"

if [ -f /usr/share/grub/unicode.pf2 ]; then
    cp /usr/share/grub/unicode.pf2 "$ESP_MNT/boot/grub/fonts/unicode.pf2"
fi
if command -v grub-mkfont >/dev/null 2>&1; then
    FONT_SOURCE="/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
    [ -f /usr/share/fonts/truetype/ubuntu/UbuntuMono-R.ttf ] && FONT_SOURCE="/usr/share/fonts/truetype/ubuntu/UbuntuMono-R.ttf"
    [ -f /mnt/c/Windows/Fonts/CascadiaMono.ttf ] && FONT_SOURCE="/mnt/c/Windows/Fonts/CascadiaMono.ttf"
    if [ -f "$FONT_SOURCE" ]; then
        grub-mkfont -s 22 -o "$ESP_MNT/boot/grub/fonts/vertex-boot.pf2" "$FONT_SOURCE"
    fi
fi

cat > "$GRUB_WORK/embedded.cfg" <<EOF
search --no-floppy --label $ESP_LABEL --set=root
set prefix=(\$root)/boot/grub
configfile /boot/grub/grub.cfg
EOF

grub-mkstandalone \
    -O x86_64-efi \
    -o "$ESP_MNT/EFI/BOOT/BOOTX64.EFI" \
    --modules="part_gpt fat ext2 normal linux search search_label configfile reboot halt efifwsetup echo sleep read test all_video gfxterm font" \
    "boot/grub/grub.cfg=$GRUB_WORK/embedded.cfg"

cat > "$ESP_MNT/README.txt" <<'EOF'
Vertex UEFI Live Media

This drive boots Vertex from the UEFI removable media path:

  EFI/BOOT/BOOTX64.EFI

Select "Start Vertex" from the boot manager to start the live desktop.
EOF

sync
umount "$ESP_MNT"
umount "$ROOT_MNT"
umount "$SRC_MNT"
losetup -d "$LOOP_DEV"
LOOP_DEV=""

cp --sparse=always "$IMAGE_WORK" "$IMAGE"
rm -f "$IMAGE_WORK"

cat > "$USB_OUT/README.txt" <<EOF
Vertex live USB image

Image:
  $IMAGE

Minimum pendrive:
  4 GB required, 8 GB recommended

Linux flash command:
  sudo VERTEX_WRITE_USB_CONFIRM=YES scripts/write-usb-live.sh /dev/sdX

Windows:
  Use Rufus or balenaEtcher and select:
    $IMAGE

Boot:
  Reboot PC -> firmware boot menu -> select the USB drive -> Start Vertex
EOF

info "Created $IMAGE"
info "Flash it to a 4 GB or larger USB drive with Rufus, Etcher, or scripts/write-usb-live.sh."
