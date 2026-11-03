function Get-IdentityInfo {
    [CmdletBinding()]
    param()
    try {
        $dsreg = $null
        try { $dsreg = (dsregcmd /status 2>&1) -join "`n" } catch {}
        $parsed = @{}
        if ($dsreg) {
            foreach ($line in ($dsreg -split "`n")) {
                if ($line -match '^\s*(AzureAdJoined|DomainJoined|AzureAdPrt|TenantName|DeviceAuthStatus|EnterpriseJoined)\s*:\s*(.+)$') {
                    $parsed[$matches[1]] = $matches[2].Trim()
                }
            }
        }
        $secureChannel = $null
        try { $secureChannel = Test-ComputerSecureChannel -ErrorAction Stop } catch { $secureChannel = 'error' }
        $dcInfo = $null
        try {
            $cs = Get-CimInstance Win32_ComputerSystem
            if ($cs.PartOfDomain) { $dcInfo = (nltest /dsgetdc:$($cs.Domain) 2>&1) -join "`n" }
        } catch {}
        $timeSync = $null
        try { $timeSync = (w32tm /query /status 2>&1) -join "`n" } catch {}
        # Office activation / ClickToRun
        $officeConfig = $null
        try {
            $cr = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' -ErrorAction Stop
            $officeConfig = [pscustomobject]@{ version=$cr.VersionToReport; channel=$cr.UpdateChannel; platform=$cr.Platform; cdn=$cr.UpdateUrl }
        } catch {}
        $ospp = $null
        $osppPath = Get-ChildItem 'C:\Program Files\Microsoft Office\Office*' -Filter 'ospp.vbs' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($osppPath) { try { $ospp = (cscript //nologo $osppPath.FullName /dstatus 2>&1) -join "`n" } catch {} }
        # OneDrive sync state
        $oneDrive = $null
        try {
            $od = Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue
            $oneDrive = [pscustomobject]@{ running=[bool]$od; count=($od | Measure-Object).Count }
        } catch {}
        # OST size
        $ostSize = $null
        try {
            $ost = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Outlook" -Filter '*.ost' -ErrorAction SilentlyContinue
            $ostSize = @($ost | ForEach-Object { [pscustomobject]@{ name=$_.Name; sizeMB=[math]::Round($_.Length/1MB,1) } })
        } catch {}
        [pscustomobject]@{
            dsreg       = if ($dsreg) { $dsreg.Substring(0,[Math]::Min(4000,$dsreg.Length)) } else { $null }
            dsregParsed = if ($parsed.Count) { $parsed } else { $null }
            secureChannel = $secureChannel
            dcInfo      = if ($dcInfo) { $dcInfo.Substring(0,[Math]::Min(2000,$dcInfo.Length)) } else { $null }
            timeSync    = if ($timeSync) { $timeSync.Substring(0,[Math]::Min(1000,$timeSync.Length)) } else { $null }
            officeConfig= $officeConfig
            ospp        = if ($ospp) { $ospp.Substring(0,[Math]::Min(3000,$ospp.Length)) } else { $null }
            oneDrive    = $oneDrive
            ostFiles    = $ostSize
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
