!ifndef __PARTICLE_DRIVERS_NSH__
!define __PARTICLE_DRIVERS_NSH__

!verbose 3

; Gen 1
!define _PARTICLE_CORE_CDC "1D50607D"
!define _PARTICLE_CORE_DFU "1D50607F"

; Gen 2 with a dedicated VID 0x2b04
!define _PARTICLE_VID "2B04"
!define _PARTICLE_PHOTON_CDC "${_PARTICLE_VID}C006"
!define _PARTICLE_PHOTON_DFU "${_PARTICLE_VID}D006"
!define _PARTICLE_P1_CDC "${_PARTICLE_VID}C008"
!define _PARTICLE_P1_DFU "${_PARTICLE_VID}D008"
!define _PARTICLE_ELECTRON_CDC "${_PARTICLE_VID}C00A"
!define _PARTICLE_ELECTRON_DFU "${_PARTICLE_VID}D00A"
; Gen 3 with a dedicated VID 0x2b04
!define _PARTICLE_ARGON_CDC "${_PARTICLE_VID}C00C"
!define _PARTICLE_ARGON_DFU "${_PARTICLE_VID}D00C"
!define _PARTICLE_BORON_CDC "${_PARTICLE_VID}C00D"
!define _PARTICLE_BORON_DFU "${_PARTICLE_VID}D00D"
!define _PARTICLE_XENON_CDC "${_PARTICLE_VID}C00E"
!define _PARTICLE_XENON_DFU "${_PARTICLE_VID}D00E"
; Gen 3 SoMs
!define _PARTICLE_ARGON_SOM_CDC "${_PARTICLE_VID}C016"
!define _PARTICLE_ARGON_SOM_DFU "${_PARTICLE_VID}D016"
!define _PARTICLE_BORON_SOM_CDC "${_PARTICLE_VID}C017"
!define _PARTICLE_BORON_SOM_DFU "${_PARTICLE_VID}D017"
!define _PARTICLE_XENON_SOM_CDC "${_PARTICLE_VID}C018"
!define _PARTICLE_XENON_SOM_DFU "${_PARTICLE_VID}D018"

!define _VID_PID_LENGTH 8

Function IsParticleDevice
  Exch $0 ; PID + VID e.g. 2B04C006
  Push $R0
  Push $1
  Push $2
  ${StrLoc} $1 $0 "${_PARTICLE_VID}" ">"
  ${If} $1 == 0
    ; Matches Particle VID = 0x2b04
    StrCpy $2 $0 ${_VID_PID_LENGTH}
    ${Switch} $2
      ${Case} "${_PARTICLE_PHOTON_CDC}"
      ${Case} "${_PARTICLE_PHOTON_DFU}"
      ${Case} "${_PARTICLE_P1_CDC}"
      ${Case} "${_PARTICLE_P1_DFU}"
      ${Case} "${_PARTICLE_ELECTRON_CDC}"
      ${Case} "${_PARTICLE_ELECTRON_DFU}"
      ${Case} "${_PARTICLE_ARGON_CDC}"
      ${Case} "${_PARTICLE_ARGON_DFU}"
      ${Case} "${_PARTICLE_BORON_CDC}"
      ${Case} "${_PARTICLE_BORON_DFU}"
      ${Case} "${_PARTICLE_XENON_CDC}"
      ${Case} "${_PARTICLE_XENON_DFU}"
      ${Case} "${_PARTICLE_ARGON_SOM_CDC}"
      ${Case} "${_PARTICLE_ARGON_SOM_DFU}"
      ${Case} "${_PARTICLE_BORON_SOM_CDC}"
      ${Case} "${_PARTICLE_BORON_SOM_DFU}"
      ${Case} "${_PARTICLE_XENON_SOM_CDC}"
      ${Case} "${_PARTICLE_XENON_SOM_DFU}"
        ; Ok, known Particle device
        StrCpy $R0 1
        ${Break}
      ${Default}
        ; Unknown Particle device
        StrCpy $R0 0
        ${Break}
    ${EndSwitch}
  ${Else}
    ; Doesn't match Particle VID = 0x2b04. Is this perhaps Core?
    StrCpy $2 $0 ${_VID_PID_LENGTH}
    ${Switch} $2
      ${Case} "${_PARTICLE_CORE_CDC}"
      ${Case} "${_PARTICLE_CORE_DFU}"
        ; Ok, this is Core
        StrCpy $R0 1
        ${Break}
      ${Default}
        StrCpy $R0 0
        ${Break}
    ${EndSwitch}
  ${EndIf}

  Pop $2
  Pop $1
  Exch
  Pop $0
  Exch $R0
