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
        [pscustomobject]@{
            auditPolicy    = if ($audit) { $audit.Substring(0,[Math]::Min(4000,$audit.Length)) } else { $null }
            dsregStatus    = if ($dsreg) { $dsreg.Substring(0,[Math]::Min(4000,$dsreg.Length)) } else { $null }
            avProducts     = $avProducts
            hardening      = $hardening
            passwordPolicy = if ($passwordPolicy) { $passwordPolicy.Substring(0,[Math]::Min(1000,$passwordPolicy.Length)) } else { $null }
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
