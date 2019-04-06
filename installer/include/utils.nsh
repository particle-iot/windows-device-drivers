!ifndef __PARTICLE_UTILS_NSH__
!define __PARTICLE_UTILS_NSH__

!macro MsvcRedist
  DetailPrint "Installing MSVC redist"
  ${DisableX64FSRedirection}
  ExecDos::exec /DETAILED /TIMEOUT=60000 '"$PLUGINSDIR\bin\$ARCH\vcredist_$ARCH_WIN.exe" /install /passive /norestart' ""
  Pop $0
  ${EnableX64FSRedirection}
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
