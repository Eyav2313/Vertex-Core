# VertexOS Architecture

## Base

VertexOS is a Debian Stable derivative, not a generic respin. Debian provides the base operating system, security update cadence, package format, and initial root filesystem. VertexOS owns the experience layer, system profiles, package selection, kernel policy, installation flow, and custom package repository.

The default engineering priority is performance first, stability second, and visual polish third. Premium UI effects are treated as optional profiles, not mandatory system behavior.

### Why Debian Stable

- Stability is prioritized over novelty.
- APT/dpkg gives predictable packaging and upgrade behavior.
- Security updates and long maintenance windows reduce operational risk.
- `mmdebstrap` and `live-build` provide practical paths to reproducible images.
- Backports and a VertexOS repository allow selective modernization without turning the whole OS into a rolling target.

## Release Model

- `stable`: daily-driver channel, conservative updates.
- `testing`: candidate images and desktop stack validation.
- `edge`: compositor, kernel, and graphics experiments.

Every package promoted to `stable` should pass boot, login, graphical session, update, rollback, and suspend/resume checks.

## Core Components

| Layer | Component | VertexOS Policy |
| --- | --- | --- |
| Kernel | Linux LTS-derived desktop flavor | Preemptible desktop responsiveness, modern GPU support, Btrfs/EXT4, zstd, eBPF diagnostics |
| Boot | systemd-boot first, GRUB fallback | UEFI first, Secure Boot support planned |
| Init | systemd | Use upstream service units unless VertexOS needs explicit policy |
| Packages | APT/dpkg | Debian archive plus signed VertexOS repo |
| Rootfs | mmdebstrap | Minimal rootfs, profile-driven package inclusion |
| Images | live-build | ISO creation and installer media |
| Display | Wayland + Xwayland | Wayland native, X11 compatibility only where needed |
| Display manager | SDDM | QML theme with glass panel and clean login flow |
| Compositor | Hyprland/wlroots | Pinned builds, performance default profile, optional glass profile |
| Audio | PipeWire + WirePlumber | Low-latency desktop audio and screen sharing compatibility |
| Network | NetworkManager | Reliable laptop-first networking |
| Security | AppArmor, nftables, Polkit | Secure defaults without noisy friction |

## Filesystem Layout

Default installation target:

- `/`: Btrfs root with zstd compression.
- `/home`: separate Btrfs subvolume.
- `/.snapshots`: rollback-ready subvolume.
- `/var/log`: separate subvolume to avoid noisy snapshot churn.
- EFI System Partition mounted at `/boot/efi`.

EXT4 remains the fallback for conservative installs and constrained devices.

## Performance Policy

VertexOS optimizes for interactive latency before synthetic throughput. The target is a desktop that feels instant under real user pressure:

- Preemptible kernel configuration.
- `schedutil` CPU governor by default, with an explicit performance mode available.
- zram plus zswap-ready kernel support for memory pressure resilience.
- Low-cost compositor defaults: opaque windows, no blur, no shadow, minimal animation.
- Optional glass compositor profile for systems with enough GPU headroom.
- NVMe/SATA IO scheduler policy through udev rules.
- BBR/FQ network tuning when supported by the kernel.
- No always-on background indexers unless the user enables them.
- Package profiles remain explicit and small.

## Stability Policy

- Pin compositor, display manager theme runtime, graphics stack, and kernel ABI per release.
- Avoid replacing core Debian services without a measurable reason.
- Treat theme and desktop effects as configurable layers, not hard dependencies.
- Keep emergency TTY, recovery boot entry, and package rollback paths available.
