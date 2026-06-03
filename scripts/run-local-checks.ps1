Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Venv = Join-Path $Root ".vertex-build\venv-win"
$Python = Join-Path $Venv "Scripts\python.exe"
$VertexBuild = Join-Path $Venv "Scripts\vertex-build.exe"

function Write-Vertex {
    param([string]$Message)
    Write-Host "[vertex] $Message" -ForegroundColor Cyan
}

Write-Vertex "Preparing Windows-local Python tooling."
if (-not (Test-Path $Python)) {
    python -m venv $Venv
}

& $Python -m pip install --upgrade pip wheel
& $Python -m pip install -e (Join-Path $Root "tools\python")

Write-Vertex "Compiling Python tools."
& $Python -m compileall -q (Join-Path $Root "tools\python")

Write-Vertex "Parsing TOML configs."
@'
from pathlib import Path
import tomllib

root = Path.cwd()
for path in [
    root / "config/terminal/alacritty/vertex.toml",
    root / "tools/rust/vertexctl/Cargo.toml",
    root / "tools/python/pyproject.toml",
]:
    with path.open("rb") as handle:
        tomllib.load(handle)
    print(f"parsed {path.relative_to(root)}")
'@ | & $Python -

Write-Vertex "Checking shell script syntax when bash is available."
$Bash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $Bash -and (Test-Path "C:\Program Files\Git\bin\bash.exe")) {
    $BashPath = "C:\Program Files\Git\bin\bash.exe"
} elseif ($Bash) {
    $BashPath = $Bash.Source
} else {
    $BashPath = $null
}

if ($BashPath) {
    & $BashPath -n (Join-Path $Root "build-vertex.sh")
    Get-ChildItem -Path (Join-Path $Root "scripts") -Filter "*.sh" | ForEach-Object {
        & $BashPath -n $_.FullName
    }
    Write-Vertex "bash syntax OK."
} else {
    Write-Vertex "bash not found; shell syntax check skipped."
}

Write-Vertex "Inspecting desktop package profile."
& $VertexBuild inspect --profile desktop

Write-Vertex "Local checks complete."
