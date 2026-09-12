# Touch Switcher — Windows development handoff

## Goal and next action

Build a simple background Windows app that starts at sign-in and watches a USB-connected Seeed XIAO nRF52840 Sense with a TTP223 touch sensor. Each touch toggles the Lenovo G27q-20 between the Windows PC (DisplayPort) and MacBook (HDMI).

**Next action: test the existing Windows helper on the actual PC.** The board is already programmed and the sensor works. No Mac helper, Bluetooth, network service, or dock replacement is needed. Keep the Windows PC awake while using the Mac.

## Hardware and verified facts

| Item | Details |
|---|---|
| Monitor | Lenovo G27q-20 |
| PC | Windows, NVIDIA GeForce RTX 3060 Ti, DisplayPort |
| Mac | M1 MacBook, HAMMER USB-C-to-HDMI dock (model unknown) |
| Sensor power | TTP223 VCC → XIAO 3V3; GND → GND |
| Sensor signal | TTP223 OUT → XIAO D0 |
| Sensor mode | Active-high momentary; release between touches |
| XIAO | Bootloader identified nRF52840-SeeedXiaoSense-v1; built as Sense |
| Firmware | Flashed successfully; USB heartbeat verified; three physical taps produced exactly three touch messages |
| Windows end-to-end app | **Not yet tested** |

The board previously ran Zephyr firmware named “Omi INMP441 Debug” with VID 2FE3. The user explicitly authorized replacing it. Current Arduino firmware reports “XIAO nRF52840 Sense”, VID 2886. Do not search for the old Zephyr USB identity.

## Important finding: Windows can switch both ways

Earlier commands using `Primary` or `\\.\DISPLAY1\Monitor0` switched to Mac but did not return. This led to an incorrect provisional suspicion that inactive DisplayPort could not carry DDC commands.

A later test **worked both ways** using monitor name `G27q-20` and `Start-Process -Wait -PassThru`. It recorded:

```text
Before switching | VCP 10 | Result: 50
Before switching | VCP 60 | Result: 15
While HDMI is selected | VCP 10 | Result: 50
While HDMI is selected | VCP 60 | Result: 17
```

VCP `60` selects input: decimal `15` is DisplayPort; decimal `17` is HDMI. VCP `10` is brightness. ControlMyMonitor `/GetValue` returns its value as the **process exit code**, not standard output. Nonzero exit codes therefore are not automatically errors. The exact cause of the earlier failed tests is unproven; preserve the working name and wait behavior.

BetterDisplay on the Mac failed to switch inputs through the dock. That is irrelevant to this Windows-only design; do not spend time on it unless new evidence requires it.

## Files

- `firmware/TouchSwitcher/TouchSwitcher.ino`: firmware source.
- `build/TouchSwitcher.uf2`: compiled and flashed Sense firmware; included in development bundle.
- `windows/TouchSwitcher.ps1`: background helper.
- `windows/Install.ps1` and `Install.cmd`: per-user installation and immediate launch.
- `windows/Uninstall.cmd`: removes startup shortcut; sign out to stop existing process.
- `windows/README.txt`: user setup instructions.
- `README.md`: build notes.

ControlMyMonitor.exe is **not included**. Copy the user's existing working executable into `windows/`. Official source: https://www.nirsoft.net/utils/control_my_monitor.html

## First Windows test (foreground development)

