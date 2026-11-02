function Get-SystemInfo {
    [CmdletBinding()]
    param()
    try {
        $os   = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cs   = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
        $cpu  = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        $uptime = (Get-Date) - $os.LastBootUpTime
        [pscustomobject]@{
            hostname        = $env:COMPUTERNAME
            username        = $env:USERNAME
            domain          = $env:USERDOMAIN
            os              = $os.Caption
            osVersion       = $os.Version
            osBuild         = $os.BuildNumber
            osArch          = $os.OSArchitecture
            installDate     = if ($os.InstallDate) { $os.InstallDate.ToString('o') } else { $null }
            lastBoot        = if ($os.LastBootUpTime) { $os.LastBootUpTime.ToString('o') } else { $null }
            uptimeHours     = [math]::Round($uptime.TotalHours, 2)
            manufacturer    = $cs.Manufacturer
            model           = $cs.Model
            systemType      = $cs.SystemType
            totalRamGB      = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
            cpu             = $cpu.Name
            cpuCores        = $cpu.NumberOfCores
            cpuLogical      = $cpu.NumberOfLogicalProcessors
            cpuMaxClock     = $cpu.MaxClockSpeed
            biosManufacturer= $bios.Manufacturer
            biosVersion     = $bios.SMBIOSBIOSVersion
            biosDate        = if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { $null }
            timezone        = (Get-TimeZone).Id
            locale          = (Get-Culture).Name
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
