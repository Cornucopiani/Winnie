function Get-UpdateInfo {
    [CmdletBinding()]
    param()
    try {
        $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
        $searcher = $session.CreateUpdateSearcher()
        $pending = $searcher.Search("IsInstalled=0")
        $installed = $searcher.Search("IsInstalled=1")
        $pendingList = @($pending.Updates | Select-Object -First 40 | ForEach-Object {
            [pscustomobject]@{ title=$_.Title; severity=$_.MsrcSeverity; kb=@($_.KBArticleIDs) -join ',' }
        })
        # recent failures from event log
        $failures = @()
        try {
            $ev = Get-WinEvent -FilterHashtable @{ LogName='System'; Id=20; StartTime=(Get-Date).AddDays(-14) } -MaxEvents 20 -ErrorAction SilentlyContinue
            foreach ($e in $ev) { $failures += [pscustomobject]@{ time=$e.TimeCreated.ToString('o'); message=($e.Message -replace '\s+',' ').Substring(0,[Math]::Min(300,$e.Message.Length)) } }
        } catch {}
        [pscustomobject]@{
            pendingCount = $pending.Updates.Count
            installedCount = $installed.Updates.Count
            pending = $pendingList
            recentFailures = $failures
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
