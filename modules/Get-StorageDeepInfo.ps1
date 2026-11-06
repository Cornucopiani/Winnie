function Get-StorageDeepInfo {
    [CmdletBinding()]
    param()
    try {
        $removable = @(Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -in 'Removable','CD-ROM' } | Select-Object DriveLetter, FileSystemLabel, DriveType, @{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}}, @{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB,2)}})
        $topFolders = @(Get-ChildItem 'C:\' -Directory -ErrorAction SilentlyContinue | Select-Object -First 20 -ExpandProperty Name)
        [pscustomobject]@{
            removableVolumes = $removable
            topFolders       = $topFolders
            diskImages       = @()
            dismComponentStore = $null
            shadowStorage     = $null
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
