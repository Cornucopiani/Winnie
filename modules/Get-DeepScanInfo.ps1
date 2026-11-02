function Get-DeepScanInfo {
    [CmdletBinding()]
    param()
    try {
        $sfc = $null
        try { $sfc = (sfc /verifyonly 2>&1) -join "`n" } catch {}
        $dism = $null
        try { $dism = (DISM /Online /Cleanup-Image /CheckHealth 2>&1) -join "`n" } catch {}
        $chkdsk = $null
        try {
            $vols = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter }
            $chkdsk = foreach ($v in $vols) { "--- $($v.DriveLetter): ---"; (chkdsk "$($v.DriveLetter):" /scan 2>&1) -join "`n" }
        } catch {}
        $energy = $null
        try { $energy = (powercfg /energy /output (Join-Path $env:TEMP 'energy-report.html') 2>&1) -join "`n" } catch {}
        [pscustomobject]@{
            sfc     = if ($sfc) { $sfc.Substring(0,[Math]::Min(4000,$sfc.Length)) } else { $null }
            dism    = if ($dism) { $dism.Substring(0,[Math]::Min(4000,$dism.Length)) } else { $null }
            chkdsk  = if ($chkdsk) { ($chkdsk -join "`n").Substring(0,[Math]::Min(8000,($chkdsk -join "`n").Length)) } else { $null }
            energy  = if ($energy) { $energy.Substring(0,[Math]::Min(2000,$energy.Length)) } else { $null }
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
