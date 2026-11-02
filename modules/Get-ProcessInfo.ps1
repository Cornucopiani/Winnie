function Get-ProcessInfo {
    [CmdletBinding()]
    param([int]$Top = 25)
    try {
        $procs = Get-Process -ErrorAction Stop
        $totalCpu = ($procs | Measure-Object -Property CPU -Sum).Sum
        $topCpu = $procs | Sort-Object CPU -Descending | Select-Object -First $Top
        $topMem = $procs | Sort-Object WorkingSet64 -Descending | Select-Object -First $Top
        [pscustomobject]@{
            count = $procs.Count
            totalCpuSeconds = [math]::Round($totalCpu,1)
            topCpu = @($topCpu | ForEach-Object {
                [pscustomobject]@{
                    name = $_.ProcessName
                    pid  = $_.Id
                    cpu  = [math]::Round($_.CPU,1)
                    memMB= [math]::Round($_.WorkingSet64/1MB,1)
                    path = $_.Path
                }
            })
            topMemory = @($topMem | ForEach-Object {
                [pscustomobject]@{
                    name = $_.ProcessName
                    pid  = $_.Id
                    memMB= [math]::Round($_.WorkingSet64/1MB,1)
                    cpu  = [math]::Round($_.CPU,1)
                    path = $_.Path
                }
            })
            suspicious = @($procs | Where-Object { -not $_.Path -and $_.ProcessName -notin @('Idle','System') } | ForEach-Object {
                [pscustomobject]@{ name=$_.ProcessName; pid=$_.Id; reason='no path' }
            } | Select-Object -First 20)
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
