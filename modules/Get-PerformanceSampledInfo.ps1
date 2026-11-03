function Get-PerformanceSampledInfo {
    [CmdletBinding()]
    param()
    try {
        # sampled CPU (avoid cumulative CPU seconds)
        $sampledCpu = @()
        try {
            $samples = Get-Counter '\Process(*)\% Processor Time' -SampleInterval 2 -MaxSamples 3 -ErrorAction Stop
            $sampledCpu = @($samples.CounterSamples | Where-Object { $_.InstanceName -notin '_total','idle' } |
                Group-Object InstanceName | ForEach-Object {
                    [pscustomobject]@{ name=$_.Name; avgCpu=[math]::Round((($_.Group | Measure-Object CookedValue -Average).Average / [Environment]::ProcessorCount),1) }
                } | Sort-Object avgCpu -Descending | Select-Object -First 10)
        } catch {}
        # commit charge / page file
        $os = Get-CimInstance Win32_OperatingSystem
        $commitCharge = [math]::Round(($os.TotalVirtualMemorySize - $os.FreeVirtualMemory)/1MB,2)
        $pageFileUsage = $null
        try { $pageFileUsage = @(Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage) } catch {}
        # boot/shutdown duration from diagnostics-performance
        $bootDuration = $null
        try {
            $ev = Get-WinEvent -FilterHashtable @{ LogName='Microsoft-Windows-Diagnostics-Performance/Operational'; Id=100; StartTime=(Get-Date).AddDays(-30) } -MaxEvents 5 -ErrorAction SilentlyContinue
            if ($ev) { $bootDuration = @($ev | ForEach-Object { [pscustomobject]@{ time=$_.TimeCreated.ToString('o'); message=($_.Message -replace '\s+',' ').Substring(0,[Math]::Min(200,$_.Message.Length)) } }) }
        } catch {}
        # processor freq vs max
        $cpuPerf = $null
        try { $cpuPerf = (Get-Counter '\Processor Information(_Total)\% Processor Performance' -SampleInterval 1 -MaxSamples 2 -ErrorAction Stop).CounterSamples | Select-Object -Last 1 -ExpandProperty CookedValue } catch {}
        [pscustomobject]@{
            sampledCpu   = $sampledCpu
            commitChargeGB = $commitCharge
            pageFileUsage = $pageFileUsage
            bootDuration  = $bootDuration
            cpuPerfPct    = if ($cpuPerf) { [math]::Round($cpuPerf,1) } else { $null }
            freeRamMB     = [math]::Round($os.FreePhysicalMemory/1024,0)
            totalRamMB    = [math]::Round($os.TotalVisibleMemorySize/1024,0)
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
