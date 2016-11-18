[![Build status](https://ci.appveyor.com/api/projects/status/wqljs3lq4caneru3/branch/master?svg=true)](https://ci.appveyor.com/project/m-mcgowan/windows-device-drivers/branch/master)

# Windows Drivers for Particle devices

**NOTE: These drivers only support Particle Photon/P1/Electron firmware version >= 0.6.0 and Spark Core (no firmware version restriction)**

## Windows Installer
The installer is built using Nullsoft NSIS. The installer supports Microsoft Windows versions starting with Windows XP, both x86 and amd64 variants. The driver inf files are installed using `devcon` utility from Microsoft DDK.

A basic outline of the installation steps:

1. Installer requests administrative privileges
2. Installer checks whether it's being run on x86 or amd64 operating system
3. Installer checks current Windows version
  1. If the installer is being run on Windows 10, a message dialog is shown: _"Particle devices don't require driver installation on Windows 10. If you installed Particle device drivers previously this installer can cleanly remove them."_ "Particle Drivers" section is permanently unchecked and disabled. Only "Uninstall current drivers" is available
  2. If the installer is being run on Windows 10 but in silent mode a dialog is not show but instead "Uninstall current drivers" section is auto-selected.
  3. If the installer is being run on a machine with OS older than Windows XP, a message dialog is shown: _"The installer requires Windows XP or newer"_. The installer exits after the user clicks "OK" button.
4. Installation directory `%TEMP%\particle-drivers-${version}` is deleted
5. If the installer is being run in silent mode (i.e. `particle-drivers-${version}.exe /S`), a registry key `HKEY_LOCAL_MACHINE\Software\Particle\Drivers\Version` is checked
  1. If such key exists and has a `String` value of current driver installer version (e.g. `6.1.0.45`) (meaning that the drivers are already installed), or equals to `"99999999"` the installer silently exits.
6. The installer presents the user with a "Components" selection
  1. "Uninstall current drivers" (selected by default)
    1. This section correctly cleans up any previous installations of drivers for Particle devices (USB VID=0x2B04 PID=0xCxxx)
    2. Installer extracts necessary utilities into `%TEMP%\particle-drivers-${version}`
    3. Installer runs `devcon` utility and removes any `USB\VID_2B04&PID_C0*` devices
    4. Installer runs `devcon` utility and removes any installed drivers (OEM inf files) with `Provider: Particle` or `Provider: Sparklabs`
    5. Installer cleans USB driver cache by removing the following registry keys under SYSTEM account (with the help of `psexec` utility): `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB\VID_2B04&PID_C0*`, `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\usbflags\2B04C0*`
    6. Installer deletes `HKEY_LOCAL_MACHINE\Software\Particle\Drivers\Version` registry entry
    7. If the installer is being run on Windows 10, `"99999999"` string is written into `HKEY_LOCAL_MACHINE\Software\Particle\Drivers\Version` registry key
    8. If the installer is being run on Windows 10, `99999999` DWORD value is written into `HKEY_LOCAL_MACHINE\Software\Particle\Drivers\serial` registry key
  2. "Partice Drivers" (selected by default)
    1. This section installs drivers for Particle devices: Spark Core, Photon, P1 and Electron
    2. Installer extracts necessary utilities and files into `%TEMP%\particle-drivers-${version}`
    3. Installer adds Particle code signing certificate into trusted certificates
    4. Installer installs `particle.inf` using `devcon` utility
    5. Installer uses `devcon` utility to rescan currently attached devices
    6. Installer writes current version string (e.g. `6.1.0.45`) into `HKEY_LOCAL_MACHINE\Software\Particle\Drivers\Version` registry key
    7. Installer writes `99999999` DWORD value into `HKEY_LOCAL_MACHINE\Software\Particle\Drivers\serial` registry key
7. Installer cleans its installation directory (`%TEMP%\particle-drivers-${version}`)
8. If the installer is not running in silent mode, a message dialog is displayed: _"Do you wish to reboot the system?"_
9. Installer exits and optionally reboots the computer
