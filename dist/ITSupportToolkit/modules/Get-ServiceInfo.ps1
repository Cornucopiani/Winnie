function Get-ServiceInfo {
    [CmdletBinding()]
    param([int]$Top = 50)
    try {
        $svcs = Get-CimInstance Win32_Service -ErrorAction Stop
        $failed = $svcs | Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' }
        $stopped = $svcs | Where-Object { $_.State -eq 'Stopped' -and $_.StartMode -in 'Auto','Manual' }
        [pscustomobject]@{
            total = $svcs.Count
            running = ($svcs | Where-Object State -eq 'Running').Count
            failedAuto = @($failed | Select-Object -First $Top | ForEach-Object {
                [pscustomobject]@{ name=$_.Name; display=$_.DisplayName; state=$_.State; startMode=$_.StartMode; path=$_.PathName }
            })
            stoppedServices = @($stopped | Select-Object -First $Top | ForEach-Object {
                [pscustomobject]@{ name=$_.Name; display=$_.DisplayName; state=$_.State; startMode=$_.StartMode }
            })
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
