# build\exe.ps1 - Build a single-file .exe via PS2EXE (optional)
# Usage: .\build\exe.ps1
# Requires: PS2EXE module (will prompt to install if missing).

[CmdletBinding()]
param(
    [string]$Entry = 'gui.ps1',
    [string]$OutName = 'ITSupport.exe',
    [switch]$InstallPS2EXE
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    if ($InstallPS2EXE) {
        Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
    } else {
        Write-Host "PS2EXE module not found." -ForegroundColor Yellow
        Write-Host "Install it with:  Install-Module ps2exe -Scope CurrentUser" -ForegroundColor Yellow
        Write-Host "Or re-run with -InstallPS2EXE to install automatically." -ForegroundColor Yellow
        exit 1
    }
}
Import-Module ps2exe

$entryPath = Join-Path $root $Entry
$outPath = Join-Path $root "dist\$OutName"
if (-not (Test-Path (Split-Path $outPath))) { New-Item -ItemType Directory -Path (Split-Path $outPath) -Force | Out-Null }

Invoke-PS2EXE -InputFile $entryPath -OutputFile $outPath `
    -NoConsole -RequireAdmin -Title 'IT Support Toolkit' `
    -Description 'Portable Windows diagnostics toolkit' -Company 'Winnie' -Version '1.0.0.0'

# PS2EXE does not bundle modules/collect.ps1 by default; copy runtime next to the exe.
$dist = Split-Path $outPath
foreach ($it in @('collect.ps1','modules','dashboard','ai','config')) {
    $src = Join-Path $root $it
    if (Test-Path $src) { Copy-Item $src -Destination $dist -Recurse -Force }
}
# place exe-friendly launcher (exe already is the launcher)

Write-Host "Built: $outPath" -ForegroundColor Green
Write-Host "NOTE: SmartScreen may warn on first run. Code-sign the exe to remove the warning." -ForegroundColor Yellow
Write-Host "Runtime files copied alongside the exe; keep them together." -ForegroundColor Yellow
