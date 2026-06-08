param(
    [string]$Image = "",
    [string]$Memory = "2048M",
    [int]$Cpus = 2,
    [int]$Width = 1280,
    [int]$Height = 720,
    [switch]$UseWhpx
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Image)) {
    $Image = Join-Path $Root "out\usb\Vertex-OS-Live-USB-x86_64-UEFI.img"
}

if (-not (Test-Path $Image)) {
    throw "USB image is missing. Run this first in WSL: scripts/build-usb-live.sh"
}

$OutDir = Join-Path $Root "out\usb"
$LogDir = Join-Path $Root "build\logs"
$OvmfVars = Join-Path $OutDir "OVMF_VARS_VERTEX_USB.fd"
$LogFile = Join-Path $LogDir "vertex-usb-qemu.log"
$ErrFile = Join-Path $LogDir "vertex-usb-qemu.err.log"
$SerialLog = Join-Path $LogDir "vertex-usb-qemu.serial.log"

$Qemu = Join-Path ${env:ProgramFiles} "qemu\qemu-system-x86_64.exe"
if (-not (Test-Path $Qemu)) {
    $Qemu = "qemu-system-x86_64.exe"
}

$OvmfCodeCandidates = @(
    (Join-Path ${env:ProgramFiles} "qemu\share\edk2-x86_64-code.fd"),
    (Join-Path ${env:ProgramFiles} "qemu\share\OVMF_CODE.fd"),
    (Join-Path $Root "out\smoke\OVMF_CODE_4M.fd")
)
$OvmfVarsCandidates = @(
    (Join-Path ${env:ProgramFiles} "qemu\share\edk2-i386-vars.fd"),
    (Join-Path ${env:ProgramFiles} "qemu\share\OVMF_VARS.fd"),
    (Join-Path $Root "out\smoke\OVMF_VARS_4M.fd")
)

$OvmfCode = $OvmfCodeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$OvmfVarsTemplate = $OvmfVarsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $OvmfCode) {
    throw "OVMF UEFI firmware was not found. Install qemu-system-x86 with OVMF in WSL or install QEMU for Windows with edk2 firmware."
}

New-Item -ItemType Directory -Force -Path $OutDir, $LogDir | Out-Null
if ($OvmfVarsTemplate) {
    Copy-Item -Force $OvmfVarsTemplate $OvmfVars
}

$firmwareArgs = @(
    "-drive", "if=pflash,format=raw,readonly=on,file=$OvmfCode"
)
if (Test-Path $OvmfVars) {
    $firmwareArgs += @("-drive", "if=pflash,format=raw,file=$OvmfVars")
}

$accelArgs = @("-accel", "tcg,thread=multi")
if ($UseWhpx) {
    $accelArgs = @("-accel", "whpx")
}

$qemuArgs = @(
    "-name", "Vertex-USB-Live"
    "-m", $Memory
    "-smp", "$Cpus"
) + $accelArgs + $firmwareArgs + @(
    "-drive", "file=$Image,format=raw,if=ide,cache=writeback"
    "-usb"
    "-device", "usb-kbd"
    "-device", "usb-tablet"
    "-boot", "order=c,menu=off,strict=on"
    "-device", "VGA,vgamem_mb=64,xres=$Width,yres=$Height"
    "-net", "none"
    "-display", "gtk,zoom-to-fit=off"
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
Write-Host "[vertex-usb] QEMU UEFI USB live boot started."
Write-Host "[vertex-usb] Image: $Image"
Write-Host "[vertex-usb] Serial log: $SerialLog"
