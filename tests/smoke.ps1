# tests\smoke.ps1 - Smoke test: run collector and validate output
param([string]$Root = (Split-Path $PSScriptRoot -Parent))
Set-ExecutionPolicy -Scope Process Bypass -Force
powershell -ExecutionPolicy Bypass -File (Join-Path $Root 'collect.ps1') -OutputDir (Join-Path $Root 'output')
Write-Host "collect exit code: $LASTEXITCODE"
if ($LASTEXITCODE -ne 0) { Write-Host "collect failed" -ForegroundColor Red; exit 1 }
$json = Get-Content (Join-Path $Root 'output\data.json') -Raw | ConvertFrom-Json
$required = @('meta','system','health','storage','network','performance')
foreach ($k in $required) {
    if (-not $json.$k) { Write-Host "Missing section: $k" -ForegroundColor Red; exit 1 }
}
Write-Host "Smoke test passed. Score=$($json.health.score)" -ForegroundColor Green
& (Join-Path $Root 'ai\summarize.ps1')
if (Test-Path (Join-Path $Root 'output\summary.md')) { Write-Host "Summary generated" -ForegroundColor Green } else { Write-Host "Summary missing" -ForegroundColor Red; exit 1 }
