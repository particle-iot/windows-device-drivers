!include "MUI2.nsh"
!include "WinVer.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"
!include "TextFunc.nsh"
!include "StrFunc.nsh"

;--------------------------------
;General

  ;Request application privileges for Windows Vista
  RequestExecutionLevel highest

  !define MUI_ICON "resources\particle.ico"

  !define PRODUCT_NAME "Particle Device Drivers"
  !ifndef PRODUCT_VERSION
    !define PRODUCT_VERSION "6.1.0.0"
  !endif
  !define PRODUCT_PUBLISHER "Particle"
  !define PRODUCT_WEBSITE "http://particle.io"

  ;Name and file
  Name "${PRODUCT_NAME} ${PRODUCT_VERSION} Installer"
  OutFile "particle_drivers_${PRODUCT_VERSION}.exe"

  ;Default installation folder
  InstallDir "$TEMP\particle_drivers_${PRODUCT_VERSION}"

  !ifndef DRIVERSDIR
    !define DRIVERSDIR "drivers"
  !endif

;--------------------------------
;Interface Configuration

  !define MUI_HEADERIMAGE
  !define MUI_HEADERIMAGE_BITMAP "resources\header.bmp"
  !define MUI_ABORTWARNING

;--------------------------------
;Pages

  ;!insertmacro MUI_PAGE_LICENSE "${NSISDIR}\Docs\Modern UI\License.txt"
  !insertmacro MUI_PAGE_COMPONENTS
  ;!insertmacro MUI_PAGE_DIRECTORY
  !insertmacro MUI_PAGE_INSTFILES
  
  ;!insertmacro MUI_UNPAGE_CONFIRM
  ;!insertmacro MUI_UNPAGE_INSTFILES
  
;--------------------------------
;Languages
 
  !insertmacro MUI_LANGUAGE "English"


  VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName" "${PRODUCT_NAME}"
  VIAddVersionKey /LANG=${LANG_ENGLISH} "Comments" ""
  VIAddVersionKey /LANG=${LANG_ENGLISH} "CompanyName" "${PRODUCT_PUBLISHER}"
  VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalTrademarks" ""
  VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalCopyright" ""
  VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "${PRODUCT_NAME} Installer"
  VIAddVersionKey /LANG=${LANG_ENGLISH} "FileVersion" "${PRODUCT_VERSION}"
  VIProductVersion "${PRODUCT_VERSION}"

;--------------------------------
;Installer Sections

Var /GLOBAL ARCH
Var /GLOBAL DEVCON

${StrStr}
${StrTok}

; Trim
;   Removes leading & trailing whitespace from a string
; Usage:
;   Push 
;   Call Trim
;   Pop 
Function Trim
  Exch $R1 ; Original string
  Push $R2
 
Loop:
  StrCpy $R2 "$R1" 1
  StrCmp "$R2" " " TrimLeft
  StrCmp "$R2" "$\r" TrimLeft
  StrCmp "$R2" "$\n" TrimLeft
  StrCmp "$R2" "$\t" TrimLeft
  GoTo Loop2
TrimLeft: 
  StrCpy $R1 "$R1" "" 1
  Goto Loop
 
Loop2:
  StrCpy $R2 "$R1" 1 -1
  StrCmp "$R2" " " TrimRight
  StrCmp "$R2" "$\r" TrimRight
  StrCmp "$R2" "$\n" TrimRight
  StrCmp "$R2" "$\t" TrimRight
  GoTo Done
TrimRight:  
  StrCpy $R1 "$R1" -1
  Goto Loop2
 
Done:
  Pop $R2
  Exch $R1
FunctionEnd

; Usage:
; ${Trim} $trimmedString $originalString
 
!define Trim "!insertmacro Trim"
 
!macro Trim ResultVar String
  Push "${String}"
  Call Trim
  Pop "${ResultVar}"
!macroend

!macro TrustCertRegister
  DetailPrint "Installing Particle certificate"
  ${DisableX64FSRedirection}
  ExecDos::exec /DETAILED /TIMEOUT=10000 '"$INSTDIR\bin\x86\trustcertregister.exe"' ""
  Pop $0
  ${EnableX64FSRedirection}
