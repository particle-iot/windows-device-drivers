. "$PSScriptRoot\env.ps1";

if (-not (Test-Path env:key_secret)) {
    Write-Error "key_secret is not defined"
    Exit 1
}
if (-not (Test-Path env:encryption_secret)) {
    Write-Error "encryption_secret is not defined"
    Exit 1
}

# Clean deploy folder
rm -Recurse -Force deploy
# Create deploy folder
mkdir $path\deploy;
# Copy driver inf files preserving directory structure
robocopy $path\drivers $path\deploy /s ;
# Copy lowcdc.sys files from Release folder
mkdir $path\deploy\serial\win7_81\x86;
mkdir $path\deploy\serial\win7_81\amd64;
cp $path\lowcdc\Release\x86\lowcdc.sys $path\deploy\serial\win7_81\x86\lowcdc_particle.sys;
cp $path\lowcdc\Release\amd64\lowcdc.sys $path\deploy\serial\win7_81\amd64\lowcdc_particle.sys;

# Copy WinUSB co-installers from Windows Driver Kit to Windows 7 DFU and Control Interface drivers
mkdir $path\deploy\dfu\win7\x86;
mkdir $path\deploy\dfu\win7\amd64;
cp $wdk_redist\wdf\x86\WinUsbCoInstaller2.dll $path\deploy\dfu\win7\x86;
cp $wdk_redist\wdf\x86\WdfCoInstaller01011.dll $path\deploy\dfu\win7\x86;
cp $wdk_redist\wdf\x64\WinUsbCoInstaller2.dll $path\deploy\dfu\win7\amd64;
cp $wdk_redist\wdf\x64\WdfCoInstaller01011.dll $path\deploy\dfu\win7\amd64;
mkdir $path\deploy\control\win7\x86;
mkdir $path\deploy\control\win7\amd64;
cp $wdk_redist\wdf\x86\WinUsbCoInstaller2.dll $path\deploy\control\win7\x86;
cp $wdk_redist\wdf\x86\WdfCoInstaller01011.dll $path\deploy\control\win7\x86;
cp $wdk_redist\wdf\x64\WinUsbCoInstaller2.dll $path\deploy\control\win7\amd64;
cp $wdk_redist\wdf\x64\WdfCoInstaller01011.dll $path\deploy\control\win7\amd64;

# Decrypt signing certificate/key
$arg = "aes-256-cbc", "-k", "${env:encryption_secret}", "-in", "$path\cert\particle-code-signing-cert.p12.enc", "-out",
        "$path\cert\particle-code-signing-cert.p12", "-d", "-a";
& ${openssl} $arg;

$sign = "sign", "/v", "/ac", "$path\cert\comodorsacertificationauthority_kmod.crt", "/f", "$path\cert\particle-code-signing-cert.p12", "/p", "${env:key_secret}", "/tr", "http://timestamp.comodoca.com/rfc3161";

# Sign lowcdc.sys drivers for Windows 7 to Windows 8.1
& $signtool ($sign + "$path\deploy\serial\win7_81\x86\lowcdc_particle.sys");
& $signtool ($sign + "$path\deploy\serial\win7_81\amd64\lowcdc_particle.sys");

# inf2cat serial drivers for Windows 10
$arg = "/v", "/driver:$path\deploy\serial\win10", "/os:10_X86,10_X64,Server10_X64";
& ${inf2cat} $arg;
# inf2cat serial drivers for Windows 7 to Windows 8.1
$arg = "/v", "/driver:$path\deploy\serial\win7_81", "/os:6_3_X86,6_3_X64,Server6_3_X64,8_X64,8_X86,Server8_X64,Server2008R2_X64,7_X64,7_X86,Server2008_X64,Server2008_X86";
& ${inf2cat} $arg;
# inf2cat dfu drivers for Windows 7
$arg = "/v", "/driver:$path\deploy\dfu\win7", "/os:Server2008R2_X64,7_X64,7_X86,Server2008_X64,Server2008_X86";
& ${inf2cat} $arg;
# inf2cat dfu drivers for Windows 8 - Windows 10
$arg = "/v", "/driver:$path\deploy\dfu\win8_10", "/os:10_X86,10_X64,Server10_X64,6_3_X86,6_3_X64,Server6_3_X64,8_X64,8_X86,Server8_X64";
& ${inf2cat} $arg;
# inf2cat Control Interface drivers for Windows 7
$arg = "/v", "/driver:$path\deploy\control\win7", "/os:Server2008R2_X64,7_X64,7_X86,Server2008_X64,Server2008_X86";
& ${inf2cat} $arg;

