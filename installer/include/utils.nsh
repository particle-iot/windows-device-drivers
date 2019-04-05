!ifndef __PARTICLE_UTILS_NSH__
!define __PARTICLE_UTILS_NSH__

!macro MsvcRedist2010
  ${DisableX64FSRedirection}
  ExecDos::exec /DETAILED /TIMEOUT=10000 '"$PLUGINSDIR\bin\x86\vcredist_x86.exe" /q /norestart' ""
  Pop $0
  ${EnableX64FSRedirection}
!macroend

!macro TrustCertRegister
  DetailPrint "Installing Particle certificate"
  ${DisableX64FSRedirection}
  ExecDos::exec /DETAILED /TIMEOUT=10000 '"$PLUGINSDIR\bin\x86\trustcertregister.exe"' ""
  Pop $0
  ${EnableX64FSRedirection}
!macroend

!macro CleanInstDir
  SetOutPath "$TEMP"
  RMDir /r "$INSTDIR"
!macroend

!endif # !__PARTICLE_UTILS_NSH__
