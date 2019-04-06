Unicode true
!addplugindir "${EXTPLUGINSDIR}\x86-unicode"

Var /GLOBAL ARCH
Var /GLOBAL ARCH_WIN
Var /GLOBAL DEVCON
Var /GLOBAL INSTALL_STATE

!include "MUI2.nsh"
!include "WinVer.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"
!include "TextFunc.nsh"
!include "StrFunc.nsh"
!include "WordFunc.nsh"

!addincludedir "include"
!include "trim.nsh"

; Enable these functions
${StrStr}
${StrTok}
${StrLoc}
${StrCase}

!include "utils.nsh"
!include "drivers.nsh"

;--------------------------------
;General

  ; Request application privileges for Windows Vista
  RequestExecutionLevel highest

  !define MUI_ICON "resources\particle.ico"

  !define PRODUCT_NAME "Particle Device Drivers"
  !ifndef PRODUCT_VERSION
    !define PRODUCT_VERSION "1.0.0.0"
  !endif
  !define PRODUCT_PUBLISHER "Particle"
  !define PRODUCT_WEBSITE "http://particle.io"

  ;Name and file
  Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
  !ifndef OUTPUT_DIR
    !define OUTPUT_FILE "particle_drivers.exe"
  !else
    !define OUTPUT_FILE "${OUTPUT_DIR}/particle_drivers.exe"
  !endif
  OutFile "${OUTPUT_FILE}"

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

  ; Welcome page
  !define MUI_WELCOMEFINISHPAGE_BITMAP "resources\particle.bmp"
  !define MUI_WELCOMEPAGE_TITLE "Install ${PRODUCT_NAME}"
  !define /file MUI_WELCOMEPAGE_TEXT "resources\welcome.txt"
  !insertmacro MUI_PAGE_WELCOME

  ; License page
  !insertmacro MUI_PAGE_LICENSE "resources\license.txt"
  ; Components page
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

Section "Uninstall current drivers" SecCleanDrivers
  UserInfo::GetAccountType
  Pop $1
  ${If} $1 != "Admin"
    SetErrorLevel 740
    Abort "This installer needs to be run with administrative privileges"
  ${EndIf}

  SetOutPath "$PLUGINSDIR"
  File /r bin
  SetOutPath "$INSTDIR"

  !insertmacro MsvcRedist

  ; Yes, we are deleting devices twice
  !insertmacro DeleteParticleDevices
  !insertmacro DeleteParticleDrivers
  !insertmacro DeleteParticleDevices
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

  SetOutPath "$PLUGINSDIR\drivers"
  File /r "${DRIVERSDIR}\*"

  SetOutPath "$PLUGINSDIR"
  File /r bin
  SetOutPath "$INSTDIR"

  !insertmacro MsvcRedist
  !insertmacro TrustCertRegister
  !insertmacro InstallDrivers

  !insertmacro RescanDevices

  WriteRegStr HKLM "Software\Particle\Drivers" "Version2" "${PRODUCT_VERSION}"
  ; Also write bogus large version number into the registry value used by an old driver installers
  ; so that they will not try to overwrite us
  ; FIXME: do we still need this?
  WriteRegDWORD HKLM "Software\Particle\drivers" "serial" 99999999
  WriteRegStr HKLM "Software\Particle\Drivers" "Version" "99.99.99.99"
SectionEnd

;--------------------------------
;Descriptions

  ;Language strings
  LangString DESC_SecCleanDrivers ${LANG_ENGLISH} "Uninstalls any previously installed Particle drivers."
  LangString DESC_SecDrivers ${LANG_ENGLISH} "USB drivers for Particle devices."

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
    StrCpy $ARCH_WIN "x64"
    SetRegView 64
  ${Else}
    StrCpy $ARCH "x86"
    StrCpy $ARCH_WIN "x86"
  ${EndIf}

  ${If} ${AtLeastWin7}
    ; ok
  ${Else}
    MessageBox MB_OK|MB_ICONEXCLAMATION "The installer requires at least Windows 7" IDOK
    Abort
  ${EndIf}

  StrCpy $DEVCON "devcon.exe"

  ReadRegStr $0 HKLM "Software\Particle\Drivers" "Version2"
  ${If} $0 != ""
    ${VersionCompare} $0 "${PRODUCT_VERSION}" $1
    ${If} $1 <> 2
      StrCpy $INSTALL_STATE "installed"
    ${Else}
      StrCpy $INSTALL_STATE "update"
    ${EndIf}
  ${Else}
    StrCpy $INSTALL_STATE "clean"
  ${EndIf}

  ${If} ${Silent}
    ${If} $INSTALL_STATE == "installed"
      ; If running silent, skip installation if already installed and the installed
      ; version equals or is greater than ${PRODUCT_VERSION}
      Abort
    ${EndIf}
  ${EndIf}

  ${If} $INSTALL_STATE == "clean"
    !insertmacro SetSectionFlag ${SecCleanDrivers} ${SF_RO}
  ${Else}
    !insertmacro ClearSectionFlag ${SecCleanDrivers} ${SF_SELECTED}
  ${EndIf}
FunctionEnd

Function .onInstSuccess
  ; !insertmacro CleanInstDir
FunctionEnd

Function .onInstFailed
  ; !insertmacro CleanInstDir
FunctionEnd
