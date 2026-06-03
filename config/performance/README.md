# Vertex Performance Profile

This folder contains performance-first defaults for Vertex OS. These settings are intentionally modular so the distro can ship a fast default while still offering a premium glass profile for stronger GPUs.

## Default Policy

- Prefer input latency and responsiveness over decorative effects.
- Use zram to reduce stalls during memory pressure.
- Prefer `schedutil` for balanced responsiveness, with explicit performance mode support.
- Disable compositor blur/shadows in the default performance profile.
- Use IO scheduler rules suitable for NVMe and SATA devices.
- Enable BBR/FQ network tuning where kernel support exists.

## Install Targets

- `zram-tools/zramswap`: install to `/etc/default/zramswap`.
- `udev/rules.d/60-vertex-io-scheduler.rules`: install to `/etc/udev/rules.d/`.
- `systemd/vertex-performance.service`: install to `/etc/systemd/system/` and enable only for performance-first images.
