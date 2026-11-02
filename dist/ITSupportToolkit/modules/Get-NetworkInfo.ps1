function Get-NetworkInfo {
    [CmdletBinding()]
    param([string[]]$PingTargets = @('8.8.8.8','1.1.1.1'))
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress
        $ipcfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue
        $dns = Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses } |
            Select-Object InterfaceAlias, @{n='Servers';e={$_.ServerAddresses -join ', '}}
        # ping tests
        $pings = @()
        foreach ($t in $PingTargets) {
            if ($t -eq 'gateway') {
                $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
                if ($gw) { $t = $gw }
            }
            $r = Test-Connection -ComputerName $t -Count 2 -ErrorAction SilentlyContinue
            $pings += [pscustomobject]@{
                target  = $t
                success = [bool]$r
                latency = if ($r) { [math]::Round(($r | Measure-Object -Property ResponseTime -Average).Average,1) } else { $null }
            }
        }
        # listening ports (top)
        $ports = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Select-Object LocalAddress, LocalPort, OwningProcess |
            Sort-Object LocalPort | Select-Object -First 60
        $portList = @($ports | ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
            [pscustomobject]@{
                address = $_.LocalAddress
                port    = $_.LocalPort
                pid     = $_.OwningProcess
                process = $proc.ProcessName
            }
        })
        # proxy
        $proxy = $null
        try { $proxy = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop).ProxyServer } catch {}
        [pscustomobject]@{
            adapters = @($adapters | ForEach-Object {
                [pscustomobject]@{ name=$_.Name; desc=$_.InterfaceDescription; status=$_.Status; speed=$_.LinkSpeed; mac=$_.MacAddress }
            })
            ipConfig = @($ipcfg | ForEach-Object {
                [pscustomobject]@{
                    alias   = $_.InterfaceAlias
                    ipv4    = $_.IPv4Address.IPAddress
                    ipv6    = $_.IPv6Address.IPAddress
                    gateway = $_.IPv4DefaultGateway.NextHop
                }
            })
            dns = @($dns | ForEach-Object { [pscustomobject]@{ alias=$_.InterfaceAlias; servers=$_.Servers } })
            pings = $pings
            listeningPorts = $portList
            proxy = $proxy
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
