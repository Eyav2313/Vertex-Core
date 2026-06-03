# VertexOS kernel Patches

Store custom kernel optimization, branding, hardware, or packaging patches here.

Recommended naming:

```text
patches/
  0001-vertex-branding.patch
  0002-desktop-latency-tuning.patch
```

You may also group kernel-only patches under:

```text
patches/kernel/
```

`scripts/build-kernel.sh` applies `*.patch` files from `patches/` and one nested level below it in lexical order. The script checks whether each patch applies cleanly, skips it if it is already applied, and fails loudly on conflicts.

Generate patches from inside `src/kernel/` with:

```sh
git format-patch -1 HEAD --stdout > ../../patches/0001-example.patch
```

Keep patches small and reviewable. Performance patches should include a clear benchmark or rationale in the commit message.
