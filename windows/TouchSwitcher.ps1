$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$exe = Join-Path $root 'ControlMyMonitor.exe'
$log = Join-Path $root 'touch-switcher.log'
$mutex = New-Object Threading.Mutex($false, 'Local\XiaoTouchSwitcher')
if (-not $mutex.WaitOne(0)) { exit }
function Write-Log($message) {
    if ((Test-Path $log) -and (Get-Item $log).Length -gt 1MB) {
        Move-Item $log "$log.old" -Force
    }
    "$(Get-Date -Format s) $message" | Out-File $log -Append
}
function Invoke-Monitor($arguments) {
    $p = Start-Process -FilePath $exe -ArgumentList $arguments -PassThru -WindowStyle Hidden
    if (-not $p.WaitForExit(8000)) { $p.Kill(); throw 'Monitor command timed out' }
    $p.WaitForExit()
    return $p.ExitCode
}
function Switch-Input {
    $current = Invoke-Monitor '/GetValue G27q-20 60'
    if ($current -eq 15) { $target = 17 }
    elseif ($current -eq 17) { $target = 15 }
    else { throw "Cannot read input: $current. No switch sent." }
    $null = Invoke-Monitor "/SetValue G27q-20 60 $target"
    Start-Sleep -Seconds 2
    $actual = Invoke-Monitor '/GetValue G27q-20 60'
    Write-Log "Input $current -> $target; readback=$actual"
}
try {
    if (-not (Test-Path $exe)) { throw 'ControlMyMonitor.exe is missing' }
    Write-Log 'Started; waiting for XIAO'
    while ($true) {
        # Restrict discovery to Seeed USB devices; never probe unrelated serial ports.
        $devices = Get-CimInstance Win32_PnPEntity | Where-Object {
            $_.PNPDeviceID -match 'VID_2886' -and $_.Name -match '\(COM\d+\)'
        }
        foreach ($device in $devices) {
            $portName = [regex]::Match($device.Name, 'COM\d+').Value
            $port = New-Object IO.Ports.SerialPort($portName,115200,'None',8,'One')
            $port.ReadTimeout = 1500
            $port.DtrEnable = $true
            try {
                $port.Open()
                $confirmed = $false
                $deadline = (Get-Date).AddSeconds(5)
                while ((Get-Date) -lt $deadline) {
                    try { if ($port.ReadLine().Trim() -eq 'TOUCH_SWITCHER_READY_V1') { $confirmed=$true; break } }
                    catch [TimeoutException] {}
                }
                if (-not $confirmed) { continue }
                Write-Log "Connected $portName"
                $lastSeen = Get-Date
                while ($port.IsOpen) {
                    try { $line = $port.ReadLine().Trim(); $lastSeen=Get-Date }
                    catch [TimeoutException] {
                        if (((Get-Date)-$lastSeen).TotalSeconds -gt 6) { throw 'Heartbeat lost' }
                        continue
                    }
                    if ($line -eq 'TOUCH_SWITCHER_TOUCH_V1') {
                        try { Switch-Input } catch { Write-Log $_.Exception.Message }
                        $port.DiscardInBuffer() # Ignore touches queued during switching.
                    }
                }
            } catch { Write-Log "$portName : $($_.Exception.Message)" }
            finally { if ($port.IsOpen) { $port.Close() }; $port.Dispose() }
        }
        Start-Sleep -Seconds 2
    }
} catch { Write-Log $_.Exception.Message }
finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
