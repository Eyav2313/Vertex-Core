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
    sleep 0.15
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
    --disable-gpu \
    --disable-gpu-compositing \
    --disable-accelerated-2d-canvas \
    --disable-zero-copy \
    --disable-dev-shm-usage \
    --disable-features=TranslateUI \
    --hide-scrollbars \
    --window-size=1280,720 \
    --force-device-scale-factor=1 \
    --overscroll-history-navigation=0 \
    --user-data-dir=/tmp/vertex-chromium \
    file:///usr/share/vertex/preview/desktop/index.html \
    >> /var/log/vertex/chromium.log 2>&1
