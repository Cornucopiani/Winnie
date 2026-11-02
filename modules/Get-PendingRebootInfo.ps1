function Get-PendingRebootInfo {
    [CmdletBinding()]
    param()
    try {
        $active = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -ErrorAction SilentlyContinue).ComputerName
        $newest = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -ErrorAction SilentlyContinue).ComputerName
        $cbs = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        $wu  = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        $pfr = [bool](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
        $rename = ($active -ne $newest) -and $active -and $newest
        [pscustomobject]@{
            componentBasedServicing = [bool]$cbs
            windowsUpdate          = [bool]$wu
            pendingFileRename      = $pfr
            pendingComputerRename  = [bool]$rename
            rebootPending          = [bool]($cbs -or $wu -or $pfr -or $rename)
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
