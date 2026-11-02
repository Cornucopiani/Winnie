function Get-NetworkDeepInfo {
    [CmdletBinding()]
    param()
    try {
        $routes = @(Get-NetRoute -ErrorAction SilentlyContinue | Select-Object -First 80 DestinationPrefix, NextHop, RouteMetric, InterfaceAlias, AddressFamily)
        $conns = @(Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $_.State -in 'Established','Listen' } |
            Select-Object -First 100 LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess,
            @{n='Process';e={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}}
        )
        $wifi = $null
        try { $wifi = (netsh wlan show interfaces) -join "`n" } catch {}
        $shares = @(Get-SmbShare -ErrorAction SilentlyContinue | Select-Object Name, Path, Description)
        $timeSync = $null
        try { $timeSync = (w32tm /query /status 2>&1) -join "`n" } catch {}
        $hosts = $null
        try { $hosts = Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue } catch {}
        [pscustomobject]@{
            routes       = $routes
            connections  = $conns
            wifi         = if ($wifi) { $wifi.Substring(0,[Math]::Min(2000,$wifi.Length)) } else { $null }
            shares       = $shares
            timeSync     = if ($timeSync) { $timeSync.Substring(0,[Math]::Min(1000,$timeSync.Length)) } else { $null }
            hostsEntries = @($hosts | Where-Object { $_ -and -not $_.TrimStart().StartsWith('#') })
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
