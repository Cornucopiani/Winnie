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
                    level   = $e.LevelDisplayName
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
    foreach ($e in $entries) { $counts[$e.level] = $counts[$e.level]+1 }
    [pscustomobject]@{
        hours = $Hours
        total = $entries.Count
        counts = $counts
        entries = $entries
        bugchecks = $bugchecks
    }
}