!macroend

!macro DeleteParticleDevices
  DetailPrint "Looking for installed Particle devices"
  ${DisableX64FSRedirection}
  ExecDos::exec /TIMEOUT=10000 '"$INSTDIR\bin\$ARCH\$DEVCON" findall USB\VID_2B04&PID_C0*' "" "$INSTDIR\usbdevs.log"
  Pop $0
  ${LineFind} "$INSTDIR\usbdevs.log" "/NUL" "1:-1" "DeleteDevice"
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
    ${StrStr} $2 $1 "VID_2B04&PID_C0"
    ${If} $2 != ""
      StrCpy $2 "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB\$1"
      DetailPrint "Removing from registry $2"
      ${DisableX64FSRedirection}
      ExecDos::exec /TIMEOUT=10000 '"$INSTDIR\bin\x86\PsExec.exe" -accepteula -s reg delete "$2" /f' ""
      Pop $3
      ${EnableX64FSRedirection}
    ${EndIf}
  ${Loop}

  StrCpy $0 0
  ${Do}
    EnumRegKey $1 HKLM "SYSTEM\CurrentControlSet\Control\usbflags" $0
    ${If} $1 == ""
      ${ExitDo}
    ${EndIf}
    IntOp $0 $0 + 1
    ${StrStr} $2 $1 "2B04C0"
    ${If} $2 != ""
      StrCpy $2 "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\usbflags\$1"
      DetailPrint "Removing from registry $2"
      ${DisableX64FSRedirection}
      ExecDos::exec /TIMEOUT=10000 '"$INSTDIR\bin\x86\PsExec.exe" -accepteula -s reg delete "$2" /f' ""
      Pop $3
      ${EnableX64FSRedirection}
    ${EndIf}
  ${Loop}

FunctionEnd

!macro DeleteParticleDrivers
  DetailPrint "Looking for installed Particle drivers"
  ${DisableX64FSRedirection}
  ExecDos::exec /TIMEOUT=10000 '"$INSTDIR\bin\$ARCH\$DEVCON" dp_enum' "" "$INSTDIR\oem.log"
  Pop $0
  ${LineFind} "$INSTDIR\oem.log" "/NUL" "1:-1" "DeleteOemInf"
  ${EnableX64FSRedirection}
!macroend

!macro RescanDevices
  DetailPrint "Rescan connected devices"
  ${DisableX64FSRedirection}
  ExecDos::exec /DETAILED /TIMEOUT=60000 '"$INSTDIR\bin\$ARCH\$DEVCON" rescan' ""
  Pop $0
  ${EnableX64FSRedirection}
!macroend


!macro CleanInstDir
  SetOutPath "$TEMP"
  RMDir /r "$INSTDIR"
!macroend

Function DeleteDevice
  ${StrStr} $1 $R9 "USB"
  ${If} $1 == $R9
    ${StrTok} $2 $1 ":" "0" "1"
    ${Trim} $1 $2
    DetailPrint "Removing $1"
    ExecDos::exec /DETAILED /TIMEOUT=2000 '"$INSTDIR\bin\$ARCH\$DEVCON" remove "@$1"' ""
    Pop $3
  ${EndIf}
  StrCpy $0 ""
  Push $0
FunctionEnd

Function DeleteOemInf
  ${StrStr} $1 $R9 "oem"
  ${If} $1 == $R9
    ; oemXXX.inf
    ; save in $R1
    ${Trim} $2 $1
    StrCpy $R1 $2
  ${Else}
    ${Trim} $1 $R9
    ${StrStr} $2 $1 "Provider:"
    ${If} $R1 != ""
      ${If} $2 == "Provider: Particle" 
      ${OrIf} $2 == "Provider: Sparklabs"
        DetailPrint "Deleting $R1"
        ExecDos::exec /DETAILED /TIMEOUT=60000 '"$INSTDIR\bin\$ARCH\$DEVCON" -f dp_delete "$R1"' ""
        Pop $3
      ${EndIf}
    ${EndIf}
  ${EndIf}
  StrCpy $0 ""
  Push $0
FunctionEnd

