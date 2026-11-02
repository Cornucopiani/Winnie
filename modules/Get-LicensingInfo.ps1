function Get-LicensingInfo {
    [CmdletBinding()]
    param()
    try {
        $os = Get-CimInstance SoftwareLicensingProduct -ErrorAction SilentlyContinue | Where-Object { $_.PartialProductKey } | Select-Object -First 5
        $winLicense = @($os | ForEach-Object {
            [pscustomobject]@{
                name          = $_.Name
                description   = $_.Description
                licenseStatus = $_.LicenseStatus
                partialKey    = $_.PartialProductKey
                gracePeriod   = $_.GracePeriodRemaining
            }
        })
        # BIOS OEM key
        $oemKey = $null
        try { $oemKey = (Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey } catch {}
        # slmgr /dlv (text)
        $slmgr = $null
        try { $slmgr = (cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /dlv 2>&1) -join "`n" } catch {}
        # Office (ospp)
        $office = $null
        $ospp = Get-ChildItem 'C:\Program Files\Microsoft Office\Office*' -Filter 'ospp.vbs' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ospp) {
            try { $office = (cscript //nologo $ospp.FullName /dstatus 2>&1) -join "`n" } catch {}
        }
        [pscustomobject]@{
            windows = $winLicense
            oemKey  = if ($oemKey) { '****' + $oemKey.Substring([Math]::Max(0,$oemKey.Length-5)) } else { $null }
            slmgr   = if ($slmgr) { $slmgr.Substring(0,[Math]::Min(2000,$slmgr.Length)) } else { $null }
            office  = if ($office) { $office.Substring(0,[Math]::Min(2000,$office.Length)) } else { $null }
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
