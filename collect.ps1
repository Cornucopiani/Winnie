# collect.ps1 - Universal Windows diagnostics collector
# Usage: .\collect.ps1 [-OutputDir path] [-Config path]

[CmdletBinding()]
param(
    [string]$OutputDir = '',
    [string]$ConfigPath = ''
)
if (-not $OutputDir) { $OutputDir = Join-Path $PSScriptRoot 'output' }
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot 'config\config.json' }

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

function Find-Executable {
    param([string]$Preferred, [string[]]$Names, [string[]]$Candidates)
    if ($Preferred) {
        if (Test-Path -LiteralPath $Preferred) { return (Resolve-Path -LiteralPath $Preferred).Path }
    }
    foreach ($n in $Names) {
        $c = Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { return $c.Source }
    }
    foreach ($c in $Candidates) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    return $null
}

# load modules
Get-ChildItem (Join-Path $root 'modules') -Filter '*.ps1' | ForEach-Object { . $_.FullName }

$errors = @()
$script:Manifest = New-Object System.Collections.Generic.List[object]
function Invoke-Collector {
    param([string]$Name, [scriptblock]$Block)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $status = 'OK'
    $note = ''
    $result = $null
    try {
        $result = & $Block
        $has = ($null -ne $result) -and -not (($result -is [array]) -and $result.Count -eq 0)
        if (-not $has) { $status = 'EMPTY' }
    } catch {
        $status = 'FAILED'
        $note = $_.Exception.Message
        $script:errors += [pscustomobject]@{ collector=$Name; error=$_.Exception.Message }
        $result = [pscustomobject]@{ error = $_.Exception.Message }
    }
    $sw.Stop()
    $items = if ($result -is [array]) { $result.Count } elseif ($null -eq $result) { 0 } else { 1 }
    if ($result.error) { $items = 0 }
    $script:Manifest.Add([pscustomobject]@{
        name    = $Name
        status  = $status
        items   = $items
        seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        note    = if ($note) { ($note -replace '\s+',' ').Substring(0,[Math]::Min(200,$note.Length)) } else { '' }
    })
    $result
}

Write-Host "Collecting diagnostics..." -ForegroundColor Cyan

$system        = Invoke-Collector 'system'        { Get-SystemInfo }
$hardware      = Invoke-Collector 'hardware'      { Get-HardwareInfo }
$storage       = Invoke-Collector 'storage'       { Get-StorageInfo }
$smart         = Invoke-Collector 'smart'         { Get-SmartInfo }
$smartctl      = Invoke-Collector 'smartctl'      { Get-SmartctlInfo -PreferredPath $config.smartctlPath }
$pendingReboot = Invoke-Collector 'pendingReboot' { Get-PendingRebootInfo }
$network      = Invoke-Collector 'network'       { Get-NetworkInfo -PingTargets $config.pingTargets }
$processes    = Invoke-Collector 'processes'    { Get-ProcessInfo -Top $config.topProcesses }
$services     = Invoke-Collector 'services'     { Get-ServiceInfo -Top $config.topServices }
$events       = Invoke-Collector 'events'       { Get-EventLogInfo -Hours $config.eventLogHours }
$updates      = Invoke-Collector 'updates'      { Get-UpdateInfo }
$drivers      = Invoke-Collector 'drivers'      { Get-DriverInfo }
$software     = Invoke-Collector 'software'     { Get-SoftwareInfo }
$security     = Invoke-Collector 'security'     { Get-SecurityInfo }
$performance  = Invoke-Collector 'performance'  { Get-PerformanceInfo }
$users        = Invoke-Collector 'users'        { Get-UserInfo }
$reliability  = Invoke-Collector 'reliability'  { Get-ReliabilityInfo }

# ---- Health scoring ----
$issues = @()
function Add-Issue { param($severity,$area,$message) $script:issues += [pscustomobject]@{ severity=$severity; area=$area; message=$message } }

