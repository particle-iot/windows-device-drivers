!ifndef __PARTICLE_UTILS_NSH__
!define __PARTICLE_UTILS_NSH__

!macro MsvcRedist
  # Check if not already installed
  StrCpy $1 0
  ${If} $ARCH == "x86"
    ReadRegStr $1 HKLM "SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" "Installed"
  ${Else}
    ReadRegStr $1 HKLM "SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86" "Installed"
  ${EndIf}
  ${If} $1 != 1
    DetailPrint "Installing MSVC redist"
    ${DisableX64FSRedirection}
    ExecDos::exec /DETAILED /TIMEOUT=60000 '"$PLUGINSDIR\bin\$ARCH\vcredist_$ARCH_WIN.exe" /install /quiet /norestart' ""
    Pop $0
    ${EnableX64FSRedirection}
  ${EndIf}
!macroend

!macro TrustCertRegister
  DetailPrint "Installing Particle certificate"
  ${DisableX64FSRedirection}
  ExecDos::exec /DETAILED /TIMEOUT=60000 '"$PLUGINSDIR\bin\$ARCH\trustcertregister.exe"' ""
  Pop $0
  ${EnableX64FSRedirection}
!macroend

!macro CleanInstDir
  SetOutPath "$TEMP"
  RMDir /r "$INSTDIR"
!macroend

!endif # !__PARTICLE_UTILS_NSH__
