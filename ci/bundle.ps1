. "$PSScriptRoot\env.ps1";

# Get build path
if (-not (Test-Path env:APPVEYOR_BUILD_FOLDER)) {
    $path = Get-Location;
} else {
    $path = $env:APPVEYOR_BUILD_FOLDER;
}
# Create deploy folder
mkdir $path\deploy;
# Copy driver inf files preserving directory structure
robocopy $path\drivers $path\deploy /s ;
# Copy *.sys files from Release folder preserving directory structure
robocopy $path\lowcdc\Release $path\deploy\serial\win7_81 *.sys /s ;

# inf2cat serial drivers for Windows 10
cmd.exe /c "`"${env:INF2CAT}`" /v /driver:$path\deploy\serial\win10 /os:10_X86,10_X64,Server10_X64";
# inf2cat serial drivers for Windows 7 to Windows 8.1
cmd.exe /c "`"${env:INF2CAT}`" /v /driver:$path\deploy\serial\win7_81 /os:6_3_X86,6_3_X64,Server6_3_X64,8_X64,8_X86,Server8_X64,Server2008R2_X64,7_X64,7_X86,Server2008_X64,Server2008_X86";
# inf2cat dfu drivers for all Windows versions
cmd.exe /c "`"${env:INF2CAT}`" /v /driver:$path\deploy\dfu /os:10_X86,10_X64,Server10_X64,6_3_X86,6_3_X64,Server6_3_X64,8_X64,8_X86,Server8_X64,Server2008R2_X64,7_X64,7_X86,Server2008_X64,Server2008_X86";

# TODO: decrypt key

$sign = "`"${env:SIGNTOOL}`"  sign /v /ac cert\AddTrust_External_CA_Root.cer /f cert\particle-code-signing-cert.p12 /p %key_secret% /tr http://tsa.starfieldtech.com";

# Sign serial drivers for Windows 10
cmd.exe /c "$sign $path\deploy\serial\win10\particle_serial.cat" ;
# Sign serial drivers for Windows 7 to Windows 8.1
cmd.exe /c "$sign $path\deploy\serial\win7_81\x86\lowcdc.sys" ;
cmd.exe /c "$sign $path\deploy\serial\win7_81\amd64\lowcdc.sys" ;
cmd.exe /c "$sign $path\deploy\serial\win7_81\particle_serial.cat" ;
# Sign DFU drivers for all Windows versions
cmd.exe /c "$sign $path\deploy\dfu\particle_dfu.cat" ;

# Create a zip
7z a windows-device-drivers.zip $path\deploy\* ;

# Install ExecDos plugin for NSIS
7z -y -o"${env:NSIS}" x $path\installer\plugins\ExecDos.zip "Plugins";

# Copy trustcertregister.exe to installer folder
Copy-Item $path\trustcertstore\Release\trustcertregister.exe $path\installer\bin\x86\trustcertregister.exe ;

# Sign trustcertregister.exe
cmd.exe /c "$sign $path\installer\bin\x86\trustcertregister.exe" ;

# Copy devcon to installer folder
Copy-Item $path\devcon\Release\devcon.exe $path\installer\bin\x86\devcon.exe ;
Copy-Item $path\devcon\x64\Release\devcon.exe $path\installer\bin\amd64\devcon.exe ;
# Sign devcon binaries
cmd.exe /c "$sign $path\installer\bin\x86\devcon.exe" ;
cmd.exe /c "$sign $path\installer\bin\amd64\devcon.exe" ;

# Create an installer
$param = "/DPRODUCT_VERSION=${env:APPVEYOR_BUILD_VERSION}", "/DDRIVERSDIR=$path\deploy", "$path\installer\installer.nsi" ;
& "${env:MAKENSIS}" $param ;
# Sign
cmd.exe /c "$sign $path\installer\particle_drivers_${env:APPVEYOR_BUILD_VERSION}.exe" ;

exit
