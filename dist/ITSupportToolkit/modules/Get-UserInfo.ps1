function Get-UserInfo {
    [CmdletBinding()]
    param()
    try {
        $users = Get-LocalUser -ErrorAction SilentlyContinue
        $admins = Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue
        $sessions = quser 2>$null
        [pscustomobject]@{
            users = @($users | ForEach-Object {
                [pscustomobject]@{ name=$_.Name; enabled=$_.Enabled; lastLogon=$_.LastLogon; passwordExpires=$_.PasswordExpires; description=$_.Description }
            })
            administrators = @($admins | ForEach-Object { [pscustomobject]@{ name=$_.Name; type=$_.ObjectClass } })
            activeSessions = @($sessions)
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
