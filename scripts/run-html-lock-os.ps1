param(
    [string]$Memory = "3072M",
    [int]$Cpus = 2,
    [int]$Width = 1280,
    [int]$Height = 720
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "out\html-lock"
$Kernel = Join-Path $OutDir "vertex-html-lock-vmlinuz"
$Initrd = Join-Path $OutDir "vertex-html-lock-initrd.img"
$Rootfs = Join-Path $OutDir "vertex-html-lock-rootfs.ext4"
$LogDir = Join-Path $Root "build\logs"
$LogFile = Join-Path $LogDir "vertex-html-lock-qemu.log"
$ErrFile = Join-Path $LogDir "vertex-html-lock-qemu.err.log"
$SerialLog = Join-Path $LogDir "vertex-html-lock-qemu.serial.log"

$Qemu = Join-Path ${env:ProgramFiles} "qemu\qemu-system-x86_64.exe"
if (-not (Test-Path $Qemu)) {
    $Qemu = "qemu-system-x86_64.exe"
}

if (-not (Test-Path $Kernel) -or -not (Test-Path $Initrd) -or -not (Test-Path $Rootfs)) {
    throw "HTML lock OS artifacts are missing. Run this first in WSL: scripts/build-html-lock-os.sh"
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$qemuArgs = @(
    "-name", "Vertex-HTML-Lock"
    "-m", $Memory
    "-smp", "$Cpus"
    "-machine", "pc"
    "-accel", "tcg,thread=multi"
    "-kernel", $Kernel
    "-initrd", $Initrd
    "-append", "root=/dev/vda rw quiet loglevel=3 console=ttyS0,115200n8 vt.global_cursor_default=0 video=${Width}x${Height} systemd.unit=multi-user.target systemd.mask=systemd-udev-settle.service"
    "-drive", "file=$Rootfs,if=virtio,format=raw,cache=writeback"
    "-device", "VGA,vgamem_mb=64,xres=$Width,yres=$Height"
    "-usb"
    "-device", "usb-kbd"
    "-device", "usb-tablet"
    "-net", "none"
    "-display", "gtk,zoom-to-fit=on"
    "-full-screen"
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
Write-Host "[vertex-html-lock] Windows QEMU started."
Write-Host "[vertex-html-lock] This is a real Chromium kiosk session, not a screenshot."
Write-Host "[vertex-html-lock] Serial log: $SerialLog"
