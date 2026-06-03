param(
    [string]$Memory = "768M",
    [int]$Cpus = 2,
    [string]$DiskSize = "1GB"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "out\smoke"
$Kernel = Join-Path $OutDir "vertexos-smoke-vmlinuz"
$Initramfs = Join-Path $OutDir "vertexos-smoke-initramfs.cpio.gz"
$Disk = Join-Path $OutDir "vertexos-smoke-disk.raw"
$LogDir = Join-Path $Root "build\logs"
$LogFile = Join-Path $LogDir "vertexos-smoke-windows-qemu.log"
$ErrFile = Join-Path $LogDir "vertexos-smoke-windows-qemu.err.log"
$SerialLog = Join-Path $LogDir "vertexos-smoke-windows-qemu.serial.log"

$Qemu = Join-Path ${env:ProgramFiles} "qemu\qemu-system-x86_64.exe"
if (-not (Test-Path $Qemu)) {
    $Qemu = "qemu-system-x86_64.exe"
}

if (-not (Test-Path $Kernel) -or -not (Test-Path $Initramfs)) {
    throw "Smoke artifacts are missing. Run this first in WSL: scripts/build-smoke-os.sh"
}

New-Item -ItemType Directory -Force -Path $OutDir, $LogDir | Out-Null

if (-not (Test-Path $Disk)) {
    $bytes = switch -Regex ($DiskSize) {
        '^(\d+)GB$' { [int64]$Matches[1] * 1GB; break }
        '^(\d+)MB$' { [int64]$Matches[1] * 1MB; break }
        default { [int64]1GB }
    }

    $stream = [System.IO.File]::Create($Disk)
    try {
        $stream.SetLength($bytes)
    } finally {
        $stream.Dispose()
    }
}

$qemuArgs = @(
    "-name", "VertexOS-Smoke"
    "-m", $Memory
    "-smp", "$Cpus"
    "-kernel", $Kernel
    "-initrd", $Initramfs
    "-append", "console=tty0 console=ttyS0,115200 quiet loglevel=0 vt.global_cursor_default=0 fbcon=font:VGA8x8 panic=1"
    "-drive", "file=$Disk,if=virtio,format=raw,cache=writeback"
    "-boot", "menu=off,strict=on"
    "-net", "none"
    "-display", "gtk"
    "-serial", "file:$SerialLog"
    "-monitor", "none"
    "-no-reboot"
)

$argLine = ($qemuArgs | ForEach-Object {
    if ($_ -match '[\s"]') {
        '"' + ($_ -replace '"', '\"') + '"'
    } else {
        $_
    }
}) -join ' '

Start-Process -FilePath $Qemu -ArgumentList $argLine -RedirectStandardOutput $LogFile -RedirectStandardError $ErrFile
Write-Host "[vertexos-smoke] Windows QEMU started."
Write-Host "[vertexos-smoke] Serial log: $SerialLog"
