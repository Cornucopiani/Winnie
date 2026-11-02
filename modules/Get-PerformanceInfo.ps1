function Get-PerformanceInfo {
    [CmdletBinding()]
    param()
    try {
        $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $os = Get-CimInstance Win32_OperatingSystem
        $memUsedPct = [math]::Round((1 - $os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,1)
        $diskQueue = $null
        try { $diskQueue = (Get-Counter '\PhysicalDisk(_Total)\Avg. Disk Queue Length' -ErrorAction Stop).CounterSamples.CookedValue } catch {}
        $netBytes = $null
        try { $netBytes = (Get-Counter '\Network Interface(*)\Bytes Total/sec' -ErrorAction Stop).CounterSamples | Measure-Object CookedValue -Sum } catch {}
        [pscustomobject]@{
            cpuLoadPercent    = [math]::Round($cpu,1)
            memoryUsedPercent = $memUsedPct
            freeRamMB         = [math]::Round($os.FreePhysicalMemory/1024,0)
            totalRamMB        = [math]::Round($os.TotalVisibleMemorySize/1024,0)
            diskQueueLength   = if ($diskQueue) { [math]::Round($diskQueue,2) } else { $null }
            networkBytesPerSec= if ($netBytes) { [math]::Round($netBytes.Sum,0) } else { $null }
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
