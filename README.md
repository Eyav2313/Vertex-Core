# Vertex

Developer: Nuren Zarif Haque

Vertex is a Linux-kernel based desktop distribution focused on three priorities:

1. Premium visual quality with a restrained glassmorphism interface.
2. Stability through a conservative base and pinned release channels.
3. Fast interactive performance for modern laptops and workstations.

## Base Decision

Vertex starts as a Debian Stable derivative with curated backports and a signed Vertex package repository.

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

Build Vertex from a Debian/Ubuntu/WSL Linux environment:

```sh
cd Vertex
chmod +x build-vertex.sh scripts/*.sh
./build-vertex.sh
```

For a fast real boot test, use the smoke boot path. This boots a Linux kernel in QEMU with a minimal Vertex initramfs:

```sh
sudo apt-get install -y linux-image-virtual busybox-static qemu-system-x86 qemu-system-gui grub-efi-amd64-bin mtools xorriso
scripts/build-smoke-os.sh
scripts/run-smoke-os.sh
```

On Windows, after the WSL build creates the kernel/initramfs artifacts, the same smoke boot can use the QEMU already installed in `C:\Program Files\qemu`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-smoke-os.ps1
```

For the optional UEFI smoke path:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-smoke-os.ps1 -Firmware uefi
```

## Live USB Boot

To create a pendrive-bootable Vertex live image, first build the HTML lock OS artifacts, then wrap them in a real UEFI USB image:

```sh
scripts/build-html-lock-os.sh
scripts/build-usb-live.sh
```

The USB artifact is written to:

```text
out/usb/Vertex-OS-Live-USB-x86_64-UEFI.img
```

That image contains a removable-media UEFI boot path at `EFI/BOOT/BOOTX64.EFI`, a Vertex boot manager, the Linux kernel/initrd, and the live ext4 root filesystem. The boot manager keeps a black console-first style and the selected entry starts Linux with real kernel/systemd status output before the Vertex lock screen appears.

Test the USB image in QEMU on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-usb-live-os.ps1
```

Flash to a real USB drive with Rufus or balenaEtcher on Windows. On Linux, use the guarded writer and replace `/dev/sdX` with the whole USB disk, not a partition:

```sh
sudo VERTEX_WRITE_USB_CONFIRM=YES scripts/write-usb-live.sh /dev/sdX
```

The writer is intentionally locked behind `VERTEX_WRITE_USB_CONFIRM=YES` because it destroys all existing data on the target device.

The smoke boot is not a website preview and it is not the final Hyprland desktop. It exists to verify that Vertex can boot as an operating system quickly while the full GUI ISO pipeline is being built.

Smoke boot metrics show the virtual machine resources assigned to QEMU. The WSL/KVM runner passes through the host CPU model when `/dev/kvm` is available, while the Windows runner may show a generic QEMU CPU unless Windows acceleration is enabled. RAM shows the QEMU memory size, and disk shows the attached smoke disk image. A full live USB or installed Vertex system reports the real machine CPU, memory, and physical disks.

The default smoke runner uses direct Linux-kernel boot with PXE/network boot disabled, so the old SeaBIOS/iPXE screen is avoided. A UEFI smoke ISO is also generated at `out/smoke/Vertex-smoke-uefi.iso`; when run with `-Firmware uefi`, QEMU will show OVMF/TianoCore firmware messages before handing off to Vertex. The full desktop ISO pipeline targets proper UEFI live boot.

The HTML design in `preview/desktop/index.html` is also installed into the OS at `/usr/share/vertex/preview/desktop/index.html`. Hyprland starts `/usr/libexec/vertex/vertex-html-shell`, which opens that local design with Firefox ESR inside the actual desktop session.

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
