#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out/html-lock"
WORK_DIR="${VERTEX_HTML_LOCK_WORK_DIR:-/var/tmp/vertex-html-lock}"
ROOTFS="$WORK_DIR/rootfs"
IMAGE="$OUT_DIR/vertex-html-lock-rootfs.ext4"
KERNEL_OUT="$OUT_DIR/vertex-html-lock-vmlinuz"
INITRD_OUT="$OUT_DIR/vertex-html-lock-initrd.img"
LOG_DIR="$ROOT_DIR/build/logs"

SUITE="${VERTEX_HTML_LOCK_SUITE:-trixie}"
MIRROR="${VERTEX_HTML_LOCK_MIRROR:-http://deb.debian.org/debian}"
DISK_SIZE="${VERTEX_HTML_LOCK_DISK_SIZE:-3G}"
IMAGE_WORK="$WORK_DIR/vertex-html-lock-rootfs.ext4"

PACKAGES=(
    systemd-sysv
    dbus
    udev
    iproute2
    network-manager
    wireless-tools
    linux-image-amd64
    initramfs-tools
    ca-certificates
    tzdata
    chromium
    alsa-utils
    xserver-xorg-core
    xserver-xorg-video-vesa
    xserver-xorg-video-fbdev
    xserver-xorg-input-libinput
    x11-xserver-utils
    xinit
    fonts-dejavu-core
    fonts-liberation
    fonts-inter
    fonts-manrope
    fontconfig
)

info() {
    printf '[vertex-html-lock] %s\n' "$*"
}

