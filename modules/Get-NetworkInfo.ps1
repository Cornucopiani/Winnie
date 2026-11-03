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
        # DNS resolution tests
        $dnsResolution = @()
        try {
            $dnsResolution += [pscustomobject]@{ name='public (microsoft.com)'; result=(Resolve-DnsName 'microsoft.com' -ErrorAction Stop | Select-Object -First 1).IPAddress }
        } catch { $dnsResolution += [pscustomobject]@{ name='public (microsoft.com)'; result='FAILED' } }
        $domain = (Get-CimInstance Win32_ComputerSystem).Domain
        if ($domain -and $domain -ne 'WORKGROUP') {
            try { $dnsResolution += [pscustomobject]@{ name="domain ($domain)"; result=(Resolve-DnsName $domain -ErrorAction Stop | Select-Object -First 1).IPAddress } }
            catch { $dnsResolution += [pscustomobject]@{ name="domain ($domain)"; result='FAILED' } }
            # port tests to DC
            $portTests = @()
            try {
                $dc = (Resolve-DnsName "_ldap._tcp.dc._msdcs.$domain" -Type SRV -ErrorAction Stop | Select-Object -First 1).NameTarget
                foreach ($port in 88,389,445,53) {
                    $t = Test-NetConnection -ComputerName $dc -Port $port -WarningAction SilentlyContinue
                    $portTests += [pscustomobject]@{ dc=$dc; port=$port; success=[bool]$t.TcpTestSucceeded; latency=$t.PingReplyDetails.RoundtripTime }
                }
            } catch {}
        }
        # Wi-Fi signal
        $wifi = $null
        try { $wifi = (netsh wlan show interfaces 2>&1) -join "`n" } catch {}
        if ($wifi) { $wifi = $wifi.Substring(0,[Math]::Min(1500,$wifi.Length)) }
        # VPN state (rough: RAS connections)
        $vpn = $null
        try { $vpn = @(Get-VpnConnection -ErrorAction SilentlyContinue | Select-Object Name, ConnectionStatus) } catch { $vpn = @() }
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
            dnsResolution = $dnsResolution
            portTests = if ($portTests) { $portTests } else { @() }
            wifi = $wifi
            vpn = $vpn
            domain = $domain
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
