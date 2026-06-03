# Vertex OS

Developer: Nuren Zarif Haque

Vertex OS is a Linux-kernel based desktop distribution focused on three priorities:

1. Premium visual quality with a restrained glassmorphism interface.
2. Stability through a conservative base and pinned release channels.
3. Fast interactive performance for modern laptops and workstations.

## Base Decision

Vertex OS starts as a Debian Stable derivative with curated backports and a signed Vertex package repository.

This gives Vertex a stable package and security foundation while leaving the desktop, kernel policy, artwork, system tooling, and installation experience under Vertex control. The first build path targets `mmdebstrap` plus `live-build` for reproducible root filesystems and ISO images.

## Core Stack

- Kernel: Linux LTS-derived Vertex desktop flavor with performance and responsiveness config fragments.
- Init and services: systemd, journald, NetworkManager, resolved, timedated, logind.
- Package system: APT/dpkg plus a signed Vertex repository for custom packages.
- Display protocol: Wayland first, Xwayland for compatibility.
- Display manager: SDDM with a custom QML Vertex Glass theme.
- Window manager/compositor: Hyprland/wlroots profile with blur, translucency, tight spacing, and stable pinned builds.
- Audio: PipeWire and WirePlumber.
- Security: AppArmor, nftables, Polkit, signed packages, Secure Boot support planned.
- Shell: zsh with a Vertex prompt profile, tmux, and Alacritty terminal presets.

## Repository Map

- `docs/`: architecture, UI/UX, and coding standards.
- `build/profiles/`: build profiles and package manifests.
- `config/kernel/`: kernel and runtime tuning fragments.
- `config/display-manager/`: SDDM theme and display manager assets.
- `config/window-manager/`: Wayland compositor configuration.
- `config/shell/`: shell prompt and CLI environment profiles.
- `config/terminal/`: terminal emulator presets.
- `packages/`: Debian package scaffolds for Vertex metapackages.
- `src/native/`: C/C++ low-level components.
- `tools/python/`: Python tooling for build and release tasks.
- `tools/rust/`: Rust tooling for system management commands.
- `scripts/`: developer and build environment scripts.

## Quick Start

Build Vertex OS from a Debian/Ubuntu/WSL Linux environment:

```sh
cd Vertex
chmod +x build-vertex.sh scripts/*.sh
./build-vertex.sh
```

The master build script performs the full pipeline:

1. Checks and bootstraps host dependencies such as `mmdebstrap`, `live-build`, compiler tools, kernel build tools, CMake, and Debian packaging tools.
2. Builds native Vertex components such as `vertex-sessiond`.
3. Fetches and compiles the Linux LTS kernel using fragments from `config/kernel/`.
4. Builds the `vertex-meta-desktop` Debian metapackage.
5. Assembles a root filesystem with `mmdebstrap`.
6. Injects Vertex configs into system paths such as `/etc/skel/`, `/etc/wayland/`, `/etc/sysctl.d/`, `/etc/udev/rules.d/`, and `/usr/share/sddm/themes/`.
7. Creates a bootable ISO with `live-build`.

Build logs are written to:

```text
build/logs/
```

Useful options:

```sh
VERTEX_HYPRLAND_PROFILE=performance ./build-vertex.sh
VERTEX_HYPRLAND_PROFILE=glass ./build-vertex.sh
VERTEX_SKIP_KERNEL=1 ./build-vertex.sh
VERTEX_KERNEL_TARGETS="bzImage modules" ./build-vertex.sh
```

## First Bootstrapping Step

Run the initializer from a Debian/Ubuntu/WSL environment:

```sh
bash scripts/init-build-env.sh
```

The script installs host build tools when possible, prepares `.vertex-build/`, creates a Python virtual environment, and writes a local build environment file.
