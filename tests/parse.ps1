param([string]$File = 'gui.ps1')
$errors = $null
$tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile($File, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors) { $errors | ForEach-Object { Write-Host "$File : $($_.Message)" } } else { Write-Host "$File parses OK" }
