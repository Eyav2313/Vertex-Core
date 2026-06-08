#!/bin/sh
set -eu

export HOME=/root
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/vertex-lock
export CHROME_DEVEL_SANDBOX=/usr/lib/chromium/chrome-sandbox

mkdir -p "$XDG_RUNTIME_DIR" /tmp/vertex-chromium /var/log/vertex
chmod 700 "$XDG_RUNTIME_DIR"
rm -f /tmp/.X0-lock

write_system_info() {
    INFO_JS=/usr/share/vertex/preview/desktop/system-info.js
    mkdir -p "$(dirname "$INFO_JS")"

    json_escape() {
        printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
    }

    CPU="$(awk -F: '/model name/{gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
    [ -n "$CPU" ] || CPU="$(nproc 2>/dev/null || echo 1) threads"
    MEMORY="$(awk '/MemTotal/{printf "%.1f GB", $2/1048576}' /proc/meminfo 2>/dev/null || true)"
    [ -n "$MEMORY" ] || MEMORY="unknown"
    DISK="$(df -h / 2>/dev/null | awk 'NR==2{print $4 " free / " $2}' || true)"
    [ -n "$DISK" ] || DISK="unknown"
    KERNEL="$(uname -sr 2>/dev/null || echo Linux)"
    PLATFORM="$(uname -m 2>/dev/null || echo amd64)"
    DISPLAY_SIZE="${VERTEX_LOCKSCREEN_WIDTH:-1920} x ${VERTEX_LOCKSCREEN_HEIGHT:-1080}"

    BATTERY="AC / unknown"
    BATTERY_PERCENT=""
    for BAT in /sys/class/power_supply/BAT*; do
        [ -d "$BAT" ] || continue
        CAP="$(cat "$BAT/capacity" 2>/dev/null || true)"
        STAT="$(cat "$BAT/status" 2>/dev/null || true)"
        if [ -n "$CAP" ]; then
            BATTERY="$CAP%${STAT:+, $STAT}"
            BATTERY_PERCENT="$CAP"
            break
        fi
    done

    NETWORK_CONNECTED=false
    NETWORK_NAME=""
    if command -v ip >/dev/null 2>&1 && ip route show default >/dev/null 2>&1; then
        NETWORK_CONNECTED=true
    fi
    if command -v nmcli >/dev/null 2>&1; then
        NETWORK_NAME="$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')"
        [ -n "$NETWORK_NAME" ] || NETWORK_NAME="$(nmcli -t -f NAME connection show --active 2>/dev/null | head -n 1)"
    elif command -v iwgetid >/dev/null 2>&1; then
        NETWORK_NAME="$(iwgetid -r 2>/dev/null || true)"
    fi
    [ -n "$NETWORK_NAME" ] || [ "$NETWORK_CONNECTED" = false ] || NETWORK_NAME="Connected network"

    {
        printf 'window.VERTEX_SYSTEM_INFO = {\n'
        printf '  cpu: "%s",\n' "$(json_escape "$CPU")"
        printf '  memory: "%s",\n' "$(json_escape "$MEMORY")"
        printf '  disk: "%s",\n' "$(json_escape "$DISK")"
        printf '  battery: "%s",\n' "$(json_escape "$BATTERY")"
        if [ -n "$BATTERY_PERCENT" ]; then
            printf '  batteryPercent: %s,\n' "$BATTERY_PERCENT"
        else
            printf '  batteryPercent: null,\n'
        fi
        printf '  kernel: "%s",\n' "$(json_escape "$KERNEL")"
        printf '  platform: "%s",\n' "$(json_escape "$PLATFORM")"
        printf '  display: "%s",\n' "$(json_escape "$DISPLAY_SIZE")"
        printf '  network: { connected: %s, name: "%s" },\n' "$NETWORK_CONNECTED" "$(json_escape "$NETWORK_NAME")"
        printf '  networks: [\n'
        FIRST=1
        if command -v nmcli >/dev/null 2>&1; then
            nmcli -t -f SSID,SIGNAL dev wifi list --rescan no 2>/dev/null | awk -F: '$1!="" && !seen[$1]++{print $1 "|" $2}' | while IFS='|' read -r SSID SIGNAL; do
                [ -n "$SSID" ] || continue
                if [ "$FIRST" -eq 0 ]; then printf ',\n'; fi
                FIRST=0
                STATUS="${SIGNAL:+${SIGNAL}%}"
                [ "$SSID" = "$NETWORK_NAME" ] && STATUS="connected"
                printf '    { name: "%s", status: "%s" }' "$(json_escape "$SSID")" "$(json_escape "$STATUS")"
            done
        elif [ -n "$NETWORK_NAME" ]; then
            printf '    { name: "%s", status: "connected" }' "$(json_escape "$NETWORK_NAME")"
        fi
        printf '\n  ]\n'
        printf '};\n'
    } > "$INFO_JS"
}

write_system_info || true

if ! pgrep -x Xorg >/dev/null 2>&1; then
    /usr/lib/xorg/Xorg :0 vt1 -nolisten tcp -s 0 -dpms -noreset \
        > /var/log/vertex/xorg.log 2>&1 &
fi

for _ in $(seq 1 80); do
    [ -S /tmp/.X11-unix/X0 ] && break
    sleep 0.15
done

for _ in $(seq 1 80); do
    DISPLAY=:0 xset q >/dev/null 2>&1 && break
    sleep 0.15
done

if command -v chvt >/dev/null 2>&1; then
    chvt 1 >/dev/null 2>&1 || true
fi

xset s off >/dev/null 2>&1 || true
xset -dpms >/dev/null 2>&1 || true

OUTPUT="$(xrandr --query 2>/dev/null | awk '/ connected/{print $1; exit}')"
if [ -n "$OUTPUT" ]; then
    xrandr --output "$OUTPUT" --mode "${VERTEX_LOCKSCREEN_MODE:-1920x1080}" >/dev/null 2>&1 || \
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
    --window-size="${VERTEX_LOCKSCREEN_WIDTH:-1920},${VERTEX_LOCKSCREEN_HEIGHT:-1080}" \
    --force-device-scale-factor=1 \
    --overscroll-history-navigation=0 \
    --user-data-dir=/tmp/vertex-chromium \
    file:///usr/share/vertex/preview/desktop/index.html \
    >> /var/log/vertex/chromium.log 2>&1
