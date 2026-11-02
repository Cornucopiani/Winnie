# ai/summarize.ps1 - Build an AI-ready Markdown summary from output/data.json

[CmdletBinding()]
param(
    [string]$DataPath = (Join-Path $PSScriptRoot '..\output\data.json'),
    [string]$OutPath  = (Join-Path $PSScriptRoot '..\output\summary.md'),
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\config\config.json')
)
$ErrorActionPreference = 'Continue'
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
if (-not (Test-Path $DataPath)) { throw "data.json not found. Run collect.ps1 first." }
$data = Get-Content $DataPath -Raw | ConvertFrom-Json

$sb = New-Object System.Text.StringBuilder
function L($t){ [void]$sb.AppendLine($t) }

L "# IT Support Diagnostic Summary"
L ""
L "Generated: $($data.meta.collectedAt)"
L "Hostname: $($data.meta.hostname)"
L "Tool version: $($data.meta.toolVersion)"
L "Elevated: $($data.meta.elevated)"
L "Health score: $($data.health.score)/100"
L ""

L "## Issues ($($data.health.issues.Count))"
foreach ($i in $data.health.issues) { L "- [$($i.severity.ToUpper())] $($i.area): $($i.message)" }
if (-not $data.health.issues.Count) { L "- None detected" }
L ""

L "## System"
L "- OS: $($data.system.os) ($($data.system.osVersion), build $($data.system.osBuild))"
L "- CPU: $($data.system.cpu) ($($data.system.cpuCores) cores / $($data.system.cpuLogical) logical)"
L "- RAM: $($data.system.totalRamGB) GB"
L "- Uptime: $($data.system.uptimeHours) h (last boot $($data.system.lastBoot))"
L "- Manufacturer/Model: $($data.system.manufacturer) / $($data.system.model)"
L ""

L "## Performance"
L "- CPU load: $($data.performance.cpuLoadPercent)%"
L "- RAM used: $($data.performance.memoryUsedPercent)% ($($data.performance.freeRamMB) MB free)"
L "- Disk queue: $($data.performance.diskQueueLength)"
L ""

L "## Storage"
foreach ($v in $data.storage.volumes) { L "- $($v.drive) $($v.label): $($v.usedPercent)% used, $($v.freeGB) GB free of $($v.sizeGB) GB" }
if ($data.storage.physicalDisks) { foreach ($d in $data.storage.physicalDisks) { L "- Disk $($d.name): health=$($d.health), status=$($d.status)" } }
L ""

L "## Network"
L "- Pings: " + (($data.network.pings | ForEach-Object { "$($_.target)=$($_.success) ($($_.latency)ms)" }) -join ', ')
if ($data.network.ipConfig) { foreach ($i in $data.network.ipConfig) { L "- $($i.alias): $((@($i.ipv4)) -join ', ') gw=$($i.gateway)" } }
L "- Listening ports: $($data.network.listeningPorts.Count)"
L "- Proxy: $($data.network.proxy)"
L ""

L "## Failed Auto-Start Services ($($data.services.failedAuto.Count))"
foreach ($s in ($data.services.failedAuto | Select-Object -First 20)) { L "- $($s.name) ($($s.display)): $($s.state)" }
L ""

L "## Problem Devices ($($data.drivers.problemCount))"
foreach ($d in $data.drivers.problemDevices) { L "- $($d.name): code $($d.errorCode)" }
L ""

L "## Recent Event Log Errors ($($data.events.total) in last $($data.events.hours)h)"
if ($data.events.bugchecks.Count) { L "BSOD/crashes: $($data.events.bugchecks.Count)" ; foreach ($b in $data.events.bugchecks) { L "  - $($b.time): $($b.message)" } }
$errs = @($data.events.entries | Where-Object { $_.level -in 'Critical','Error' } | Select-Object -First 15)
foreach ($e in $errs) { L "- [$($e.level)] $($e.source) (id $($e.id)) $($e.time): $($e.message)" }
L ""

L "## Windows Updates"
L "- Pending: $($data.updates.pendingCount), Installed: $($data.updates.installedCount)"
foreach ($u in ($data.updates.pending | Select-Object -First 15)) { L "- PENDING: $($u.title) ($($u.severity))" }
if ($data.updates.recentFailures.Count) { L "Recent failures: $($data.updates.recentFailures.Count)" }
L ""

L "## Security"
if ($data.security.defender) { L "- Defender RT protection: $($data.security.defender.realTimeProtection), AV: $($data.security.defender.antivirusEnabled), defs: $($data.security.defender.definitionsUpdated)" }
L "- Firewall: " + (($data.security.firewall | ForEach-Object { "$($_.profile)=$($_.enabled)" }) -join ', ')
L "- BitLocker: " + (($data.security.bitlocker | ForEach-Object { "$($_.drive)=$($_.protection)" }) -join ', ')
L "- SecureBoot: $($data.security.secureBoot), TPM: $($data.security.tpm.present)/$($data.security.tpm.ready), UAC: $($data.security.uacEnabled)"
L ""

L "## Top Processes by CPU"
foreach ($p in ($data.processes.topCpu | Select-Object -First 10)) { L "- $($p.name) (pid $($p.pid)): CPU $($p.cpu)s, $($p.memMB) MB" }
L ""

L "## Top Memory Consumers"
foreach ($p in ($data.processes.topMemory | Select-Object -First 10)) { L "- $($p.name): $($p.memMB) MB" }
L ""

L "## Reliability / Crashes"
L "- Records: $($data.reliability.count), Minidumps: $($data.reliability.minidumps.Count)"
foreach ($m in $data.reliability.minidumps) { L "  - $($m.name) ($($m.date))" }
L ""

L "## Installed Software (count: $($data.software.count))"
L "Startup items: $($data.software.startup.Count)"
foreach ($s in $data.software.startup) { L "- $($s.name): $($s.command)" }
L ""

L "## Users"
L "- Local users: $($data.users.users.Count), Administrators: $($data.users.administrators.Count)"
L ""

L "---"
L "## Task for AI"
L "You are an IT support analyst. Analyze the diagnostics above and produce:"
L "1. A plain-English summary of the machine's health (3-5 sentences)."
L "2. The top 3 most likely root causes of any problems."
L "3. A prioritized action plan (immediate / this week / monitor)."
L "4. Any safety warnings (data loss, security exposure)."
L "5. Commands or steps to remediate, with risk level."
L "Be concise. Flag uncertainty where data is missing."

# trim to max chars
$max = $config.ai.maxSummaryChars
$text = $sb.ToString()
if ($text.Length -gt $max) { $text = $text.Substring(0,$max) + "`n...[truncated]" }
$text | Set-Content $OutPath -Encoding UTF8
Write-Host "Wrote $OutPath ($($text.Length) chars)" -ForegroundColor Green
