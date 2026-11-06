function Invoke-TimedCommand {
    param([string]$FilePath, [string[]]$Arguments = @(), [int]$TimeoutSec = 20)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = ($Arguments -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch {}
        return "[timed out after ${TimeoutSec}s]"
    }
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    if ($err) { $out += "`n$err" }
    $out
}

function Get-MspInfo {
    [CmdletBinding()]
    param()
    try {
        # printers
        $printers = @()
        try {
            $printers = @(Get-Printer -ErrorAction Stop | ForEach-Object {
                $st = $_.PrinterStatus
                $statusText = switch ($st) { 0 {'Normal'} 1 {'Paused'} 2 {'Error'} 8 {'Offline'} 18 {'TonerLow'} 19 {'NoToner'} default {"Unknown($st)"} }
                [pscustomobject]@{ Name=$_.Name; DriverName=$_.DriverName; PortName=$_.PortName; PrinterStatus=$statusText; RawStatus=$st; Shared=$_.Shared }
            })
        } catch {}
        $stuckJobs = @()
        try { $stuckJobs = @(Get-PrintJob -ErrorAction SilentlyContinue | Where-Object { $_.JobStatus -ne 'Normal' } | Select-Object PrinterName, Id, JobStatus, Size) } catch {}
        # VSS writers (timed)
        $vss = $null
        try { $vss = Invoke-TimedCommand -FilePath 'vssadmin.exe' -Arguments @('list','writers') -TimeoutSec 15 } catch {}
        # shadow copies (timed)
        $shadows = $null
        try { $shadows = Invoke-TimedCommand -FilePath 'vssadmin.exe' -Arguments @('list','shadows') -TimeoutSec 15 } catch {}
        # server roles (only on servers; fast)
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
        # winget upgrade (timed, optional)
        $winget = $null
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try { $winget = Invoke-TimedCommand -FilePath 'winget' -Arguments @('upgrade','--accept-source-agreements','--disable-interactivity') -TimeoutSec 30 } catch {}
            if ($winget) { $winget = $winget.Substring(0,[Math]::Min(4000,$winget.Length)) }
        }
        # certificates expiring soon
        $certs = @()
        try {
            $certs = @(Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Where-Object { $_.NotAfter -lt (Get-Date).AddDays(30) } | Select-Object Subject, NotAfter, Thumbprint)
        } catch {}
        [pscustomobject]@{
            printers        = $printers
            stuckPrintJobs  = $stuckJobs
            vssWriters      = if ($vss) { $vss.Substring(0,[Math]::Min(4000,$vss.Length)) } else { $null }
            shadowCopies     = if ($shadows) { $shadows.Substring(0,[Math]::Min(2000,$shadows.Length)) } else { $null }
            serverRoles     = $roles
            duplicateAgents = $dupAgents
            wingetUpgrade   = $winget
            expiringCerts   = $certs
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
