@echo off
powershell.exe -NoProfile -Command "$p=Join-Path ([Environment]::GetFolderPath('Startup')) 'Touch Switcher.lnk'; Remove-Item -LiteralPath $p -ErrorAction SilentlyContinue"
echo Startup disabled. Sign out to stop the running helper.
echo Files remain in %%LOCALAPPDATA%%\TouchSwitcher for inspection or removal.
pause
