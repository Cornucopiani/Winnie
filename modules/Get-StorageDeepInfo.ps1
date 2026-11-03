function Get-StorageDeepInfo {
    [CmdletBinding()]
    param()
    try {
        # volume filtering: skip recovery/removable in main list (already in storage), report separately here
        $removable = @(Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -in 'Removable','CD-ROM' } | Select-Object DriveLetter, FileSystemLabel, DriveType, @{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}}, @{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB,2)}})
        # top-level folder sizes on C:
        $topFolders = @()
        try {
            $topFolders = @(Get-ChildItem 'C:\' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                [pscustomobject]@{ folder=$_.Name; sizeGB=[math]::Round($size/1GB,2) }
            } | Sort-Object sizeGB -Descending | Select-Object -First 15)
        } catch {}
        # VHD/VMDK/WSL/Docker images
        $images = @()
        try {
            $images = @(Get-ChildItem 'C:\' -Recurse -Include '*.vhdx','*.vmdk','*.vhd' -File -ErrorAction SilentlyContinue | Select-Object -First 20 FullName, @{n='SizeGB';e={[math]::Round($_.Length/1GB,2)}})
        } catch {}
        # DISM component store
        $dism = $null
        try { $dism = (DISM /Online /Cleanup-Image /AnalyzeComponentStore 2>&1) -join "`n" } catch {}
        if ($dism) { $dism = $dism.Substring(0,[Math]::Min(3000,$dism.Length)) }
        # shadow copy usage
        $shadows = $null
        try { $shadows = (vssadmin list shadowstorage 2>&1) -join "`n" } catch {}
        if ($shadows) { $shadows = $shadows.Substring(0,[Math]::Min(2000,$shadows.Length)) }
        [pscustomobject]@{
            removableVolumes = $removable
            topFolders       = $topFolders
            diskImages       = $images
            dismComponentStore = $dism
            shadowStorage     = $shadows
        }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message }
    }
}
