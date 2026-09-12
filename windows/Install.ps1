$ErrorActionPreference = 'Stop'
$destination = Join-Path $env:LOCALAPPDATA 'TouchSwitcher'
if (-not (Test-Path "$PSScriptRoot\ControlMyMonitor.exe")) {
    throw 'Put your existing ControlMyMonitor.exe beside Install.cmd, then run Install.cmd again.'
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item "$PSScriptRoot\TouchSwitcher.ps1" $destination -Force
Copy-Item "$PSScriptRoot\ControlMyMonitor.exe" $destination -Force
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'Touch Switcher.lnk'
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($shortcutPath)
$link.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$link.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$destination\TouchSwitcher.ps1`""
$link.WorkingDirectory = $destination
$link.Save()
Start-Process $link.TargetPath -ArgumentList $link.Arguments -WindowStyle Hidden
Write-Host "Installed and started. It will start at Windows sign-in."
Write-Host "Log: $destination\touch-switcher.log"
