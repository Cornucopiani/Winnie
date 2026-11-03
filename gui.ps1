# gui.ps1 - Windows Forms GUI wrapper for the IT Support Toolkit
# Run: powershell -ExecutionPolicy Bypass -File .\gui.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$root = $null
if ($PSScriptRoot) { $root = $PSScriptRoot }
elseif ($PSCommandPath) { $root = Split-Path -Parent $PSCommandPath }
else {
    try { $root = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) } catch {}
}
if (-not $root) { $root = (Get-Location).Path }
$collectPath = $null
if ($root) { try { $collectPath = Join-Path $root 'collect.ps1' } catch {} }
# Fallback: search current directory if collect.ps1 not found
if (-not $collectPath -or -not (Test-Path -LiteralPath $collectPath)) {
    $found = Get-ChildItem -Path (Get-Location).Path -Filter 'collect.ps1' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $collectPath = $found.FullName; $root = $found.DirectoryName }
}
if (-not $collectPath) { $collectPath = 'collect.ps1' }
if (-not $root) { $root = (Get-Location).Path }
$dataPath = if ($root) { Join-Path $root 'output\data.json' } else { 'output\data.json' }
$dashboardPath = if ($root) { Join-Path $root 'output\dashboard.html' } else { 'output\dashboard.html' }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Test-Elevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------- Form ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'IT Support Toolkit'
$form.Size = New-Object System.Drawing.Size(720, 560)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

function New-Label($text, $x, $y, $w=200, $h=22) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    return $l
}
function New-Button($text, $x, $y, $w=200, $h=34) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, $h)
    $b.FlatStyle = 'Flat'
    return $b
}

$title = New-Label 'IT Support Toolkit' 12 12 400 28
$title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($title)

$sub = New-Label 'Portable Windows diagnostics - dashboard - AI summary' 12 44 500 20
$sub.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($sub)

$elevLabel = New-Label '' 520 16 180 20
$elevLabel.TextAlign = 'MiddleRight'
if (Test-Elevated) {
    $elevLabel.Text = 'Elevated'
    $elevLabel.ForeColor = [System.Drawing.Color]::Green
} else {
    $elevLabel.Text = 'Not elevated'
    $elevLabel.ForeColor = [System.Drawing.Color]::OrangeRed
}
$form.Controls.Add($elevLabel)

$btnRun = New-Button 'Run Diagnostics' 12 80 210 40
$btnDash = New-Button 'Open Dashboard' 234 80 210 40
$btnSum = New-Button 'Generate AI Summary' 456 80 210 40
$btnAna = New-Button 'Analyze (API)' 12 128 210 40
$btnFolder = New-Button 'Open Output Folder' 234 128 210 40
$btnElev = New-Button 'Restart as Admin' 456 128 210 40
$form.Controls.AddRange(@($btnRun,$btnDash,$btnSum,$btnAna,$btnFolder,$btnElev))

# Mode selector
$modeLabel = New-Label 'Mode:' 12 170 50 20
$form.Controls.Add($modeLabel)
$modeCombo = New-Object System.Windows.Forms.ComboBox
$modeCombo.Location = New-Object System.Drawing.Point(60, 168)
$modeCombo.Size = New-Object System.Drawing.Size(120, 24)
$modeCombo.DropDownStyle = 'DropDownList'
$modeCombo.Items.AddRange(@('Quick','Deep'))
$modeCombo.SelectedIndex = 0
$form.Controls.Add($modeCombo)
$deepCheck = New-Object System.Windows.Forms.CheckBox
$deepCheck.Text = 'Deep scan (SFC/DISM/chkdsk - slow)'
$deepCheck.Location = New-Object System.Drawing.Point(190, 170)
$deepCheck.Size = New-Object System.Drawing.Size(260, 20)
$deepCheck.Enabled = $false
$form.Controls.Add($deepCheck)
$modeCombo.Add_SelectedIndexChanged({ $deepCheck.Enabled = ($modeCombo.SelectedItem -eq 'Deep') })

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(12, 196)
$progress.Size = New-Object System.Drawing.Size(696, 18)
$progress.Style = 'Marquee'
$progress.MarqueeAnimationSpeed = 0
$form.Controls.Add($progress)

$status = New-Label 'Ready.' 12 218 696 20
$status.ForeColor = [System.Drawing.Color]::LightGray
$form.Controls.Add($status)

$log = New-Object System.Windows.Forms.TextBox
$log.Location = New-Object System.Drawing.Point(12, 244)
$log.Size = New-Object System.Drawing.Size(696, 290)
$log.Multiline = $true
$log.ScrollBars = 'Vertical'
$log.ReadOnly = $true
$log.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$log.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
$log.Font = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.Add($log)

