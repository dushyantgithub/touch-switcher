# Touch Switcher

Touch Switcher is a hardware button that toggles a monitor between two inputs. A
TTP223 capacitive touch sensor and Seeed Studio XIAO nRF52840 Sense send touch
events over USB serial to a small Windows PowerShell helper, which changes the
monitor input through NirSoft ControlMyMonitor.

The included defaults target a Lenovo G27q-20 connected to a Windows PC over
DisplayPort and another computer over HDMI.

## How it works

```text
TTP223 touch sensor
        |
        v
XIAO nRF52840 Sense -- USB serial --> Windows helper
                                            |
                                            v
                                  ControlMyMonitor / DDC-CI
                                            |
                                            v
                                  DisplayPort <--> HDMI
```

The firmware emits a heartbeat every second and one event for each debounced
touch. The Windows helper discovers Seeed USB serial devices, verifies the
heartbeat, reads the monitor's current input, and switches to the other known
input. It does not use a cloud service or network connection.

## Requirements

### Hardware

- Seeed Studio XIAO nRF52840 Sense
- TTP223 capacitive touch sensor in its default active-high momentary mode
- USB data cable
- A DDC/CI-capable monitor connected to the Windows PC

### Software

- Windows PowerShell 5.1
- [ControlMyMonitor](https://www.nirsoft.net/utils/control_my_monitor.html) by
  NirSoft (downloaded separately; it is not distributed in this repository)
- Arduino IDE or Arduino CLI only if you need to flash or modify the firmware

## Wiring

| TTP223 | XIAO nRF52840 Sense |
| --- | --- |
| VCC | 3V3 |
| GND | GND |
| OUT | D0 |

Leave the TTP223 A and B solder jumpers open for active-high momentary operation.

## Quick start

1. Flash `firmware/TouchSwitcher/TouchSwitcher.ino` to the XIAO nRF52840 Sense.
2. Download ControlMyMonitor and copy `ControlMyMonitor.exe` into the `windows`
   folder.
3. Connect the XIAO to the Windows PC with a USB data cable.
4. Double-click `windows/Install.cmd`. Administrator access is not required.
5. Touch and release the sensor. Wait about three seconds before touching it
   again.

The installer copies the helper to `%LOCALAPPDATA%\TouchSwitcher`, starts it,
and adds a per-user Startup shortcut so it runs at sign-in. Logs are written to:

```text
%LOCALAPPDATA%\TouchSwitcher\touch-switcher.log
```

To uninstall, run `windows/Uninstall.cmd`, then sign out to stop the existing
helper. Installed files are deliberately left in Local AppData for inspection
or manual removal.

## Firmware setup

Add Seeed Studio's board-manager URL to Arduino:

```text
https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
```

This project was built with:

- Board package: `Seeeduino:nrf52@1.1.13`
- Board: `Seeeduino:nrf52:xiaonRF52840Sense`
- Serial speed: 115200 baud

Double-press RESET to put the XIAO into its UF2 bootloader before uploading if
normal upload does not work.

## Configuration

The defaults in `windows/TouchSwitcher.ps1` are specific to the original setup:

| Setting | Default | Meaning |
| --- | --- | --- |
| Monitor name | `G27q-20` | ControlMyMonitor target |
| VCP code | `60` | Monitor input source |
| Input 1 | `15` | DisplayPort |
| Input 2 | `17` | HDMI |
| USB VID | `2886` | Seeed runtime USB vendor ID |

To use another monitor or input pair, first identify the monitor name and VCP
values with ControlMyMonitor, then update all three ControlMyMonitor argument
strings in `windows/TouchSwitcher.ps1`. Common input values are not guaranteed
to be the same on every monitor.

## Run in the foreground

Foreground mode is useful for first-time setup and troubleshooting. From the
repository root in Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\TouchSwitcher.ps1
```

In a second window, follow the log:

```powershell
Get-Content .\windows\touch-switcher.log -Wait
```

Only one process can open the XIAO serial port at a time. Close Arduino Serial
Monitor and any other serial terminal before running the helper.

## Troubleshooting

- **ControlMyMonitor.exe is missing:** place it beside `Install.cmd` and install
  again.
- **The XIAO is not found:** use a USB data cable, confirm the firmware is
  running, and close any program using its COM port.
- **Touches appear but the monitor does not switch:** enable DDC/CI in the
  monitor menu and verify the monitor name and VCP input values.
- **Changes to the repository have no effect:** the installer runs a copied
  version. Stop the current helper and reinstall, or run the repository version
  in the foreground.
- **PowerShell is blocked:** the launcher uses process-scoped ExecutionPolicy
  Bypass and does not alter the saved policy, but organization-managed policies
  may still prevent scripts from running.

See [WINDOWS-HANDOFF.md](WINDOWS-HANDOFF.md) for detailed validation commands,
protocol information, and the full test checklist.

## Current status and limitations

- Firmware compilation, flashing, USB heartbeat, and physical touch events were
  verified on the original hardware.
- The complete Windows touch-to-monitor flow still needs validation on the
  target PC.
- The helper is a hidden PowerShell process, not a Windows service or tray app.
- Windows must remain awake while the other input is in use.
- The current script is configured for one monitor model and two input values.

## Security and privacy

The helper probes only USB serial devices with Seeed VID `2886` and accepts a
device only after receiving the expected firmware heartbeat. It makes no network
requests. ControlMyMonitor is a separate third-party download and is subject to
its own license and terms.

## Contributing

Bug reports and pull requests are welcome. Please include the Windows version,
monitor model, connection types, relevant log lines, and exact reproduction
steps. Never attach private files or credentials to an issue.

## License

Touch Switcher is open-source software released under the [MIT License](LICENSE).

