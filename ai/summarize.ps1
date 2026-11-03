# ai/summarize.ps1 - Build an AI-ready Markdown summary from output/data.json

[CmdletBinding()]
param(
    [string]$DataPath = '',
    [string]$OutPath  = '',
    [string]$ConfigPath = '',
    [switch]$ShareSafe
)
if (-not $DataPath) { $DataPath = Join-Path $PSScriptRoot '..\output\data.json' }
if (-not $OutPath)  { $OutPath  = Join-Path $PSScriptRoot '..\output\summary.md' }
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '..\config\config.json' }

$ErrorActionPreference = 'Continue'
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $PSCommandPath }
if (-not $PSScriptRoot) { try { $PSScriptRoot = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) } catch {} }
if (-not $PSScriptRoot) { $PSScriptRoot = (Get-Location).Path }
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
if ($config.ai.shareSafe) { $ShareSafe = $true }
if (-not (Test-Path $DataPath)) { throw "data.json not found. Run collect.ps1 first." }
$data = Get-Content $DataPath -Raw | ConvertFrom-Json

function Redact($text) {
    if (-not $text) { return $text }
    $t = $text
    # mask licence/product keys (5x5 groups)
    $t = [regex]::Replace($t, '(?i)([A-Z0-9]{5}-){4,}[A-Z0-9]{5}', 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX')
    # mask common secret assignments
    $t = [regex]::Replace($t, '(?i)(password|passwd|pwd|secret|token|api[_-]?key|bearer)\s*[:=]\s*\S+', '$1=<redacted>')
    return $t
}

function Build-Summary([double]$Detail = 1.0) {
    $sb = New-Object System.Text.StringBuilder
    function L($t){ [void]$sb.AppendLine($t) }

    L "# IT Support Diagnostic Summary"
    L ""
    L "Generated: $($data.meta.collectedAt)"
    $dispHost = if ($ShareSafe) { 'HOST-' + [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($data.meta.hostname))).Replace('-','').Substring(0,8) } else { $data.meta.hostname }
    L "Hostname: $dispHost"
    L "Tool version: $($data.meta.toolVersion)"
    L "Elevated: $($data.meta.elevated)"
    L "Health score: $($data.health.score)/100"
    L ""

    L "## Issues ($($data.health.issues.Count))"
    foreach ($i in $data.health.issues) { L "- [$($i.severity.ToUpper())] $($i.area): $(Redact $i.message)" }
    if (-not $data.health.issues.Count) { L "- None detected" }
    L ""

    L "## Context"
    L "- Mode: $($data.meta.mode)"
    L "- Elevated: $($data.meta.elevated)"
    L "- Domain: $($data.system.domain)"
    if ($data.network.domain) { L "- AD domain: $($data.network.domain)" }
    if ($data.deep.identity.dsregParsed) { L "- AzureAdJoined: $($data.deep.identity.dsregParsed.AzureAdJoined), DomainJoined: $($data.deep.identity.dsregParsed.DomainJoined)" }
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
    if ($data.perfSampled) {
        L "- Sampled top CPU: " + (($data.perfSampled.sampledCpu | Select-Object -First 5 | ForEach-Object { "$($_.name)=$($_.avgCpu)%" }) -join ', ')
        L "- Commit charge: $($data.perfSampled.commitChargeGB) GB, CPU perf: $($data.perfSampled.cpuPerfPct)%"
    }
    L ""

    L "## Storage"
    foreach ($v in $data.storage.volumes) { L "- $($v.drive) $($v.label): $($v.usedPercent)% used, $($v.freeGB) GB free of $($v.sizeGB) GB" }
    if ($data.storage.physicalDisks) { foreach ($d in $data.storage.physicalDisks) { L "- Disk $($d.name): health=$($d.health), status=$($d.status)" } }
    L ""

    L "## SMART / Disk Health"
    if ($data.smart.disks) {
        foreach ($d in $data.smart.disks) {
            L "- Disk $($d.diskIndex) ($($d.model)): predictFailure=$($d.predictFailure)"
            $bad = @($d.attributes | Where-Object { $_.id -in 5,196,197,198 -and $_.raw -gt 0 })
            if ($bad.Count -gt 0) { L "  bad sectors: " + (($bad | ForEach-Object { "$($_.name)=$($_.raw)" }) -join ', ') }
        }
    } else { L "- No native SMART data" }
    if ($data.smartctl.available -and $data.smartctl.devices) {
        foreach ($d in $data.smartctl.devices) { L "- smartctl $($d.name) ($($d.model)): passed=$($d.smartPassed), used=$($d.percentageUsed)%, mediaErrors=$($d.mediaErrors)" }
    }
    L ""

    L "## Pending Reboot"
    if ($data.pendingReboot) {
        L "- CBS: $($data.pendingReboot.componentBasedServicing), WU: $($data.pendingReboot.windowsUpdate), FileRename: $($data.pendingReboot.pendingFileRename), Rename: $($data.pendingReboot.pendingComputerRename) => pending=$($data.pendingReboot.rebootPending)"
    }
    L ""

    L "## Network"
    L "- Pings: " + (($data.network.pings | ForEach-Object { "$($_.target)=$($_.success) ($($_.latency)ms)" }) -join ', ')
    if ($data.network.ipConfig) { foreach ($i in $data.network.ipConfig) {
        $ip = if ($ShareSafe) { ($i.ipv4 -replace '\d+$','xxx') } else { $i.ipv4 }
        $gw = if ($ShareSafe) { if ($i.gateway) { ($i.gateway -replace '\d+$','xxx') } else { $i.gateway } } else { $i.gateway }
        L "- $($i.alias): $ip gw=$gw"
    } }
    L "- Listening ports: $($data.network.listeningPorts.Count)"
    L "- Proxy: $($data.network.proxy)"
    if ($data.network.dnsResolution) { L "- DNS resolution: " + (($data.network.dnsResolution | ForEach-Object { "$($_.name)=$($_.result)" }) -join ', ') }
    if ($data.network.portTests) { L "- DC port tests: " + (($data.network.portTests | ForEach-Object { "$($_.port)=$($_.success)" }) -join ', ') }
    L ""

    L "## Failed Auto-Start Services ($($data.services.failedAuto.Count))"
    foreach ($s in ($data.services.failedAuto | Select-Object -First 20)) { L "- $($s.name) ($($s.display)): $($s.state)" }
    L ""

    L "## Problem Devices ($($data.drivers.problemCount))"
    foreach ($d in $data.drivers.problemDevices) { L "- $($d.name): code $($d.errorCode)" }
    L ""

    $maxEvents = if ($Detail -ge 1.0) { 15 } elseif ($Detail -ge 0.6) { 8 } else { 4 }
    L "## Recent Event Log Errors ($($data.events.total) in last $($data.events.hours)h)"
    if ($data.events.bugchecks.Count) { L "BSOD/crashes: $($data.events.bugchecks.Count)" ; foreach ($b in $data.events.bugchecks) { L "  - $($b.time): $(Redact $b.message)" } }
    $errs = @($data.events.entries | Where-Object { $_.level -in 'Critical','Error' } | Select-Object -First $maxEvents)
    foreach ($e in $errs) { L "- [$($e.level)] $($e.source) (id $($e.id)) $($e.time): $(Redact $e.message)" }
    if ($data.events.aggregated) {
        L "Aggregated (top):"
        foreach ($a in ($data.events.aggregated | Select-Object -First 10)) { L "  - $($a.source) id=$($a.id) count=$($a.count) (first $($a.first), last $($a.last))" }
    }
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

    $maxProc = if ($Detail -ge 1.0) { 10 } elseif ($Detail -ge 0.6) { 5 } else { 3 }
    L "## Top Processes by CPU"
    foreach ($p in ($data.processes.topCpu | Select-Object -First $maxProc)) { L "- $($p.name) (pid $($p.pid)): CPU $($p.cpu)s, $($p.memMB) MB" }
    L ""
    L "## Top Memory Consumers"
    foreach ($p in ($data.processes.topMemory | Select-Object -First $maxProc)) { L "- $($p.name): $($p.memMB) MB" }
    L ""

    L "## Reliability / Crashes"
    L "- Records: $($data.reliability.count), Minidumps: $($data.reliability.minidumps.Count)"
    foreach ($m in $data.reliability.minidumps) { L "  - $($m.name) ($($m.date))" }
    if ($data.deep.crashDumps.crashEvents) {
        L "Crash events:"
        foreach ($c in ($data.deep.crashDumps.crashEvents | Select-Object -First 10)) { L "  - [$($c.category)] $($c | ConvertTo-Json -Compress)" }
    }
    L ""
    L "## Updates & Firmware"
    if ($data.updatesFirmware) {
        L "- BIOS: $($data.updatesFirmware.biosVersion) ($($data.updatesFirmware.biosDate))"
        L "- Failed installs: $($data.updatesFirmware.failedCount)"
        if ($data.updatesFirmware.oldDrivers) { L "- Oldest drivers: " + (($data.updatesFirmware.oldDrivers | Select-Object -First 3 | ForEach-Object { "$($_.DeviceName) ($($_.DriverDate))" }) -join '; ') }
    }
    L ""

    L "## Battery"
    if ($data.hardware.battery) {
        $b = $data.hardware.battery
        L "- $($b.name): charge=$($b.estimatedCharge)%, wear=$($b.wearPercent)%, cycles=$($b.cycleCount), design=$($b.designCapacity_mWh) mWh, full=$($b.fullChargeCapacity_mWh) mWh"
    }
    L ""

    if ($Detail -ge 0.6) {
        L "## Installed Software (count: $($data.software.count))"
        L "Startup items: $($data.software.startup.Count)"
        foreach ($s in $data.software.startup) { L "- $($s.name): $(Redact $s.command)" }
        L ""
    }

    if ($data.mode -eq 'Deep' -and $data.deep) {
        L "## Deep: Event Logs (interesting)"
        if ($data.deep.eventLogDeep.interesting) {
            foreach ($i in $data.deep.eventLogDeep.interesting) { L "- $($i.category): $($i.count)" }
        }
        L ""
        L "## Deep: Crash Dumps"
        if ($data.deep.crashDumps.minidumps) { L "- Minidumps: $($data.deep.crashDumps.minidumps.Count)" }
        if ($data.deep.crashDumps.memoryDump) { L "- MEMORY.DMP: $($data.deep.crashDumps.memoryDump.sizeMB) MB" }
        if ($data.deep.crashDumps.dumpConfig) { L "- AutoReboot: $($data.deep.crashDumps.dumpConfig.autoReboot), DumpEnabled: $($data.deep.crashDumps.dumpConfig.crashDumpEnabled)" }
        L ""
        L "## Deep: Licensing"
        if ($data.deep.licensing.windows) {
            foreach ($w in $data.deep.licensing.windows) { L "- $($w.name): status=$($w.licenseStatus), key=$($w.partialKey)" }
        }
        if ($data.deep.licensing.oemKey) { L "- OEM key (masked): $($data.deep.licensing.oemKey)" }
        L ""
        L "## Deep: Network"
        if ($data.deep.networkDeep.routes) { L "- Routes: $($data.deep.networkDeep.routes.Count)" }
        if ($data.deep.networkDeep.connections) { L "- Connections: $($data.deep.networkDeep.connections.Count)" }
        if ($data.deep.networkDeep.shares) { L "- Shares: $($data.deep.networkDeep.shares.Count)" }
        L ""
        L "## Deep: Security"
        if ($data.deep.securityDeep.avProducts) {
            foreach ($a in $data.deep.securityDeep.avProducts) { L "- AV: $($a.displayName) (state=$($a.productState))" }
        }
        if ($data.deep.securityDeep.hardening) {
            $h = $data.deep.securityDeep.hardening
            L "- Hardening: LSASS PPL=$($h.lsassRunAsPPL), SMB1=$($h.smb1Disabled), RDP denied=$($h.rdpEnabled)"
        }
        L ""
        if ($data.deep.deepScan) {
            L "## Deep: Scan Results"
            L "- SFC/DISM/chkdsk/powercfg collected (see dashboard)"
            L ""
        }
        if ($data.deep.identity) {
            L "## Deep: Identity"
            if ($data.deep.identity.dsregParsed) { L "- dsreg: " + (($data.deep.identity.dsregParsed.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ') }
            L "- Secure channel: $($data.deep.identity.secureChannel)"
            if ($data.deep.identity.officeConfig) { L "- Office: $($data.deep.identity.officeConfig.version) ($($data.deep.identity.officeConfig.channel))" }
            L ""
        }
        if ($data.deep.msp) {
            L "## Deep: MSP"
            if ($data.deep.msp.duplicateAgents) { foreach ($d in $data.deep.msp.duplicateAgents) { L "- Duplicate agent: $($d.agent) ($($d.count))" } }
            if ($data.deep.msp.expiringCerts) { L "- Expiring certs: $($data.deep.msp.expiringCerts.Count)" }
            if ($data.deep.msp.printers) { L "- Printers: $($data.deep.msp.printers.Count)" }
            L ""
        }
        if ($data.deep.storageDeep) {
            L "## Deep: Storage"
            if ($data.deep.storageDeep.topFolders) { L "- Top folders: " + (($data.deep.storageDeep.topFolders | Select-Object -First 5 | ForEach-Object { "$($_.folder)=$($_.sizeGB)GB" }) -join ', ') }
            if ($data.deep.storageDeep.diskImages) { L "- Disk images: $($data.deep.storageDeep.diskImages.Count)" }
            L ""
        }
    }

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
    L "6. What data is missing that would improve diagnosis."
    L "Be concise. Flag uncertainty where data is missing."

    L ""
    L "## Privacy"
    L "This summary may contain computer/user names, IP/MAC addresses, serial numbers, installed software and event text."
    L "Secrets (licence keys, passwords, tokens, bearer headers) have been redacted. Review before sharing externally."

    $sb.ToString()
}

# Size-budgeted build: shrink detail level until it fits.
$max = $config.ai.maxSummaryChars
$text = $null
foreach ($lvl in 1.0, 0.6, 0.3) {
    $candidate = Build-Summary $lvl
    if ($candidate.Length -le $max) { $text = $candidate; break }
}
if (-not $text) {
    $text = Build-Summary 0.3
    if ($text.Length -gt $max) { $text = $text.Substring(0, $max) + "`n...[truncated to fit budget]" }
}
$text | Set-Content $OutPath -Encoding UTF8
Write-Host "Wrote $OutPath ($($text.Length) chars)" -ForegroundColor Green
