# VertexOS Coding Standards

## Language Boundaries

- C and C++: low-level daemons, native session helpers, performance-sensitive desktop integration.
- Rust: system tools that need safety, concurrency, structured error handling, or package/build orchestration.
- Python: build scripts, release tooling, profile generation, repository automation.
- Shell: bootstrap glue only. Keep shell scripts small, strict, and readable.

## General Rules

- Keep modules small and independently testable.
- Prefer explicit configuration files over hidden runtime behavior.
- Keep generated output out of source unless it is intentionally vendored.
- Use stable APIs before private service internals.
- Log enough to diagnose boot and session failures without noisy normal operation.

## Native Code

- C++ standard: C++20.
- C standard: C17.
- Treat warnings as errors in CI for VertexOS-owned code.
- Prefer RAII and clear ownership boundaries.
- Do not block compositor or login paths on network availability.

## Rust

- Rust edition: 2021.
- Prefer `anyhow` for tools and `thiserror` for libraries.
- Use structured command output where tools may be consumed by scripts.
- Keep privileged operations explicit and auditable.

## Python

- Python target: 3.11 or newer.
- Use virtual environments for local tooling.
- Keep CLI entry points under `tools/python/vertex_tools`.
- Prefer typed dataclasses and structured config parsing.

## Shell

- Use `set -euo pipefail`.
- Quote variables.
- Avoid destructive operations unless the script prints the exact target first.
- Make setup scripts idempotent.
