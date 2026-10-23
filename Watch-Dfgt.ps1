$ErrorActionPreference = 'Stop'
$mutex = [Threading.Mutex]::new($false, 'Local\DfgtNativeAutoSwitch')
$held = $false
try {
    try { $held = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $held = $true }
    if (-not $held) { return }
    $switch = Join-Path $PSScriptRoot 'Switch-DfgtNative.ps1'
    if (-not (Test-Path -LiteralPath $switch -PathType Leaf)) { throw 'Switch script missing.' }
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $log = Join-Path $PSScriptRoot 'AutoSwitch.log'
    while ($true) {
        try {
            $fallback = @(Get-PnpDevice -PresentOnly -ErrorAction Stop |
                Where-Object { $_.InstanceId -like 'HID\VID_046D&PID_C294\*' })
            if ($fallback.Count -gt 0) {
                if ((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log).Length -gt 262144) {
                    Set-Content -LiteralPath $log -Value ''
                }
                Add-Content -LiteralPath $log -Value "$(Get-Date -Format o) C294 detected; switching"
                $result = & $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $switch 2>&1
                $code = $LASTEXITCODE
                Add-Content -LiteralPath $log -Value ($result | Out-String)
                if ($code -ne 0) { throw "Switch process exit code: $code" }
                $range = Join-Path $PSScriptRoot 'Set-DfgtRange.ps1'
                $rangeResult = & $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $range -Degrees 360 -AutoCenter Off 2>&1
                $rangeCode = $LASTEXITCODE
                Add-Content -LiteralPath $log -Value ($rangeResult | Out-String)
                if ($rangeCode -ne 0) { throw "Range process exit code: $rangeCode" }
                Start-Sleep -Seconds 15
            }
        } catch {
            Add-Content -LiteralPath $log -Value "$(Get-Date -Format o) $($_.Exception.Message)"
            Start-Sleep -Seconds 30
        }
        Start-Sleep -Seconds 10
    }
} finally {
    if ($held) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