# Sign serial drivers for Windows 10
& $signtool ($sign + "$path\deploy\serial\win10\particle_serial.cat");
# Sign serial drivers for Windows 7 to Windows 8.1
& $signtool ($sign + "$path\deploy\serial\win7_81\particle_serial.cat");
# Sign DFU drivers for Windows 7
& $signtool ($sign + "$path\deploy\dfu\win7\particle_dfu.cat");
# Sign DFU drivers for Windows 8 to Windows 10
& $signtool ($sign + "$path\deploy\dfu\win8_10\particle_dfu.cat");
# Sign Control Interface drivers for Windows 7
& $signtool ($sign + "$path\deploy\control\win7\particle_control.cat");

# Verify signatures for Windows 7 - Windows 8.1 serial drivers
$arg = "verify", "/v", "/kp", "/c", "$path\deploy\serial\win7_81\particle_serial.cat", "$path\deploy\serial\win7_81\amd64\lowcdc_particle.sys";
& $signtool $arg;
$arg = "verify", "/v", "/pa", "/c", "$path\deploy\serial\win7_81\particle_serial.cat", "$path\deploy\serial\win7_81\amd64\lowcdc_particle.sys";
& $signtool $arg;
$arg = "verify", "/v", "/c", "$path\deploy\serial\win7_81\particle_serial.cat", "$path\deploy\serial\win7_81\amd64\lowcdc_particle.sys";
& $signtool $arg;
$arg = "verify", "/v", "/kp", "/c", "$path\deploy\serial\win7_81\particle_serial.cat", "$path\deploy\serial\win7_81\x86\lowcdc_particle.sys";
& $signtool $arg;
$arg = "verify", "/v", "/pa", "/c", "$path\deploy\serial\win7_81\particle_serial.cat", "$path\deploy\serial\win7_81\x86\lowcdc_particle.sys";
& $signtool $arg;
$arg = "verify", "/v", "/c", "$path\deploy\serial\win7_81\particle_serial.cat", "$path\deploy\serial\win7_81\x86\lowcdc_particle.sys";
& $signtool $arg;

# Create a zip
# $arg = "a", "windows-device-drivers.zip", "$path\deploy\*";
# & $7zip $arg;

# Install ExecDos plugin for NSIS
$arg = "-y", "-o`"$path\installer`"", "x", "$path\installer\plugins\ExecDos.zip", '"Plugins"';
& $7zip $arg;

# Copy devcon to installer folder
Copy-Item $path\devcon\Release\devcon.exe $path\installer\bin\x86\devcon.exe ;
Copy-Item $path\devcon\x64\Release\devcon.exe $path\installer\bin\amd64\devcon.exe ;
# Sign devcon binaries
& $signtool ($sign + "$path\installer\bin\x86\devcon.exe");
& $signtool ($sign + "$path\installer\bin\amd64\devcon.exe");

# Create an installer
$arg = "/DDRIVERSDIR=$path\deploy", "/DEXTPLUGINSDIR=$path\installer\Plugins", "/DOUTPUT_DIR=$installer_output_dir", "$path\installer\installer.nsi" ;
& ${makensis} $arg ;
# Sign
& $signtool ($sign + "$installer_output_dir\particle_drivers.exe");
