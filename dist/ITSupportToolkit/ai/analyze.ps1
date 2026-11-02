# ai/analyze.ps1 - Optionally call an LLM API with the summary and write analysis.md
# Configure provider/model/apiKey in config\config.json

[CmdletBinding()]
param(
    [string]$SummaryPath = (Join-Path $PSScriptRoot '..\output\summary.md'),
    [string]$OutPath     = (Join-Path $PSScriptRoot '..\output\analysis.md'),
    [string]$ConfigPath  = (Join-Path $PSScriptRoot '..\config\config.json')
)
$ErrorActionPreference = 'Stop'
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$ai = $config.ai
if (-not (Test-Path $SummaryPath)) { throw "summary.md not found. Run ai\summarize.ps1 first." }
$prompt = Get-Content $SummaryPath -Raw

$provider = $ai.provider
if ($provider -eq 'export') {
    Write-Host "Provider is 'export'. No API call. Use summary.md manually." -ForegroundColor Yellow
    Copy-Item $SummaryPath $OutPath -Force
    exit 0
}

switch ($provider) {
  'openai' {
    if (-not $ai.apiKey) { throw "apiKey missing in config" }
    $body = @{
      model = $ai.model
      messages = @(@{ role='user'; content=$prompt })
      temperature = 0.3
    } | ConvertTo-Json -Depth 6
    $headers = @{ Authorization = "Bearer $($ai.apiKey)"; 'Content-Type'='application/json' }
    $resp = Invoke-RestMethod -Uri $ai.endpoint -Method Post -Headers $headers -Body $body
    $text = $resp.choices[0].message.content
  }
  'anthropic' {
    if (-not $ai.apiKey) { throw "apiKey missing in config" }
    $body = @{
      model = $ai.model
      max_tokens = 2000
      messages = @(@{ role='user'; content=$prompt })
    } | ConvertTo-Json -Depth 6
    $headers = @{ 'x-api-key'=$ai.apiKey; 'anthropic-version'='2023-06-01'; 'Content-Type'='application/json' }
    $endpoint = 'https://api.anthropic.com/v1/messages'
    $resp = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body
    $text = $resp.content[0].text
  }
  'ollama' {
    $body = @{ model=$ai.model; prompt=$prompt; stream=$false } | ConvertTo-Json -Depth 6
    $resp = Invoke-RestMethod -Uri $ai.ollamaEndpoint -Method Post -Body $body -ContentType 'application/json'
    $text = $resp.response
  }
  default { throw "Unknown provider: $provider" }
}
$text | Set-Content $OutPath -Encoding UTF8
Write-Host "Wrote $OutPath" -ForegroundColor Green
