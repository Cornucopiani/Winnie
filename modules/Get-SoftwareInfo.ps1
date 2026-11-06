function Get-SoftwareInfo {
    [CmdletBinding()]
    param()
    try {
        $paths = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $apps = @()
        foreach ($p in $paths) {
            try {
                $apps += Get-ItemProperty $p -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName } |
                    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, EstimatedSize
            } catch {}
        }
        $apps = $apps | Sort-Object DisplayName -Unique
        # startup items
        $startup = @()
        try {
            $startup += Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
                Select-Object Name, Command, Location, User |
                Sort-Object Location, Name -Unique
        } catch {}
        [pscustomobject]@{
            count = $apps.Count
            apps = @($apps | Select-Object -First 200 | ForEach-Object {
                [pscustomobject]@{
                    name     = $_.DisplayName
                    version  = $_.DisplayVersion
                    publisher= $_.Publisher
                    installed= $_.InstallDate
                    sizeKB   = $_.EstimatedSize
                }
            })
            startup = @($startup | ForEach-Object {
                [pscustomobject]@{ name=$_.Name; command=$_.Command; location=$_.Location; user=$_.User }
            })
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
