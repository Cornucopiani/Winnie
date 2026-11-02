function Get-HardwareInfo {
    [CmdletBinding()]
    param()
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object Name, AdapterRAM, DriverVersion, Status
        $mb  = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
        $net = Get-CimInstance Win32_NetworkAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.PhysicalAdapter -eq $true } |
            Select-Object Name, MACAddress, Speed, NetConnectionStatus
        [pscustomobject]@{
            battery = if ($battery) {
                [pscustomobject]@{
                    name            = $battery.Name
                    status          = $battery.BatteryStatus
                    estimatedCharge = $battery.EstimatedChargeRemaining
                    estimatedRuntime= $battery.EstimatedRunTime
                }
            } else { $null }
            gpus = @($gpu | ForEach-Object {
                [pscustomobject]@{
                    name       = $_.Name
                    vramGB     = if ($_.AdapterRAM) { [math]::Round($_.AdapterRAM/1GB,2) } else { $null }
                    driver     = $_.DriverVersion
                    status     = $_.Status
                }
            })
            motherboard = if ($mb) { [pscustomobject]@{ manufacturer=$mb.Manufacturer; product=$mb.Product; serial=$mb.SerialNumber } } else { $null }
            networkAdapters = @($net | ForEach-Object {
                [pscustomobject]@{
                    name   = $_.Name
                    mac    = $_.MACAddress
                    speed  = $_.Speed
                    status = $_.NetConnectionStatus
                }
            })
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