# disk
if ($storage.volumes) {
    foreach ($v in $storage.volumes) {
        if ($v.usedPercent -ge (100-$config.diskWarnPercent)) {
            Add-Issue 'high' 'Storage' "Drive $($v.drive) is $($v.usedPercent)% full ($($v.freeGB) GB free)"
        }
    }
}
if ($storage.physicalDisks) {
    foreach ($d in $storage.physicalDisks) {
        if ($d.health -and $d.health -ne 'Healthy') {
            Add-Issue 'high' 'Storage' "Physical disk $($d.name) health: $($d.health)"
        }
    }
}
# perf
if ($performance.cpuLoadPercent -ge $config.cpuWarnPercent) { Add-Issue 'medium' 'Performance' "CPU load $($performance.cpuLoadPercent)%" }
if ($performance.memoryUsedPercent -ge $config.ramWarnPercent) { Add-Issue 'high' 'Memory' "RAM usage $($performance.memoryUsedPercent)%" }
# services
if ($services.failedAuto) { Add-Issue 'high' 'Services' "$($services.failedAuto.Count) auto-start services not running" }
# drivers
if ($drivers.problemCount -gt 0) { Add-Issue 'medium' 'Drivers' "$($drivers.problemCount) devices with errors" }
# updates
if ($updates.pendingCount -gt 0) { Add-Issue 'low' 'Updates' "$($updates.pendingCount) pending updates" }
# events
if ($events.bugchecks.Count -gt 0) { Add-Issue 'critical' 'Stability' "$($events.bugchecks.Count) BSOD/crash events in last $($config.eventLogHours)h" }
$critEvents = @($events.entries | Where-Object { $_.level -eq 'Critical' -or $_.level -eq 'Error' })
if ($critEvents.Count -gt 20) { Add-Issue 'medium' 'EventLog' "$($critEvents.Count) error/critical events in last $($config.eventLogHours)h" }
# security
if ($security.defender -and -not $security.defender.realTimeProtection) { Add-Issue 'high' 'Security' 'Windows Defender real-time protection disabled' }
if ($security.firewall) {
    $fwOff = @($security.firewall | Where-Object { -not $_.enabled })
    if ($fwOff.Count -gt 0) { Add-Issue 'high' 'Security' "Firewall profile(s) disabled: $($fwOff.profile -join ', ')" }
}
# network pings
if ($network.pings) {
    $failedPings = @($network.pings | Where-Object { -not $_.success })
    if ($failedPings.Count -gt 0) { Add-Issue 'medium' 'Network' "Ping failed to: $($failedPings.target -join ', ')" }
}
# reliability minidumps
if ($reliability.minidumps.Count -gt 0) { Add-Issue 'high' 'Stability' "$($reliability.minidumps.Count) minidump files present" }
# pending reboot
if ($pendingReboot.rebootPending) { Add-Issue 'medium' 'System' 'A reboot is pending (CBS/Windows Update/PendingFileRename)' }
# smart (native)
if ($smart.disks) {
    foreach ($d in $smart.disks) {
        if ($d.predictFailure) { Add-Issue 'critical' 'Storage' "SMART predicts failure for disk $($d.diskIndex) ($($d.model))" }
        $badAttrs = @($d.attributes | Where-Object { $_.id -in 5,196,197,198 -and $_.raw -gt 0 })
        if ($badAttrs.Count -gt 0) { Add-Issue 'high' 'Storage' "Disk $($d.diskIndex) ($($d.model)): reallocated/pending/uncorrectable sectors present" }
        $crc = @($d.attributes | Where-Object { $_.id -eq 199 -and $_.raw -gt 0 })
        if ($crc.Count -gt 0) { Add-Issue 'low' 'Storage' "Disk $($d.diskIndex): UDMA CRC errors ($($crc[0].raw)) - check cable" }
    }
}
# smartctl
if ($smartctl.available -and $smartctl.devices) {
    foreach ($d in $smartctl.devices) {
        if ($d.smartPassed -eq $false) { Add-Issue 'critical' 'Storage' "smartctl: $($d.name) overall SMART FAILED" }
        if ($null -ne $d.criticalWarning -and $d.criticalWarning -gt 0) { Add-Issue 'critical' 'Storage' "smartctl: $($d.name) NVMe critical_warning=$($d.criticalWarning)" }
        if ($null -ne $d.mediaErrors -and $d.mediaErrors -gt 0) { Add-Issue 'high' 'Storage' "smartctl: $($d.name) media_errors=$($d.mediaErrors)" }
        if ($null -ne $d.percentageUsed -and $d.percentageUsed -ge 80) { Add-Issue 'medium' 'Storage' "smartctl: $($d.name) percentage_used=$($d.percentageUsed)%" }
    }
}
# battery wear
if ($hardware.battery -and $hardware.battery.wearPercent -ge 40) { Add-Issue 'medium' 'Battery' "Battery wear is $($hardware.battery.wearPercent)% of design capacity" }

# score: start 100, deduct by severity
$score = 100
foreach ($i in $issues) {
    switch ($i.severity) {
        'critical' { $score -= 25 }
        'high'     { $score -= 12 }
        'medium'   { $score -= 6 }
        'low'      { $score -= 2 }
    }
}
$score = [math]::Max(0, $score)

$health = [pscustomobject]@{ score=$score; issues=$issues }

$data = [ordered]@{
    meta = [ordered]@{
        collectedAt = (Get-Date).ToString('o')
        hostname    = $env:COMPUTERNAME
        toolVersion = $config.toolVersion
        elevated     = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    system       = $system
    hardware     = $hardware
    storage      = $storage
    smart        = $smart
    smartctl     = $smartctl
    pendingReboot= $pendingReboot
    network      = $network
    processes    = $processes
    services     = $services
    events       = $events
    updates      = $updates
    drivers      = $drivers
    software     = $software
    security     = $security
    performance  = $performance
    users        = $users
    reliability  = $reliability
    health       = $health
    errors       = $errors
}

# write output
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

$json = $data | ConvertTo-Json -Depth 8
$json | Set-Content (Join-Path $OutputDir 'data.json') -Encoding UTF8

# manifest + errors log
$script:Manifest | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutputDir 'manifest.json') -Encoding UTF8
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { "$($_.collector): $($_.error)" } | Set-Content (Join-Path $OutputDir 'errors.log') -Encoding UTF8
} else {
    Set-Content (Join-Path $OutputDir 'errors.log') '' -Encoding UTF8
}

# render dashboard
$templatePath = Join-Path $root 'dashboard\template.html'
if (Test-Path $templatePath) {
    $template = Get-Content $templatePath -Raw
    $embedded = $template -replace '__DATA_PLACEHOLDER__', ($json -replace '</script>','<\/script>')
    $embedded | Set-Content (Join-Path $OutputDir 'dashboard.html') -Encoding UTF8
}

Write-Host "Done. Score: $score/100, Issues: $($issues.Count)" -ForegroundColor Green
Write-Host "Output: $OutputDir" -ForegroundColor Green
$hasCritical = @($issues | Where-Object { $_.severity -eq 'critical' }).Count -gt 0
if ($hasCritical) { exit 2 } else { exit 0 }
