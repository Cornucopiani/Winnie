function Get-ReliabilityInfo {
    [CmdletBinding()]
    param([int]$Days = 30)
    try {
        $since = (Get-Date).AddDays(-$Days)
        $records = Get-CimInstance Win32_ReliabilityRecords -ErrorAction SilentlyContinue |
            Where-Object { $_.TimeGenerated -ge $since } |
            Select-Object -First 40 TimeGenerated, SourceName, ProductName, EventIdentifier, Message
        $records = @($records | ForEach-Object {
            $msg = $_.Message
            if ($msg -and $msg.Length -gt 300) { $msg = $msg.Substring(0,300)+'...' }
            [pscustomobject]@{
                time    = $_.TimeGenerated.ToString('o')
                source  = $_.SourceName
                product = $_.ProductName
                eventId = $_.EventIdentifier
                message = ($msg -replace '\s+',' ')
            }
        })
        # crash dumps
        $dumps = @()
        try { $dumps = Get-ChildItem 'C:\Windows\Minidump' -Filter '*.dmp' -ErrorAction SilentlyContinue | Select-Object Name, LastWriteTime, Length } catch {}
        [pscustomobject]@{
            days = $Days
            records = $records
            count = $records.Count
            minidumps = @($dumps | ForEach-Object { [pscustomobject]@{ name=$_.Name; date=$_.LastWriteTime.ToString('o'); sizeKB=[math]::Round($_.Length/1KB,0) } })
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
