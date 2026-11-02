function Get-SmartctlInfo {
    [CmdletBinding()]
    param([string]$PreferredPath)
    $exe = $null
    # Find-Executable is defined in collect.ps1; fall back to local search
    if (Get-Command Find-Executable -ErrorAction SilentlyContinue) {
        $candidates = @()
        if ($PSScriptRoot) { $candidates += (Join-Path $PSScriptRoot 'smartctl.exe') }
        $candidates += "$env:ProgramFiles\smartmontools\bin\smartctl.exe"
        $candidates += "${env:ProgramFiles(x86)}\smartmontools\bin\smartctl.exe"
        $exe = Find-Executable -Preferred $PreferredPath -Names @('smartctl.exe') -Candidates $candidates
    } else {
        $exe = Get-Command smartctl.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    }
    if (-not $exe) {
        return [pscustomobject]@{ available = $false; path = $null; devices = @(); note = 'smartctl not found (optional)' }
    }
    $devices = @()
    try {
        $scan = (& $exe --scan -j 2>$null) -join "`n"
        $parsed = $scan | ConvertFrom-Json
        foreach ($dev in @($parsed.devices)) {
            $raw = (& $exe -a -j -d $dev.type $dev.name 2>$null) -join "`n"
            $j = $null
            try { $j = $raw | ConvertFrom-Json } catch {}
            $nv = if ($j) { $j.nvme_smart_health_information_log } else { $null }
            $devices += [pscustomobject]@{
                name            = $dev.name
                type            = $dev.type
                model           = if ($j) { $j.model_name } else { $null }
                serial          = if ($j) { $j.serial_number } else { $null }
                smartPassed     = if ($j -and $j.smart_status) { $j.smart_status.passed } else { $null }
                percentageUsed  = if ($nv) { $nv.percentage_used } else { $null }
                mediaErrors     = if ($nv) { $nv.media_errors } else { $null }
                availableSpare  = if ($nv) { $nv.available_spare } else { $null }
                criticalWarning = if ($nv) { $nv.critical_warning } else { $null }
            }
        }
    } catch {
        return [pscustomobject]@{ available = $true; path = $exe; error = $_.Exception.Message; devices = @() }
    }
    [pscustomobject]@{ available = $true; path = $exe; devices = $devices }
}
