!ifndef __PARTICLE_TRIM_NSH__
!define __PARTICLE_TRIM_NSH__

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

!endif # !__PARTICLE_TRIM_NSH__
