function Get-UpdatesFirmwareInfo {
    [CmdletBinding()]
    param()
    try {
        # BIOS
        $bios = Get-CimInstance Win32_BIOS | Select-Object -First 1
        # update history with result codes
        $history = @()
        try {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $session.CreateUpdateSearcher()
            $hist = $searcher.QueryHistory(0, 50)
            $history = @($hist | ForEach-Object {
                [pscustomobject]@{ date=$_.Date.ToString('o'); title=$_.Title; result=$_.ResultCode; hresult=$_.HResult }
            })
        } catch {}
        # failed updates
        $failed = @($history | Where-Object { $_.result -ne 2 })
        # driver age (oldest drivers)
        $oldDrivers = @()
        try {
            $oldDrivers = @(Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DriverDate -and $_.DriverDate.Year -ge 2000 } |
                Sort-Object DriverDate | Select-Object -First 10 DeviceName, DriverVersion, @{n='DriverDate';e={$_.DriverDate.ToString('yyyy-MM-dd')}}, Manufacturer)
        } catch {}
        [pscustomobject]@{
            biosVersion = $bios.SMBIOSBIOSVersion
            biosDate    = if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { $null }
            manufacturer= $bios.Manufacturer
            history     = $history
            failedCount = $failed.Count
            failed      = $failed
            oldDrivers  = $oldDrivers
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