1. Extract the development bundle to a normal local folder and open that folder in your Windows coding environment.
2. Copy ControlMyMonitor.exe into `windows/`.
3. Plug the programmed XIAO into the Windows PC with a USB data cable.
4. If the installed background helper is already running, stop it first using the section below. It holds the serial port and a single-instance mutex.
5. In Windows PowerShell, from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\TouchSwitcher.ps1
```

6. In a second PowerShell window, from the same root:

```powershell
Get-Content .\windows\touch-switcher.log -Wait
```

7. Tap once: the monitor should show Mac. Wait at least 3 seconds, then tap again: it should show Windows. Review the log after returning. Holding the sensor should trigger only once.

Run in the foreground until it works; then use `windows\Install.cmd` for startup. ExecutionPolicy Bypass is scoped to the launched process; no saved policy is changed. Corporate policy may still block scripts.

## Installed app and development restarts

Installation copies files to `%LOCALAPPDATA%\TouchSwitcher` and adds `Touch Switcher.lnk` to the user's Startup folder. It runs at **sign-in**, not before login. It is a hidden PowerShell process, not a compiled EXE or Windows service.

Installed log:

```powershell
Get-Content "$env:LOCALAPPDATA\TouchSwitcher\touch-switcher.log" -Tail 50 -Wait
```

Editing repository files does not update the installed copy. Also, rerunning Install.cmd does not stop the old helper; the mutex prevents the new process from taking over. Stop the existing helper before reinstalling:

```powershell
# Inspect only candidate TouchSwitcher PowerShell processes first.
$helpers = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'powershell.exe' -and
    $_.CommandLine -match '-File\s+"?[^"\r\n]*TouchSwitcher\.ps1(?:"|\s|$)'
}
$helpers | Select-Object ProcessId, CommandLine
# Stop only these helper processes, not every PowerShell process.
$helpers | ForEach-Object { Stop-Process -Id $_.ProcessId }
```

Then run the foreground command above, or reinstall with Install.cmd. Closing the foreground helper should release its serial port; if needed, unplug/replug the XIAO.

## Serial protocol and discovery

115200 baud, 8 data bits, no parity, 1 stop bit, DTR enabled. CRLF-terminated text:

```text
TOUCH_SWITCHER_READY_V1
TOUCH_SWITCHER_TOUCH_V1
```

The READY heartbeat is sent roughly every second. TOUCH is sent once per debounced rising edge. Firmware uses 50 ms debounce and 1500 ms minimum spacing; it requires release after boot. Default TTP223 mode must be active-high momentary.

Windows discovers `Win32_PnPEntity` entries with `VID_2886` and a `(COMn)` name, then verifies the heartbeat. It retries discovery every 2 seconds, handshakes for up to 5 seconds, and reconnects after lost communication. It discards touches queued while a monitor switch is being processed.

Inspect discovery:

```powershell
Get-CimInstance Win32_PnPEntity | Where-Object {
    $_.PNPDeviceID -match 'VID_2886'
} | Select-Object Name, PNPDeviceID, Status
[IO.Ports.SerialPort]::GetPortNames()
```

Raw sensor test, **with helper stopped** (replace COM7 with discovered port):

```powershell
$serial = New-Object IO.Ports.SerialPort('COM7',115200,'None',8,'One')
$serial.DtrEnable = $true
$serial.ReadTimeout = 1500
try {
    $serial.Open()
    while ($true) {
        try { $serial.ReadLine() }
        catch [TimeoutException] { Write-Host 'Waiting for heartbeat...' }
    }
} finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
```

Close this reader before starting the helper. Only one process may own the serial port.

## Independent monitor test

From `windows/`, with the PC initially visible:

```powershell
$exe = (Resolve-Path .\ControlMyMonitor.exe).Path
$p = Start-Process $exe -ArgumentList '/GetValue G27q-20 60' -Wait -PassThru
$p.ExitCode # Expected: 15 on PC or 17 on Mac
Start-Process $exe -ArgumentList '/SetValue G27q-20 60 17' -Wait
Start-Sleep -Seconds 15
$p = Start-Process $exe -ArgumentList '/GetValue G27q-20 60' -Wait -PassThru
$inputWhileOnMac = $p.ExitCode
Start-Process $exe -ArgumentList '/SetValue G27q-20 60 15' -Wait
"Input while Mac was selected: $inputWhileOnMac"
```

If it does not return, switch back with the monitor buttons. Keep the helper stopped during this independent test to avoid concurrent commands.

## Troubleshooting order

1. **No log:** confirm executable placement and helper launch. Run foreground. Inspect syntax/runtime errors; Windows execution has not yet been validated.
2. **Waiting for XIAO forever:** inspect VID and COM discovery. Check data cable, driver, and that firmware is running rather than bootloader. Use raw serial test.
3. **Port access denied:** close Arduino Serial Monitor, raw reader, and duplicate helpers.
4. **Heartbeat works, no TOUCH:** inspect sensor power and D0 wiring; check default A/B jumper mode. Physical touch worked on Mac, so distinguish wiring changes from app issues.
5. **TOUCH works, no input change:** run the independent DDC test. Preserve `G27q-20` and waiting for process completion. Do not infer DDC failure from a nonzero GetValue exit code.
6. **Cannot read input:** helper intentionally refuses to guess when the value is neither 15 nor 17. Log the raw return value and inspect ControlMyMonitor.
7. **Readback differs from target:** check actual monitor screen; adjust settling time only if evidence shows the 2-second wait is insufficient. Do not blindly repeat toggles.
8. **Edits have no effect:** stop old helper and refresh installed copy, or run source foreground.

Current implementation limitations worth testing: startup when board is absent; unplug during a DDC command; reconnect after sleep; command timeout handling; log rotation; unhandled discovery failures at the outer loop; duplicate startup processes and abandoned mutex recovery. There is no tray UI or user-visible error notification yet. These are review targets, not confirmed bugs.

## Validation checklist on Windows

- [ ] Helper parses and starts without errors.
- [ ] XIAO found automatically without hardcoded COM number.
- [ ] Ten alternating taps produce ten correct switches.
- [ ] Long touch produces one switch; fast taps do not cause queued switching.
- [ ] Unplug/replug reconnects automatically.
- [ ] Manual monitor input change is respected on the next touch.
- [ ] Startup works after sign-out/sign-in, including with board initially absent.
- [ ] Missing monitor/executable and failed reads produce useful diagnostics.

## Firmware development (only if needed)

The board is already flashed; don't reflash merely to test Windows code. Arduino board-manager URL:
https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json

Core used: `Seeeduino:nrf52@1.1.13`; FQBN: `Seeeduino:nrf52:xiaonRF52840Sense`.
Build size: 46,420 bytes flash, 7,464 bytes RAM. Bootloader: UF2 0.9.0, S140 7.3.0.
Double-press RESET to expose the `XIAO-SENSE` drive; copying the provided UF2 flashes it, then the drive disappears as the board reboots. No bootloader or SoftDevice replacement is needed.

## Prompt for continuing development

> Read WINDOWS-HANDOFF.md and inspect the source. This is the Windows PC connected to the Lenovo G27q-20 over DisplayPort. The XIAO already has working touch firmware. Help me test and debug the Windows helper locally, then verify startup and switching in both directions. Preserve the proven ControlMyMonitor target G27q-20 and wait-for-exit behavior. Start by checking the helper process, serial discovery and logs; do not reflash firmware unless evidence calls for it. Clearly separate verified results from assumptions.