die() {
    printf '[vertex-html-lock] %s\n' "$*" >&2
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

install_tree() {
    local src="$1"
    local dest="$2"

    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a "$src"/. "$dest"/
}

configure_rootfs() {
    info "Installing Vertex HTML lock screen files."
    mkdir -p \
        "$ROOTFS/usr/share/vertex/preview" \
        "$ROOTFS/usr/share/vertex/assets" \
        "$ROOTFS/usr/share/fonts/truetype/vertex" \
        "$ROOTFS/usr/local/bin" \
        "$ROOTFS/etc/systemd/system/multi-user.target.wants" \
        "$ROOTFS/etc/X11/xorg.conf.d" \
        "$ROOTFS/var/log/vertex"

    install_tree "$ROOT_DIR/preview" "$ROOTFS/usr/share/vertex/preview"
    install_tree "$ROOT_DIR/assets" "$ROOTFS/usr/share/vertex/assets"
    install -m 0644 "$ROOT_DIR/assets/fonts/space-grotesk/SpaceGrotesk-Variable.ttf" \
        "$ROOTFS/usr/share/fonts/truetype/vertex/SpaceGrotesk-Variable.ttf"
    chroot "$ROOTFS" fc-cache -f >/dev/null 2>&1 || true

    cat > "$ROOTFS/etc/hostname" <<'EOF'
Vertex
EOF

    cat > "$ROOTFS/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 Vertex
EOF

    if [ ! -f "$ROOTFS/usr/share/zoneinfo/Asia/Dhaka" ] && [ -f /usr/share/zoneinfo/Asia/Dhaka ]; then
        mkdir -p "$ROOTFS/usr/share/zoneinfo/Asia"
        cp /usr/share/zoneinfo/Asia/Dhaka "$ROOTFS/usr/share/zoneinfo/Asia/Dhaka"
    fi
    ln -snf /usr/share/zoneinfo/Asia/Dhaka "$ROOTFS/etc/localtime"
    cat > "$ROOTFS/etc/timezone" <<'EOF'
Asia/Dhaka
EOF

    cat > "$ROOTFS/etc/X11/xorg.conf.d/20-Vertex-kiosk.conf" <<'EOF'
Section "ServerFlags"
    Option "DontVTSwitch" "true"
    Option "DontZap" "true"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection

Section "Monitor"
    Identifier "VertexDisplay"
    Option "DPMS" "false"
EndSection
EOF

    cat > "$ROOTFS/usr/local/bin/vertex-lockscreen-session" <<'EOF'
#!/bin/sh
set -eu

export HOME=/root
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/vertex-lock
export CHROME_DEVEL_SANDBOX=/usr/lib/chromium/chrome-sandbox

mkdir -p "$XDG_RUNTIME_DIR" /tmp/vertex-chromium /var/log/vertex
chmod 700 "$XDG_RUNTIME_DIR"
rm -f /tmp/.X0-lock

if ! pgrep -x Xorg >/dev/null 2>&1; then
    /usr/lib/xorg/Xorg :0 vt1 -nolisten tcp -s 0 -dpms -noreset \
        > /var/log/vertex/xorg.log 2>&1 &
fi

for _ in $(seq 1 80); do
    [ -S /tmp/.X11-unix/X0 ] && break
    sleep 0.25
done

xset s off >/dev/null 2>&1 || true
xset -dpms >/dev/null 2>&1 || true

OUTPUT="$(xrandr --query 2>/dev/null | awk '/ connected/{print $1; exit}')"
if [ -n "$OUTPUT" ]; then
    xrandr --output "$OUTPUT" --mode "${VERTEX_LOCKSCREEN_MODE:-1280x720}" >/dev/null 2>&1 || \
        xrandr --output "$OUTPUT" --auto >/dev/null 2>&1 || true
fi

CHROMIUM="$(command -v chromium || command -v chromium-browser || true)"
[ -n "$CHROMIUM" ] || {
    echo "chromium is not installed" >&2
    sleep 5
    exit 1
}

exec "$CHROMIUM" \
    --kiosk \
    --start-fullscreen \
    --no-sandbox \
    --no-first-run \
    --autoplay-policy=no-user-gesture-required \
    --disable-infobars \
    --disable-translate \
    --disable-background-networking \
    --disable-component-update \
    --disable-renderer-backgrounding \
    --disable-background-timer-throttling \
    --disable-features=TranslateUI,MediaRouter,OptimizationHints \
    --hide-scrollbars \
    --window-size="${VERTEX_LOCKSCREEN_WIDTH:-1280},${VERTEX_LOCKSCREEN_HEIGHT:-720}" \
    --force-device-scale-factor=1 \
    --overscroll-history-navigation=0 \
    --user-data-dir=/tmp/vertex-chromium \
    file:///usr/share/vertex/preview/desktop/index.html \
    >> /var/log/vertex/chromium.log 2>&1
EOF
    install -m 0755 "$ROOT_DIR/scripts/vertex-lockscreen-session.sh" \
        "$ROOTFS/usr/local/bin/vertex-lockscreen-session"

    cat > "$ROOTFS/etc/systemd/system/vertex-lockscreen.service" <<'EOF'
[Unit]
Description=Vertex real HTML/CSS/JS lock screen
After=systemd-user-sessions.service dbus.service
Wants=dbus.service
Conflicts=getty@tty1.service

[Service]
Type=simple
Environment=HOME=/root
Environment=XDG_RUNTIME_DIR=/run/vertex-lock
TTYPath=/dev/tty1
StandardInput=tty
StandardOutput=journal
StandardError=journal
ExecStart=/usr/local/bin/vertex-lockscreen-session
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

    ln -sf /etc/systemd/system/vertex-lockscreen.service \
        "$ROOTFS/etc/systemd/system/multi-user.target.wants/vertex-lockscreen.service"
    ln -sf /dev/null "$ROOTFS/etc/systemd/system/getty@tty1.service"
}

require mmdebstrap
require debootstrap
require mkfs.ext4
require find
require cp

mkdir -p "$OUT_DIR" "$LOG_DIR" "$WORK_DIR"

if [ "${VERTEX_HTML_LOCK_REBUILD:-0}" = "1" ] || [ ! -d "$ROOTFS" ]; then
    info "Creating Debian $SUITE root filesystem with Chromium and Xorg."
    rm -rf "$ROOTFS"
    INCLUDE_PACKAGES="$(IFS=,; printf '%s' "${PACKAGES[*]}")"
    if ! mmdebstrap \
        --variant=important \
        --aptopt='Apt::Install-Recommends "false"' \
        --include="$INCLUDE_PACKAGES" \
        "$SUITE" "$ROOTFS" "$MIRROR"; then
        info "mmdebstrap failed; retrying with debootstrap."
        rm -rf "$ROOTFS"
        debootstrap \
            --arch=amd64 \
            --variant=minbase \
            --include="$INCLUDE_PACKAGES" \
            --keyring=/usr/share/keyrings/debian-archive-keyring.gpg \
            "$SUITE" "$ROOTFS" "$MIRROR"
    fi
else
    info "Reusing existing root filesystem at $ROOTFS."
fi

configure_rootfs

KERNEL_IMAGE="$(find "$ROOTFS/boot" -maxdepth 1 -type f -name 'vmlinuz-*' | sort -V | tail -n 1)"
INITRD_IMAGE="$(find "$ROOTFS/boot" -maxdepth 1 -type f -name 'initrd.img-*' | sort -V | tail -n 1)"
[ -n "$KERNEL_IMAGE" ] || die "No kernel image found in $ROOTFS/boot"
[ -n "$INITRD_IMAGE" ] || die "No initrd image found in $ROOTFS/boot"

cp "$KERNEL_IMAGE" "$KERNEL_OUT"
cp "$INITRD_IMAGE" "$INITRD_OUT"

info "Creating ext4 root disk image: $IMAGE ($DISK_SIZE)."
rm -f "$IMAGE_WORK" "$IMAGE"
truncate -s "$DISK_SIZE" "$IMAGE_WORK"
mkfs.ext4 -q -F -L VertexLock -d "$ROOTFS" "$IMAGE_WORK"
cp --sparse=always "$IMAGE_WORK" "$IMAGE"
if [ "${VERTEX_HTML_LOCK_KEEP_WORK_IMAGE:-0}" != "1" ]; then
    rm -f "$IMAGE_WORK"
fi

cat > "$OUT_DIR/README.txt" <<EOF
Vertex real HTML lock screen VM

This image boots Linux, starts systemd, launches Xorg, and runs Chromium in
kiosk mode with:

  file:///usr/share/vertex/preview/desktop/index.html

Artifacts:
  Kernel: $KERNEL_OUT
  Initrd: $INITRD_OUT
  Rootfs: $IMAGE

Run on Windows:
  powershell -ExecutionPolicy Bypass -File scripts\\run-html-lock-os.ps1
EOF

info "Created $KERNEL_OUT"
info "Created $INITRD_OUT"
info "Created $IMAGE"
