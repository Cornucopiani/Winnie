function Get-EventLogDeepInfo {
    [CmdletBinding()]
    param([int]$Days = 14, [int]$MaxPerLog = 2000)
    $since = (Get-Date).AddDays(-$Days)
    $logPlan = @(
        'System','Application','Setup',
        'Microsoft-Windows-WindowsUpdateClient/Operational',
        'Microsoft-Windows-Windows Defender/Operational',
        'Microsoft-Windows-Diagnostics-Performance/Operational',
        'Microsoft-Windows-Kernel-WHEA/Errors',
        'Microsoft-Windows-Kernel-WHEA/Operational',
        'Microsoft-Windows-Storage-Storport/Operational',
        'Microsoft-Windows-Storage-Storport/Health',
        'Microsoft-Windows-Ntfs/Operational',
        'Microsoft-Windows-CodeIntegrity/Operational',
        'Microsoft-Windows-GroupPolicy/Operational',
        'Microsoft-Windows-TaskScheduler/Operational',
        'Microsoft-Windows-DNS-Client/Operational',
        'Microsoft-Windows-WLAN-AutoConfig/Operational',
        'Microsoft-Windows-Bits-Client/Operational',
        'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational',
        'Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational',
        'Microsoft-Windows-Hyper-V-VMMS/Admin'
    )
    $available = @{}
    try { Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object { $available[$_.LogName] = $_.IsEnabled } } catch {}
    $logs = @()
    foreach ($log in $logPlan) {
        if (-not $available.ContainsKey($log) -or -not $available[$log]) { continue }
        try {
            $rows = Get-WinEvent -FilterHashtable @{ LogName=$log; StartTime=$since } -MaxEvents $MaxPerLog -ErrorAction SilentlyContinue |
                Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, @{n='Message';e={ if ($_.Message) { ($_.Message -replace '\s+',' ').Substring(0,[Math]::Min(300,$_.Message.Length)) } else { '' } }}
            if ($rows) {
                $logs += [pscustomobject]@{ log=$log; count=$rows.Count; events=@($rows | Select-Object -First 50) }
            }
        } catch {}
    }
    # interesting events roll-up
    $interesting = @()
    $interestingDefs = @(
        @{ Cat='UnexpectedShutdown'; Log='System'; Ids=@(41) },
        @{ Cat='BugCheck'; Log='System'; Ids=@(1001) },
        @{ Cat='WHEA_Hardware'; Log='System'; Providers=@('Microsoft-Windows-WHEA-Logger') },
        @{ Cat='DiskError'; Log='System'; Ids=@(7,11,51,55,153) },
        @{ Cat='NtfsError'; Log='System'; Providers=@('Ntfs','Microsoft-Windows-Ntfs') }
    )
    foreach ($def in $interestingDefs) {
        try {
            $f = @{ LogName=$def.Log; StartTime=$since }
            if ($def.Ids) { $f.Id = $def.Ids }
            if ($def.Providers) { $f.ProviderName = $def.Providers }
            $ev = Get-WinEvent -FilterHashtable $f -MaxEvents 200 -ErrorAction SilentlyContinue
            if ($ev) {
                $interesting += [pscustomobject]@{ category=$def.Cat; count=$ev.Count; events=@($ev | Select-Object -First 20 TimeCreated, Id, ProviderName, @{n='Message';e={ if($_.Message){($_.Message -replace '\s+',' ').Substring(0,[Math]::Min(200,$_.Message.Length))}else{''} }}) }
            }
        } catch {}
    }
    [pscustomobject]@{ days=$Days; logs=$logs; interesting=$interesting }
}
