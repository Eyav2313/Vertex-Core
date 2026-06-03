# Desktop Build Profile

This profile describes the first Vertex OS desktop image. It is intentionally lean: install the base system, graphics stack, display manager, compositor, terminal, shell, and essential laptop services before layering optional applications.

Package manifests are split so the base stays stable while Vertex-owned packages can come from the custom repository.
