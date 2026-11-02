function Get-StorageInfo {
    [CmdletBinding()]
    param()
    try {
        $disks = Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | Where-Object { $_.DriveType -in 2,3,4 } |
            Select-Object DeviceID, VolumeName, FileSystem, Size, FreeSpace, DriveType
        $pageFile = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
        $smart = $null
        try {
            $smart = Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName, HealthStatus, OperationalStatus, Size, MediaType
        } catch { $smart = $null }
        [pscustomobject]@{
            volumes = @($disks | ForEach-Object {
                $sizeGB = if ($_.Size) { [math]::Round($_.Size/1GB,2) } else { 0 }
                $freeGB = if ($_.FreeSpace) { [math]::Round($_.FreeSpace/1GB,2) } else { 0 }
                $usedPct = if ($_.Size -gt 0) { [math]::Round((1 - $_.FreeSpace/$_.Size)*100,1) } else { 0 }
                [pscustomobject]@{
                    drive       = $_.DeviceID
                    label       = $_.VolumeName
                    fs          = $_.FileSystem
                    type        = switch ($_.DriveType) { 2 {'Removable'} 3 {'Fixed'} 4 {'Network'} default {'Unknown'} }
                    sizeGB      = $sizeGB
                    freeGB      = $freeGB
                    usedPercent = $usedPct
                }
            })
            pageFile = @($pageFile | ForEach-Object {
                [pscustomobject]@{ name=$_.Name; allocatedMB=$_.AllocatedBaseSize; currentMB=$_.CurrentUsage; peakMB=$_.PeakUsage }
            })
            physicalDisks = @($smart | ForEach-Object {
                [pscustomobject]@{
                    name    = $_.FriendlyName
                    health  = $_.HealthStatus
                    status  = $_.OperationalStatus
                    sizeGB  = [math]::Round($_.Size/1GB,2)
                    media   = $_.MediaType
                }
            })
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
function Get-SmartStatus {
    # Best-effort SMART via MSFT_StorageReliabilityCounter (Win8+)
    try {
        $rel = Get-StorageReliabilityCounter -PhysicalDisk (Get-PhysicalDisk) -ErrorAction Stop
        @($rel | ForEach-Object {
            [pscustomobject]@{
                device        = $_.DeviceId
                temperature   = $_.Temperature
                readErrors    = $_.ReadErrorsTotal
                writeErrors   = $_.WriteErrorsTotal
                wear          = $_.Wear
            }
        })
    } catch { @() }
}
