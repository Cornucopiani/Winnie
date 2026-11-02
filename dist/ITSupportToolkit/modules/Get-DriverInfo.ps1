function Get-DriverInfo {
    [CmdletBinding()]
    param()
    try {
        $devices = Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
        $problemDevs = @($devices | ForEach-Object {
            [pscustomobject]@{ name=$_.Name; deviceID=$_.DeviceID; errorCode=$_.ConfigManagerErrorCode; status=$_.Status }
        })
        $drivers = Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Running' -and $_.StartMode -eq 'Auto' } |
            Select-Object -First 40 Name, DisplayName, State, StartMode
        [pscustomobject]@{
            problemDevices = $problemDevs
            problemCount = $problemDevs.Count
            stoppedAutoDrivers = @($drivers | ForEach-Object { [pscustomobject]@{ name=$_.Name; display=$_.DisplayName; state=$_.State } })
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
