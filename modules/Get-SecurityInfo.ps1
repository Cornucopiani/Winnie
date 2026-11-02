function Get-SecurityInfo {
    [CmdletBinding()]
    param()
    try {
        $fw = Get-NetFirewallProfile -ErrorAction SilentlyContinue | Select-Object Name, Enabled
        $defender = $null
        try { $defender = Get-MpComputerStatus -ErrorAction Stop } catch {}
        $bitlocker = $null
        try { $bitlocker = Get-BitLockerVolume -ErrorAction Stop | Select-Object MountPoint, VolumeStatus, ProtectionStatus } catch {}
        $secureBoot = $null
        try { $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop } catch { $secureBoot = 'unknown/unsupported' }
        $tpm = $null
        try { $tpm = Get-Tpm -ErrorAction Stop } catch {}
        $uac = $null
        try {
            $uac = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction Stop).EnableLUA
        } catch {}
        [pscustomobject]@{
            firewall = @($fw | ForEach-Object { [pscustomobject]@{ profile=$_.Name; enabled=[bool]$_.Enabled } })
            defender = if ($defender) {
                [pscustomobject]@{
                    realTimeProtection = $defender.RealTimeProtectionEnabled
                    antivirusEnabled   = $defender.AntivirusEnabled
                    antispywareEnabled = $defender.AntispywareEnabled
                    definitionsUpdated = $defender.AntivirusSignatureLastUpdated
                    quickScanAge       = $defender.QuickScanAge
                    fullScanAge        = $defender.FullScanAge
                }
            } else { $null }
            bitlocker = @($bitlocker | ForEach-Object { [pscustomobject]@{ drive=$_.MountPoint; status=$_.VolumeStatus; protection=$_.ProtectionStatus } })
            secureBoot = $secureBoot
            tpm = if ($tpm) { [pscustomobject]@{ present=$tpm.TpmPresent; ready=$tpm.TpmReady; enabled=$tpm.TpmEnabled } } else { $null }
            uacEnabled = if ($uac -ne $null) { [bool]$uac } else { $null }
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
