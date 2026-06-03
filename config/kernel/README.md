# Kernel Configuration

`vertex-desktop-performance.fragment` is the first desktop tuning fragment. It should be merged into the Debian kernel configuration or a VertexOS kernel package build, then validated with:

```sh
bash scripts/init-build-env.sh
```

## Fetching Linux LTS

Fetch the official stable Linux LTS source into `src/kernel/`:

```sh
bash scripts/fetch-kernel.sh
```

Default source:

```text
https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
```

Default ref:

```text
linux-6.6.y
```

Override when needed:

```sh
VERTEX_KERNEL_REF=v6.6.32 bash scripts/fetch-kernel.sh
VERTEX_KERNEL_REF=linux-6.6.y VERTEX_KERNEL_FULL_CLONE=1 bash scripts/fetch-kernel.sh
```

## Merging VertexOS Fragments

Kernel fragments live in:

```text
config/kernel/*.fragment
```

The build script merges them into the active kernel `.config` using the kernel tree helper:

```sh
scripts/kconfig/merge_config.sh -m -O .vertex-build/kernel .vertex-build/kernel/.config config/kernel/*.fragment
```

Then it runs:

```sh
make -C src/kernel O=.vertex-build/kernel ARCH=x86 olddefconfig
```

That step resolves new or missing symbols and writes the final config to:

```text
.vertex-build/kernel/.config
```

By default, `scripts/build-kernel.sh` starts from `x86_64_defconfig`. To merge VertexOS fragments onto a distro or custom config instead:

```sh
VERTEX_KERNEL_BASE_CONFIG=/boot/config-$(uname -r) bash scripts/build-kernel.sh
```

## Patching

Custom kernel patches are stored in:

```text
patches/
```

Use ordered names such as:

```text
0001-vertex-branding.patch
0002-desktop-latency-tuning.patch
```

`scripts/build-kernel.sh` applies `patches/*.patch` and `patches/*/*.patch` before configuration and compilation.

## Building

Build the VertexOS kernel packages:

```sh
bash scripts/build-kernel.sh
```

The default target is:

```text
bindeb-pkg
```

For a raw kernel image and modules only:

```sh
VERTEX_KERNEL_TARGETS="bzImage modules" bash scripts/build-kernel.sh
```

Useful build variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `VERTEX_KERNEL_DIR` | `src/kernel` | Linux source tree |
| `VERTEX_KERNEL_BUILD_DIR` | `.vertex-build/kernel` | Out-of-tree kernel build directory |
| `VERTEX_KERNEL_REF` | `linux-6.6.y` | LTS branch or tag fetched by `fetch-kernel.sh` |
| `VERTEX_KERNEL_DEFCONFIG` | `x86_64_defconfig` | Base defconfig when no custom config is provided |
| `VERTEX_KERNEL_BASE_CONFIG` | empty | Existing `.config` to merge fragments onto |
| `VERTEX_KERNEL_TARGETS` | `bindeb-pkg` | Make targets to compile |
| `VERTEX_KERNEL_JOBS` | CPU count | Parallel build jobs |
| `VERTEX_KERNEL_LOCALVERSION` | `-vertex` | Kernel local version suffix |

Future kernel work should split policy by profile:

- `desktop-performance`: default workstation and laptop kernel.
- `laptop-efficiency`: reduced power draw and thermal pressure.
- `workstation-lowlatency`: creative and development workloads.
- `secure-hardened`: stricter defaults for high-risk environments.
