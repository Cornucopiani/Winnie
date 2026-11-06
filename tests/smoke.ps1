# tests\smoke.ps1 - Smoke test: run collector and validate output
param([string]$Root = (Split-Path $PSScriptRoot -Parent))
Set-ExecutionPolicy -Scope Process Bypass -Force
powershell -ExecutionPolicy Bypass -File (Join-Path $Root 'collect.ps1') -OutputDir (Join-Path $Root 'output')
Write-Host "collect exit code: $LASTEXITCODE"
if ($LASTEXITCODE -ne 0) { Write-Host "collect failed" -ForegroundColor Red; exit 1 }
$latestFile = Join-Path $Root 'output\latest.txt'
$runDir = if (Test-Path $latestFile) { (Get-Content $latestFile -Raw).Trim() } else { Join-Path $Root 'output' }
$json = Get-Content (Join-Path $runDir 'data.json') -Raw | ConvertFrom-Json
$required = @('meta','system','health','storage','network','performance')
foreach ($k in $required) {
    if (-not $json.$k) { Write-Host "Missing section: $k" -ForegroundColor Red; exit 1 }
}
Write-Host "Smoke test passed. Score=$($json.health.score)" -ForegroundColor Green
& (Join-Path $Root 'ai\summarize.ps1')
$latestFile2 = Join-Path $Root 'output\latest.txt'
$runDir2 = if (Test-Path $latestFile2) { (Get-Content $latestFile2 -Raw).Trim() } else { Join-Path $Root 'output' }
if (Test-Path (Join-Path $runDir2 'summary.md')) { Write-Host "Summary generated" -ForegroundColor Green } else { Write-Host "Summary missing" -ForegroundColor Red; exit 1 }
