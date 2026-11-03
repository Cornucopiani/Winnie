function Get-MspInfo {
    [CmdletBinding()]
    param()
    try {
        # printers
        $printers = @()
        try {
            $printers = @(Get-Printer -ErrorAction Stop | Select-Object Name, DriverName, PortName, PrinterStatus, Shared)
        } catch {}
        $stuckJobs = @()
        try {
            $stuckJobs = @(Get-PrintJob -ErrorAction SilentlyContinue | Where-Object { $_.JobStatus -ne 'Normal' } | Select-Object PrinterName, Id, JobStatus, Size)
        } catch {}
        # VSS writers
        $vss = $null
        try { $vss = (vssadmin list writers 2>&1) -join "`n" } catch {}
        # shadow copies
        $shadows = $null
        try { $shadows = (vssadmin list shadows 2>&1) -join "`n" } catch {}
        # server roles (auto-detect)
        $roles = $null
        try {
            if (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) {
                $roles = @(Get-WindowsFeature -ErrorAction SilentlyContinue | Where-Object { $_.Installed } | Select-Object Name, DisplayName)
            }
        } catch {}
        # software hygiene: duplicate RMM/remote/AV agents in startup
        $dupAgents = @()
        try {
            $names = @('spiceworks','teamviewer','anydesk','splashtop','logmein','connectwise','datto','kaseya','screenconnect','vnc','realvnc')
            $startup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
            foreach ($n in $names) {
                $hits = @($startup | Where-Object { $_.Name -match $n -or $_.Command -match $n })
                if ($hits.Count -gt 1) { $dupAgents += [pscustomobject]@{ agent=$n; count=$hits.Count } }
            }
        } catch {}
        # winget upgrade (if available)
        $winget = $null
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try { $winget = (winget upgrade 2>&1) -join "`n" } catch {}
            if ($winget) { $winget = $winget.Substring(0,[Math]::Min(4000,$winget.Length)) }
        }
        # certificates expiring soon
        $certs = @()
        try {
            $certs = @(Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Where-Object { $_.NotAfter -lt (Get-Date).AddDays(30) } | Select-Object Subject, NotAfter, Thumbprint)
        } catch {}
        [pscustomobject]@{
            printers     = $printers
            stuckPrintJobs = $stuckJobs
            vssWriters   = if ($vss) { $vss.Substring(0,[Math]::Min(4000,$vss.Length)) } else { $null }
            shadowCopies = if ($shadows) { $shadows.Substring(0,[Math]::Min(2000,$shadows.Length)) } else { $null }
            serverRoles  = $roles
            duplicateAgents = $dupAgents
            wingetUpgrade= $winget
            expiringCerts= $certs
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
