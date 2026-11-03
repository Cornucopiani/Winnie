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
        # crash-related events
        $crashEvents = @()
        try {
            $since = (Get-Date).AddDays(-30)
            $defs = @(
                @{ Cat='BugCheck'; Log='System'; Provider='Microsoft-Windows-WER-SystemErrorReporting'; Id=1001 }
                @{ Cat='UnexpectedShutdown'; Log='System'; Id=6008 }
                @{ Cat='KernelPower'; Log='System'; Provider='Microsoft-Windows-Kernel-Power'; Id=41 }
                @{ Cat='AppError'; Log='Application'; Id=1000 }
                @{ Cat='AppHang'; Log='Application'; Id=1002 }
            )
            foreach ($def in $defs) {
                $f = @{ LogName=$def.Log; StartTime=$since }
                if ($def.Id) { $f.Id = $def.Id }
                if ($def.Provider) { $f.ProviderName = $def.Provider }
                $ev = Get-WinEvent -FilterHashtable $f -MaxEvents 50 -ErrorAction SilentlyContinue
                if ($ev) {
                    # group by faulting module for app errors
                    if ($def.Cat -in 'AppError','AppHang') {
                        $grp = $ev | Group-Object { [regex]::Match($_.Message,'Faulting module name:\s*(\S+)').Groups[1].Value } | Sort-Object Count -Descending | Select-Object -First 10
                        foreach ($g in $grp) {
                            $crashEvents += [pscustomobject]@{ category=$def.Cat; count=$g.Count; module=($g.Name); sample=(($g.Group[0].Message -replace '\s+',' ').Substring(0,[Math]::Min(200,$g.Group[0].Message.Length))) }
                        }
                    } elseif ($def.Cat -eq 'BugCheck') {
                        foreach ($e in ($ev | Select-Object -First 10)) {
                            $code = [regex]::Match($e.Message,'0x[0-9a-fA-F]+').Value
                            $crashEvents += [pscustomobject]@{ category=$def.Cat; time=$e.TimeCreated.ToString('o'); bugcheck=$code; sample=(($e.Message -replace '\s+',' ').Substring(0,[Math]::Min(300,$e.Message.Length))) }
                        }
                    } else {
                        $crashEvents += [pscustomobject]@{ category=$def.Cat; count=$ev.Count; sample=(($ev[0].Message -replace '\s+',' ').Substring(0,[Math]::Min(200,$ev[0].Message.Length))) }
                    }
                }
            }
        } catch {}
        [pscustomobject]@{ minidumps=$dumps; memoryDump=$memDump; werReports=$wer; pagefile=$pagefile; dumpConfig=$dumpConfig; crashEvents=$crashEvents }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