FunctionEnd

!macro IsParticleDevice Result Vid Pid
  Push "${Vid}${Pid}"
  Call IsParticleDevice
  Pop "${Result}"
!macroend

!define IsParticleDevice "!insertmacro IsParticleDevice"

!macro UsbDevicePathToVidPid Vid Pid Input
  ${StrLoc} "${Vid}" "${Input}" "VID_" ">"
  ${If} ${Vid} != ""
    IntOp ${Vid} ${Vid} + 4
    StrCpy ${Vid} ${Input} 4 ${Vid}
  ${Else}
    StrCpy ${Vid} ${Input} 4
  ${Endif}

  ${StrLoc} "${Pid}" "${Input}" "PID_" ">"
  ${If} ${Pid} != ""
    IntOp ${Pid} ${Pid} + 4
    StrCpy ${Pid} ${Input} 4 ${Pid}
  ${Else}
    StrCpy ${Pid} ${Input} 4 4
  ${Endif}
!macroend

!define UsbDevicePathToVidPid "!insertmacro UsbDevicePathToVidPid"

!macro DeleteParticleDevices
  DetailPrint "Looking for installed Particle devices"
  ${DisableX64FSRedirection}
  ExecDos::exec /TIMEOUT=60000 '"$PLUGINSDIR\bin\$ARCH\$DEVCON" findall USB\VID_*' "" "$PLUGINSDIR\usbdevs.log"
  Pop $0
  ${LineFind} "$PLUGINSDIR\usbdevs.log" "/NUL" "1:-1" "DeleteDevice"
  ${EnableX64FSRedirection}
!macroend

Function CleanUsbCache
  DetailPrint "Cleaning USB driver cache"
  StrCpy $0 0
  ${Do}
    EnumRegKey $1 HKLM "SYSTEM\CurrentControlSet\Enum\USB" $0
    ${If} $1 == ""
      ${ExitDo}
    ${EndIf}
    IntOp $0 $0 + 1
    ${UsbDevicePathToVidPid} $3 $4 $1
    ${IsParticleDevice} $2 $3 $4
    ${If} $2 == 1
      StrCpy $2 "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB\$1"
      DetailPrint "Removing from registry $2"
      ${DisableX64FSRedirection}
      ExecDos::exec /DETAILED /TIMEOUT=60000 '"$PLUGINSDIR\bin\x86\paexec.exe" -i -s reg delete "$2" /f' ""
      Pop $3
      ${EnableX64FSRedirection}
    ${EndIf}
  ${Loop}

  DetailPrint "Cleaning USB WCID cache"
  StrCpy $0 0
  ${Do}
    EnumRegKey $1 HKLM "SYSTEM\CurrentControlSet\Control\usbflags" $0
    ${If} $1 == ""
      ${ExitDo}
    ${EndIf}
    IntOp $0 $0 + 1
    ${UsbDevicePathToVidPid} $3 $4 $1
    ${IsParticleDevice} $2 $3 $4
    ${If} $2 == 1
      StrCpy $2 "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\usbflags\$1"
      DetailPrint "Removing from registry $2"
      ${DisableX64FSRedirection}
      ExecDos::exec /DETAILED /TIMEOUT=60000 '"$PLUGINSDIR\bin\x86\paexec.exe" -i -s reg delete "$2" /f' ""
      Pop $3
      ${EnableX64FSRedirection}
    ${EndIf}
  ${Loop}
FunctionEnd

!macro DeleteParticleDrivers
  DetailPrint "Looking for installed Particle drivers"
  ${DisableX64FSRedirection}
  ExecDos::exec /TIMEOUT=60000 '"$PLUGINSDIR\bin\$ARCH\$DEVCON" dp_enum' "" "$PLUGINSDIR\oem.log"
  Pop $0
  ${LineFind} "$PLUGINSDIR\oem.log" "/NUL" "1:-1" "DeleteOemInf"
  ${EnableX64FSRedirection}
