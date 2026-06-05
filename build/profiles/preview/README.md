# Preview Build Profile

Fast visual preview profile for early Vertex ISO testing.

This profile intentionally uses the same package manifest as `desktop`, but it is intended to be run with:

```sh
VERTEX_SUITE=forky VERTEX_ENABLE_BACKPORTS=0 VERTEX_SKIP_KERNEL=1 bash build-vertex.sh
```

Reason: Debian Trixie Stable does not ship Hyprland in main. Hyprland is available through Trixie backports, but the compositor dependency chain may require newer libraries than a plain Trixie rootfs provides. The preview profile lets us inspect the GUI quickly while the stable packaging strategy is refined.
