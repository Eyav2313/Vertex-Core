from __future__ import annotations

from pathlib import Path

import click
from rich.console import Console

console = Console()


@click.group()
def main() -> None:
    """VertexOS build and release helper."""


@main.command()
@click.option(
    "--profile",
    default="desktop",
    show_default=True,
    help="Build profile under build/profiles.",
)
def inspect(profile: str) -> None:
    """Print the package manifests for a build profile."""
    root = Path(__file__).resolve().parents[3]
    profile_dir = root / "build" / "profiles" / profile

    if not profile_dir.exists():
        raise click.ClickException(f"unknown profile: {profile}")

    console.print(f"[bold cyan]VertexOS profile:[/] {profile}")
    for manifest in sorted(profile_dir.glob("*.packages")):
        packages = [
            line.strip()
            for line in manifest.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.strip().startswith("#")
        ]
        console.print(f"\n[bold]{manifest.name}[/]")
        for package in packages:
            console.print(f"  - {package}")


if __name__ == "__main__":
    main()
