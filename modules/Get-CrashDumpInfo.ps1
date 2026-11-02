function Get-CrashDumpInfo {
    [CmdletBinding()]
    param()
    try {
        # dump files
        $dumps = @()
        $minidumpDir = 'C:\Windows\Minidump'
        if (Test-Path $minidumpDir) {
            $dumps += Get-ChildItem $minidumpDir -Filter '*.dmp' -ErrorAction SilentlyContinue | ForEach-Object {
                [pscustomobject]@{ name=$_.Name; path=$_.FullName; sizeMB=[math]::Round($_.Length/1MB,2); date=$_.LastWriteTime.ToString('o') }
            }
        }
        # MEMORY.DMP
        $memDump = $null
        if (Test-Path 'C:\Windows\MEMORY.DMP') {
            $f = Get-Item 'C:\Windows\MEMORY.DMP'
            $memDump = [pscustomobject]@{ name=$f.Name; sizeMB=[math]::Round($f.Length/1MB,2); date=$f.LastWriteTime.ToString('o') }
        }
        # WER reports (recent)
        $wer = @()
        $werDir = 'C:\ProgramData\Microsoft\Windows\WER\ReportQueue'
        if (Test-Path $werDir) {
            $wer = Get-ChildItem $werDir -Recurse -Filter '*.wer' -ErrorAction SilentlyContinue | Select-Object -First 20 | ForEach-Object {
                [pscustomobject]@{ name=$_.Name; date=$_.LastWriteTime.ToString('o') }
            }
        }
        # pagefile config
        $pagefile = $null
        try {
            $pf = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
            $pagefile = @($pf | ForEach-Object { [pscustomobject]@{ name=$_.Name; allocatedMB=$_.AllocatedBaseSize; currentMB=$_.CurrentUsage; peakMB=$_.PeakUsage } })
        } catch {}
        # dump config
        $dumpConfig = $null
        try {
            $dc = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -ErrorAction Stop
            $dumpConfig = [pscustomobject]@{
                crashDumpEnabled = $dc.CrashDumpEnabled
                minidumpsDir     = $dc.MinidumpDir
                dumpFile         = $dc.DumpFile
                autoReboot       = [bool]$dc.AutoReboot
            }
        } catch {}
        [pscustomobject]@{ minidumps=$dumps; memoryDump=$memDump; werReports=$wer; pagefile=$pagefile; dumpConfig=$dumpConfig }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