!macroend

!macro RescanDevices
  DetailPrint "Rescan connected devices"
  ${DisableX64FSRedirection}
  ExecDos::exec /DETAILED /TIMEOUT=60000 '"$PLUGINSDIR\bin\$ARCH\$DEVCON" rescan' ""
  Pop $0
  ${EnableX64FSRedirection}
!macroend

!macro InstallDrivers
  DetailPrint "Installing Serial (CDC) Drivers"
  ${If} ${IsWin10}
    StrCpy $0 "win10"
  ${Else}
    StrCpy $0 "win7_81"
  ${EndIf}
  ${DisableX64FSRedirection}
  ExecDos::exec /DETAILED /TIMEOUT=60000 '"$PLUGINSDIR\bin\$ARCH\$DEVCON" dp_add "$PLUGINSDIR\drivers\serial\$0\particle_serial.inf"' ""
  Pop $0
  ${EnableX64FSRedirection}

  DetailPrint "Installing DFU Drivers"
  ${DisableX64FSRedirection}
  ExecDos::exec /DETAILED /TIMEOUT=60000 '"$PLUGINSDIR\bin\$ARCH\$DEVCON" dp_add "$PLUGINSDIR\drivers\dfu\particle_dfu.inf"' ""
  Pop $0
  ${EnableX64FSRedirection}
!macroend

Function DeleteDevice
  ${StrLoc} $1 $R9 "USB\VID_" ">"
  ${If} $1 != ""
    ${StrTok} $2 $R9 ":" "0" "1"
    ${Trim} $1 $2
    ${UsbDevicePathToVidPid} $3 $4 $1
    ${IsParticleDevice} $5 $3 $4
    ${If} $5 == 1
      DetailPrint "Removing $1"
      ExecDos::exec /DETAILED /TIMEOUT=60000 '"$PLUGINSDIR\bin\$ARCH\$DEVCON" removeall "@$1"' ""
      Pop $3
    ${EndIf}
  ${EndIf}
  StrCpy $0 ""
  Push $0
FunctionEnd

Function MatchParticleVidPidInOemInf
  ; Just in case uppercase input string
  ${StrCase} $R9 $R9 "U"
  ${StrLoc} $1 $R9 "VID_" ">"
  ${If} $1 != ""
    ${UsbDevicePathToVidPid} $3 $4 $R9
    ${IsParticleDevice} $R2 $3 $4
  ${EndIf}
  ${If} $R2 == 1
    DetailPrint "Found matching VID/PID: $3:$4"
    StrCpy $0 "StopLineFind"
  ${Else}
    StrCpy $0 ""
  ${EndIf}
  Push $0
FunctionEnd

Function LookIntoOemInf
  DetailPrint "Looking into $R1"
  ${DisableX64FSRedirection}
  ; This is needed to be able to read UTF-16 files :|
  ; Only looking at lines with 'VID_'
  ExecDos::exec 'cmd.exe /C "type $WINDIR\inf\$R1 | findstr VID_"' "" "$PLUGINSDIR\$R1"
  Pop $0
  ${LineFind} "$PLUGINSDIR\$R1" "/NUL" "1:-1" "MatchParticleVidPidInOemInf"
  ${EnableX64FSRedirection}
FunctionEnd

Function DeleteOemInf
  ${StrStr} $1 $R9 "oem"
  ${If} $1 == $R9
    ; oemXXX.inf
    ; save in $R1
    ${Trim} $2 $1
    StrCpy $R1 $2
    StrCpy $R2 0
    Call LookIntoOemInf
    ${If} $R2 == 1
      DetailPrint "Deleting $R1"
      ExecDos::exec /DETAILED /TIMEOUT=60000 '"$PLUGINSDIR\bin\$ARCH\$DEVCON" -f dp_delete "$R1"' ""
      Pop $3
    ${EndIf}
  ${EndIf}
  StrCpy $0 ""
  Push $0
FunctionEnd

!endif # !__PARTICLE_DRIVERS_NSH__
