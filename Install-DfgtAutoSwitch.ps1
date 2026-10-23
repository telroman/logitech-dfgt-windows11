param([switch]$RestorePointChecked)
$ErrorActionPreference = 'Stop'
if (-not $RestorePointChecked) {
    throw 'First verify a recent Windows restore point, then run with -RestorePointChecked.'
}
$name = 'DFGT Native AutoSwitch'
if (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) {
    throw 'Task already exists. Inspect it before making changes.'
}
$watch = Join-Path $PSScriptRoot 'Watch-Dfgt.ps1'
$switch = Join-Path $PSScriptRoot 'Switch-DfgtNative.ps1'
foreach ($file in @($watch, $switch)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing: $file" }
}
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$action = New-ScheduledTaskAction -Execute $ps -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $watch) -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Switch DFGT C294 to C29A; after switching apply 360 degrees and disable autocenter. Keep Microsoft HID drivers.' | Out-Null
Start-ScheduledTask -TaskName $name
Get-ScheduledTask -TaskName $name | Select-Object TaskName,State