Section "Uninstall current drivers" SecCleanDrivers
  UserInfo::GetAccountType
  Pop $1
  ${If} $1 != "Admin"
    SetErrorLevel 740
    Abort "This installer needs to be run with administrative privileges"
  ${EndIf}

  SetOutPath "$INSTDIR"
  File /r bin

  !insertmacro DeleteParticleDevices
  !insertmacro DeleteParticleDrivers
  Call CleanUsbCache

  DeleteRegKey HKLM "Software\Particle\Drivers"
SectionEnd

Section "Particle Drivers" SecDrivers
  UserInfo::GetAccountType
  Pop $1
  ${If} $1 != "Admin"
    SetErrorLevel 740
    Abort "This installer needs to be run with administrative privileges"
  ${EndIf}

  SetOutPath "$INSTDIR\drivers"
  File /r "${DRIVERSDIR}\*"

  SetOutPath "$INSTDIR\bin\x86"
  File "bin\x86\trustcertregister.exe"

  SetOutPath "$INSTDIR"

  !insertmacro TrustCertRegister

  DetailPrint "Installing particle.inf"
  ${DisableX64FSRedirection}
  ExecDos::exec /DETAILED /TIMEOUT=60000 '"$INSTDIR\bin\$ARCH\$DEVCON" dp_add "$INSTDIR\drivers\particle.inf"' ""
  Pop $0
  ${EnableX64FSRedirection}

  !insertmacro RescanDevices

  WriteRegStr HKLM "Software\Particle\Drivers" "Version" "${PRODUCT_VERSION}"
SectionEnd

;--------------------------------
;Descriptions

  ;Language strings
  LangString DESC_SecCleanDrivers ${LANG_ENGLISH} "Uninstalls any previously installed Particle drivers."
  LangString DESC_SecDrivers ${LANG_ENGLISH} "USB CDC (Serial) drivers for Photon, Electron, P1 and Core."

  ;Assign language strings to sections
  !insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecCleanDrivers} $(DESC_SecCleanDrivers)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecDrivers} $(DESC_SecDrivers)
  !insertmacro MUI_FUNCTION_DESCRIPTION_END
 
;--------------------------------
;Uninstaller Section

; Section "Uninstall"

;   ;ADD YOUR OWN FILES HERE...

;   ; Delete "$INSTDIR\Uninstall.exe"

;   ; RMDir "$INSTDIR"

; SectionEnd

;--------------------------------
;init
Function .onInit
  ${If} ${RunningX64}
    StrCpy $ARCH "amd64"
    SetRegView 64
  ${Else}
    StrCpy $ARCH "x86"
  ${EndIf}
  ${If} ${IsWin10}
    !insertmacro SetSectionFlag ${SecDrivers} ${SF_RO}
    !insertmacro ClearSectionFlag ${SecDrivers} ${SF_SELECTED}
    MessageBox MB_OK|MB_ICONEXCLAMATION "Particle devices don't require driver installation on Windows 10. If you installed Particle device drivers previously this installer can cleanly remove them." IDOK
  ${EndIf}

  ${If} ${AtLeastWinXP}
    ; ok
  ${Else}
    MessageBox MB_OK|MB_ICONEXCLAMATION "The installer requires Windows XP or newer" IDOK
    Abort
  ${EndIf}

  ${If} ${AtMostWinXP}
    StrCpy $DEVCON "devcon_xp.exe"
  ${Else}
    StrCpy $DEVCON "devcon.exe"
  ${EndIf}

  !insertmacro CleanInstDir

  ${If} ${Silent}
    ReadRegStr $0 HKLM "Software\Particle\Drivers" "Version"
    ${If} $0 == "${PRODUCT_VERSION}"
      ; If running silent, skip installation if already installed
      Abort
    ${EndIf}
  ${EndIf}
FunctionEnd

Function .onInstSuccess
  !insertmacro CleanInstDir
  ${If} ${Silent}
    ;
  ${Else}
    MessageBox MB_YESNO|MB_ICONQUESTION "Do you wish to reboot the system?" IDNO +2
    Reboot
  ${EndIf}
FunctionEnd

Function .onInstFailed
  !insertmacro CleanInstDir
FunctionEnd
