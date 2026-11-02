function Get-SmartInfo {
    [CmdletBinding()]
    param()
    try {
        $status = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop)
        if ($status.Count -eq 0) { return [pscustomobject]@{ disks = @(); note = 'no SMART data (MSStorageDriver not available)' } }
        $fdata  = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictData -ErrorAction SilentlyContinue)
        $fthr   = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictThresholds -ErrorAction SilentlyContinue)
        $drives = @(Get-CimInstance Win32_DiskDrive)
        $attrNames = @{
            1='Raw_Read_Error_Rate'; 3='Spin_Up_Time'; 4='Start_Stop_Count'; 5='Reallocated_Sector_Count'
            9='Power_On_Hours'; 12='Power_Cycle_Count'; 177='Wear_Leveling_Count'; 187='Reported_Uncorrectable'
            188='Command_Timeout'; 190='Airflow_Temperature'; 192='Power-Off_Retract_Count'; 193='Load_Cycle_Count'
            194='Temperature_Celsius'; 196='Reallocated_Event_Count'; 197='Current_Pending_Sector'; 198='Offline_Uncorrectable'
            199='UDMA_CRC_Error_Count'; 231='SSD_Life_Left'; 232='Available_Reserved_Space'; 233='Media_Wearout_Indicator'
        }
        $disks = @()
        foreach ($s in $status) {
            $inst = $s.InstanceName
            $drive = $drives | Where-Object { $_.PNPDeviceID -and $inst -like "$($_.PNPDeviceID)*" } | Select-Object -First 1
            $fd = $fdata | Where-Object { $_.InstanceName -eq $inst } | Select-Object -First 1
            $t  = $fthr  | Where-Object { $_.InstanceName -eq $inst } | Select-Object -First 1
            $tmap = @{}
            if ($t -and $t.VendorSpecific) {
                $tb = [byte[]]$t.VendorSpecific
                for ($o = 2; ($o + 11) -lt $tb.Length; $o += 12) { if ($tb[$o] -ne 0) { $tmap[[int]$tb[$o]] = [int]$tb[$o + 1] } }
            }
            $attrs = @()
            if ($fd -and $fd.VendorSpecific) {
                $bytes = [byte[]]$fd.VendorSpecific
                for ($o = 2; ($o + 11) -lt $bytes.Length; $o += 12) {
                    $id = [int]$bytes[$o]
                    if ($id -eq 0) { continue }
                    $raw = [uint64]0
                    for ($b = 5; $b -ge 0; $b--) { $raw = ($raw -shl 8) -bor [uint64]$bytes[$o + 1 + 4 + $b] }
                    $flags = [int]$bytes[$o + 1] + ([int]$bytes[$o + 2] -shl 8)
                    $attrs += [pscustomobject]@{
                        id        = $id
                        name      = $attrNames[$id]
                        current   = [int]$bytes[$o + 3]
                        worst     = [int]$bytes[$o + 4]
                        threshold = $tmap[$id]
                        raw       = $raw
                        preFail   = [bool]($flags -band 1)
                    }
                }
            }
            $disks += [pscustomobject]@{
                instanceName   = $inst
                model          = $drive.Model
                diskIndex      = $drive.Index
                predictFailure = $s.PredictFailure
                reason         = $s.Reason
                attributes     = $attrs
            }
        }
        [pscustomobject]@{ disks = $disks }
    } catch {
        [pscustomobject]@{ error = $_.Exception.Message; disks = @() }
    }
}
