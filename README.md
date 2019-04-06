# Windows Driver installer for Particle devices

Installs Serial (CDC) and DFU drivers for Particle devices.

## Supported Windows versions

The drivers are compatible with the following x86 and amd64 versions of Microsoft Windows:

Desktop:
- Windows 10
- Windows 8.1
- Windows 8
- Windows 7

Server:
- Windows Server 2019
- Windows Server 2016
- Windows Server 2012 R2
- Windows Server 2012
- Windows Server 2008 R2
- Windows Server 2008

## Components

The installer and the drivers in this repository use the following third-party components:

1. [devcon](https://github.com/Microsoft/Windows-driver-samples): a command-line tool that displays detailed information about devices, and lets you search for and manipulate devices from the command line.
2. [PaExec](https://github.com/poweradminllc/PAExec): a free, redistributable and open source equivalent to Microsoft's popular PsExec application.
3. [lowcdc](http://www.recursion.jp/prose/avrcdc/driver.html): CDC class driver implementation for low-speed USB
4. trustcertregister: a part of [libwdi](https://github.com/pbatard/libwdi) Windows Driver Installer library for USB devices

See [license.txt](/installer/resources/license.txt) for full information about licenses of these components.

## License

Copyright 2019 © Particle Industries, Inc. Licensed under the Apache 2 license.
