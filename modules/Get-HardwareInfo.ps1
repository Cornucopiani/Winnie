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
        # battery wear / cycle info (Win8+ WMI)
        $bStatic = $null; $bFull = $null; $bCycle = $null
        try { $bStatic = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1 } catch {}
        try { $bFull   = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1 } catch {}
        try { $bCycle  = Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount -ErrorAction Stop | Select-Object -First 1 } catch {}
        [pscustomobject]@{
            battery = if ($battery) {
                $b = $battery | Select-Object -First 1
                $wear = $null
                if ($bStatic.DesignedCapacity -and $bFull.FullChargedCapacity) {
                    $wear = [math]::Round(100 - (100 * $bFull.FullChargedCapacity / $bStatic.DesignedCapacity), 1)
                }
                [pscustomobject]@{
                    name                 = $b.Name
                    status               = $b.BatteryStatus
                    estimatedCharge      = $b.EstimatedChargeRemaining
                    estimatedRuntime     = $b.EstimatedRunTime
                    chemistry            = $b.Chemistry
                    designCapacity_mWh   = $bStatic.DesignedCapacity
                    fullChargeCapacity_mWh = $bFull.FullChargedCapacity
                    wearPercent          = $wear
                    cycleCount           = $bCycle.CycleCount
                    manufacturer         = $bStatic.ManufactureName
                    serialNumber         = $bStatic.SerialNumber
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
