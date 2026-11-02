# build\portable.ps1 - Create a portable, zipped distribution of the toolkit
# Usage: .\build\portable.ps1 [-OutDir dist]

[CmdletBinding()]
param([string]$OutDir = '')
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '..\dist' }

$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $PSCommandPath }
if (-not $PSScriptRoot) { $PSScriptRoot = (Get-Location).Path }
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$dist = Join-Path $OutDir 'ITSupportToolkit'
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Path $dist -Force | Out-Null

# Copy runtime files
$items = @('collect.ps1','gui.ps1','README.md','AGENTS.md','.gitignore','modules','dashboard','ai','config','tests')
foreach ($it in $items) {
    $src = Join-Path $root $it
    if (Test-Path $src) {
        Copy-Item $src -Destination $dist -Recurse -Force
    }
}
# Ensure output dir exists (empty) for artifacts
New-Item -ItemType Directory -Path (Join-Path $dist 'output') -Force | Out-Null

# Launcher batch
$bat = @"
@echo off
setlocal
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0gui.ps1"
"@
$bat | Set-Content (Join-Path $dist 'Run.bat') -Encoding ASCII

# Console-only launcher
$bat2 = @"
@echo off
setlocal
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0collect.ps1"
pause
"@
$bat2 | Set-Content (Join-Path $dist 'Collect-Console.bat') -Encoding ASCII

# Zip
$zip = Join-Path $OutDir 'ITSupportToolkit.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $dist -DestinationPath $zip -Force

Write-Host "Portable build created:" -ForegroundColor Green
Write-Host "  Folder: $dist"
Write-Host "  Zip:    $zip"
Write-Host ""
Write-Host "Ship the zip. Recipient extracts and runs Run.bat (GUI) or Collect-Console.bat."
