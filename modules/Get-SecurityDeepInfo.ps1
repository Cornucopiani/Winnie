function Get-SecurityDeepInfo {
    [CmdletBinding()]
    param()
    try {
        $audit = $null
        try { $audit = (auditpol /get /category:* 2>&1) -join "`n" } catch {}
        $dsreg = $null
        try { $dsreg = (dsregcmd /status 2>&1) -join "`n" } catch {}
        $avProducts = @()
        try { $avProducts = @(Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop | Select-Object displayName, productState, pathToSignedProductExe) } catch {}
        $hardening = [pscustomobject]@{
            lsassRunAsPPL = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL -ErrorAction SilentlyContinue).RunAsPPL
            smb1Disabled  = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name SMB1 -ErrorAction SilentlyContinue).SMB1
            rdpEnabled    = (Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections
        }
        $passwordPolicy = $null
        try { $passwordPolicy = (net accounts 2>&1) -join "`n" } catch {}
        # local admins via net (sidesteps Get-LocalGroupMember SID resolution failures)
        $localAdmins = $null
        try { $localAdmins = (net localgroup administrators 2>&1) -join "`n" } catch {}
        # unquoted service paths
        $unquoted = @()
        try {
            $unquoted = @(Get-CimInstance Win32_Service | Where-Object { $_.PathName -and $_.PathName -notmatch '^"' -and $_.PathName -match ' ' } | Select-Object Name, PathName)
        } catch {}
        # non-Microsoft scheduled tasks
        $tasks = @()
        try {
            $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notmatch '\\Microsoft\\' -and $_.State -ne 'Disabled' } | Select-Object TaskName, TaskPath, State | Select-Object -First 40)
        } catch {}
        # BitLocker fallback
        $bitlockerFallback = $null
        try { $bitlockerFallback = (manage-bde -status 2>&1) -join "`n" } catch {}
        # RDP / NLA
        $rdp = [pscustomobject]@{
            denyTS = (Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections
            nla    = (Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -ErrorAction SilentlyContinue).UserAuthentication
        }
        # SMB1
        $smb1 = $null
        try { $smb1 = (Get-SmbServerConfiguration -ErrorAction Stop).EnableSMB1Protocol } catch {}
        # Defender threats
        $threats = @()
        try { $threats = @(Get-MpThreatDetection -ErrorAction SilentlyContinue | Select-Object -First 20 ThreatID, ProcessName, DomainUser ) } catch {}
        # TPM detail
        $tpmDetail = $null
        try { $tpmDetail = Get-Tpm -ErrorAction Stop } catch {}
        [pscustomobject]@{
            auditPolicy        = if ($audit) { $audit.Substring(0,[Math]::Min(4000,$audit.Length)) } else { $null }
            dsregStatus        = if ($dsreg) { $dsreg.Substring(0,[Math]::Min(4000,$dsreg.Length)) } else { $null }
            avProducts         = $avProducts
            hardening          = $hardening
            passwordPolicy     = if ($passwordPolicy) { $passwordPolicy.Substring(0,[Math]::Min(1000,$passwordPolicy.Length)) } else { $null }
            localAdmins        = if ($localAdmins) { $localAdmins.Substring(0,[Math]::Min(2000,$localAdmins.Length)) } else { $null }
            unquotedServices   = $unquoted
            scheduledTasks     = $tasks
            bitlockerFallback  = if ($bitlockerFallback) { $bitlockerFallback.Substring(0,[Math]::Min(2000,$bitlockerFallback.Length)) } else { $null }
            rdp                = $rdp
            smb1Enabled        = $smb1
            defenderThreats    = $threats
            tpmDetail          = if ($tpmDetail) { [pscustomobject]@{ present=$tpmDetail.TpmPresent; ready=$tpmDetail.TpmReady; enabled=$tpmDetail.TpmEnabled; activated=$tpmDetail.TpmActivated; manufacturer=$tpmDetail.ManufacturerIdTxt } } else { $null }
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
