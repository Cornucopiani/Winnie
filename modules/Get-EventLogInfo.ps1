function Get-EventLogInfo {
    [CmdletBinding()]
    param([int]$Hours = 72, [int]$MaxPerLog = 40)
    $since = (Get-Date).AddHours(-$Hours)
    $logs = @('System','Application')
    $entries = @()
    foreach ($log in $logs) {
        try {
            $ev = Get-WinEvent -FilterHashtable @{ LogName=$log; Level=1,2,3; StartTime=$since } -MaxEvents $MaxPerLog -ErrorAction SilentlyContinue
            foreach ($e in $ev) {
                $msg = $e.Message
                if ($msg -and $msg.Length -gt 500) { $msg = $msg.Substring(0,500) + '...' }
                $entries += [pscustomobject]@{
                    log     = $log
                    time    = $e.TimeCreated.ToString('o')
                    id      = $e.Id
                    level   = if ($e.LevelDisplayName) { $e.LevelDisplayName } elseif ($e.Level -eq 0) { 'LogAlways' } else { 'Unknown' }
                    source  = $e.ProviderName
                    message = ($msg -replace '\s+',' ')
                }
            }
        } catch {}
    }
    # BSOD / bugcheck
    $bugchecks = @()
    try {
        $bc = Get-WinEvent -FilterHashtable @{ LogName='System'; Id=1001; StartTime=$since } -MaxEvents 10 -ErrorAction SilentlyContinue
        foreach ($e in $bc) {
            $bugchecks += [pscustomobject]@{ time=$e.TimeCreated.ToString('o'); message=($e.Message -replace '\s+',' ') }
        }
    } catch {}
    # counts by level
    $counts = @{}
    foreach ($e in $entries) {
        $lvl = if ($e.level) { $e.level } else { 'Unknown' }
        if (-not $counts.ContainsKey($lvl)) { $counts[$lvl] = 0 }
        $counts[$lvl] = $counts[$lvl] + 1
    }
    # aggregated by provider+id (expert: group by provider and ID with count, first/last, sample)
    $aggregated = @()
    try {
        $aggEvents = Get-WinEvent -FilterHashtable @{ LogName=@('System','Application'); Level=1,2,3; StartTime=$since } -MaxEvents 2000 -ErrorAction SilentlyContinue
        if ($aggEvents) {
            $aggregated = @($aggEvents | Group-Object ProviderName, Id | ForEach-Object {
                $new = $_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1
                $old = $_.Group | Sort-Object TimeCreated | Select-Object -First 1
                $msg = if ($new.Message) { ($new.Message -replace '\s+',' ').Trim() } else { '' }
                [pscustomobject]@{
                    count  = $_.Count
                    source = $new.ProviderName
                    id     = $new.Id
                    first  = $old.TimeCreated.ToString('o')
                    last   = $new.TimeCreated.ToString('o')
                    sample = $msg.Substring(0, [Math]::Min(200, $msg.Length))
                }
            } | Sort-Object count -Descending | Select-Object -First 25)
        }
    } catch {}
    [pscustomobject]@{
        hours = $Hours
        total = $entries.Count
        counts = $counts
        entries = $entries
        bugchecks = $bugchecks
        aggregated = $aggregated
    }
}