function Append-Log($text) {
    $log.AppendText($text + "`r`n")
    $log.ScrollToCaret()
}

# ---------- Timer-based collection (avoids PowerShell runspace issues) ----------
$script:proc = $null
$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 100
$script:timer.Add_Tick({
    if ($null -eq $script:proc) { return }
    # drain stdout
    while ($script:proc.StandardOutput.Peek() -ne -1) {
        $line = $script:proc.StandardOutput.ReadLine()
        if ($line) { Append-Log $line }
    }
    while ($script:proc.StandardError.Peek() -ne -1) {
        $line = $script:proc.StandardError.ReadLine()
        if ($line) { Append-Log "STDERR: $line" }
    }
    if ($script:proc.HasExited) {
        $script:timer.Stop()
        $progress.Style = 'Blocks'
        $progress.Value = 100
        $progress.MarqueeAnimationSpeed = 0
        $btnRun.Enabled = $true
        $btnSum.Enabled = $true
        $btnAna.Enabled = $true
        try {
            if (Test-Path $dataPath) {
                $d = Get-Content $dataPath -Raw | ConvertFrom-Json
                $status.Text = "Done. Health score: $($d.health.score)/100 | Issues: $($d.health.issues.Count)"
                Append-Log "----- Health score: $($d.health.score)/100, $($d.health.issues.Count) issues -----"
            } else {
                $status.Text = 'Done (no data.json produced)'
            }
        } catch {
            $status.Text = 'Done.'
            Append-Log "Finalize error: $($_.Exception.Message)"
        }
        $script:proc = $null
    }
})

# ---------- Button handlers ----------
$btnRun.Add_Click({
    try {
    Append-Log '>>> Run button clicked'
    if (-not (Test-Path $collectPath)) {
        Append-Log "ERROR: collect.ps1 not found. Root='$root' CollectPath='$collectPath'"
        return
    }
    $btnRun.Enabled = $false
    $btnSum.Enabled = $false
    $btnAna.Enabled = $false
    $progress.Style = 'Marquee'
    $progress.MarqueeAnimationSpeed = 30
    $progress.Value = 0
    $status.Text = 'Collecting diagnostics...'
    Append-Log '=== Starting collection ==='
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $mode = $modeCombo.SelectedItem
    $args = "-NoLogo -ExecutionPolicy Bypass -NoProfile -File `"$collectPath`" -Mode $mode"
    if ($deepCheck.Checked) { $args += " -DeepScan" }
    $psi.Arguments = $args
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $script:proc = [System.Diagnostics.Process]::Start($psi)
    $script:timer.Start()
    } catch { Append-Log "RUN ERROR: $($_.Exception.Message)" }
})

$btnDash.Add_Click({
    if (Test-Path $dashboardPath) {
        Start-Process $dashboardPath
    } else {
        [System.Windows.Forms.MessageBox]::Show('Run diagnostics first.', 'No dashboard') | Out-Null
    }
})

$btnSum.Add_Click({
    $btnSum.Enabled = $false
    $status.Text = 'Generating AI summary...'
    Append-Log '=== Generating summary ==='
    try {
        & (Join-Path $root 'ai\summarize.ps1')
        Append-Log 'Summary written to output\summary.md'
        $status.Text = 'Summary generated.'
    } catch {
        Append-Log "ERROR: $($_.Exception.Message)"
        $status.Text = 'Summary failed.'
    }
    $btnSum.Enabled = $true
})

$btnAna.Add_Click({
    $btnAna.Enabled = $false
    $status.Text = 'Running AI analysis...'
    Append-Log '=== AI analysis ==='
    try {
        & (Join-Path $root 'ai\analyze.ps1')
        Append-Log 'Analysis written to output\analysis.md'
        $status.Text = 'Analysis complete.'
    } catch {
        Append-Log "ERROR: $($_.Exception.Message)"
        $status.Text = 'Analysis failed.'
    }
    $btnAna.Enabled = $true
})

$btnFolder.Add_Click({
    $out = Join-Path $root 'output'
    if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out -Force | Out-Null }
    Start-Process explorer.exe $out
})

$btnElev.Add_Click({
    if (Test-Elevated) {
        [System.Windows.Forms.MessageBox]::Show('Already elevated.', 'Info') | Out-Null
        return
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = 'runas'
    $psi.UseShellExecute = $true
    try { [System.Diagnostics.Process]::Start($psi) | Out-Null; $form.Close() } catch {}
})

$form.AcceptButton = $btnRun
$form.Add_Shown({ $form.Activate(); $btnRun.Focus(); Append-Log "Root: $root"; Append-Log "CollectPath: $collectPath"; Append-Log "DataPath: $dataPath" })
[void]$form.ShowDialog()
