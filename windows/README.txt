TOUCH SWITCHER - Lenovo G27q-20

1. Extract this folder on your Windows PC.
2. Copy your existing ControlMyMonitor.exe into this folder.
3. Connect the programmed XIAO by a USB data cable to Windows.
4. Double-click Install.cmd. Administrator access is not needed.
5. Touch and release the sensor to toggle HDMI (17) and DisplayPort (15).

Runs invisibly at Windows sign-in. Windows must remain awake.
Allow about 3 seconds between touches. Holding the pad triggers once.
The TTP223 must use its default active-high momentary mode (A/B pads open).
No Mac app or network connection is required.

Logs: %LOCALAPPDATA%\TouchSwitcher\touch-switcher.log
Automatic reconnect: unplug/replug the XIAO if needed.
Only Seeed USB serial devices (VID 2886) with the firmware handshake are used.
If another app has the serial port open, close it (e.g. Arduino Serial Monitor).
Uninstall.cmd removes startup; sign out to stop the running helper.

The launcher uses process-scoped ExecutionPolicy Bypass for these local scripts;
it does not change Windows' saved execution policy. Managed PCs may block scripts.

Validation: firmware compiled and flashed to XIAO nRF52840 Sense; USB heartbeat verified.
Three physical taps produced exactly three USB touch events. Windows runtime
and the complete physical touch-to-monitor flow still need testing on your PC.
