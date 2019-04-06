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
# Copy *.sys files from Release folder preserving directory structure
robocopy $path\lowcdc\Release $path\deploy\serial\win7_81 *.sys /s ;

# inf2cat serial drivers for Windows 10
$arg = "/v", "/driver:$path\deploy\serial\win10", "/os:10_X86,10_X64,Server10_X64";
& ${inf2cat} $arg;
# inf2cat serial drivers for Windows 7 to Windows 8.1
$arg = "/v", "/driver:$path\deploy\serial\win7_81", "/os:6_3_X86,6_3_X64,Server6_3_X64,8_X64,8_X86,Server8_X64,Server2008R2_X64,7_X64,7_X86,Server2008_X64,Server2008_X86";
& ${inf2cat} $arg;
# inf2cat dfu drivers for all Windows versions
$arg = "/v", "/driver:$path\deploy\dfu", "/os:10_X86,10_X64,Server10_X64,6_3_X86,6_3_X64,Server6_3_X64,8_X64,8_X86,Server8_X64,Server2008R2_X64,7_X64,7_X86,Server2008_X64,Server2008_X86";
& ${inf2cat} $arg;

# Decrypt signing certificate/key
$arg = "aes-256-cbc", "-k", "${env:encryption_secret}", "-in", "$path\cert\particle-code-signing-cert.p12.enc", "-out",
        "$path\cert\particle-code-signing-cert.p12", "-d", "-a";
& ${openssl} $arg;

$sign = "sign", "/v", "/f", "$path\cert\particle-code-signing-cert.p12", "/p", "${env:key_secret}";

# Sign serial drivers for Windows 10
& $signtool ($sign + "$path\deploy\serial\win10\particle_serial.cat");
# Sign serial drivers for Windows 7 to Windows 8.1
& $signtool ($sign + "$path\deploy\serial\win7_81\x86\lowcdc.sys");
& $signtool ($sign + "$path\deploy\serial\win7_81\amd64\lowcdc.sys");
& $signtool ($sign + "$path\deploy\serial\win7_81\particle_serial.cat");
# Sign DFU drivers for all Windows versions
& $signtool ($sign + "$path\deploy\dfu\particle_dfu.cat");

# Create a zip
# $arg = "a", "windows-device-drivers.zip", "$path\deploy\*";
# & $7zip $arg;

# Install ExecDos plugin for NSIS
mkdir $path\deploy\nsis;
$arg = "-y", "-o`"$path\deploy\nsis`"", "x", "$path\installer\plugins\ExecDos.zip", '"Plugins"';
& $7zip $arg;

# Copy trustcertregister.exe to installer folder
Copy-Item $path\trustcertstore\Release\trustcertregister.exe $path\installer\bin\x86\trustcertregister.exe ;

# Sign trustcertregister.exe
& $signtool ($sign + "$path\installer\bin\x86\trustcertregister.exe");

# Copy devcon to installer folder
Copy-Item $path\devcon\Release\devcon.exe $path\installer\bin\x86\devcon.exe ;
Copy-Item $path\devcon\x64\Release\devcon.exe $path\installer\bin\amd64\devcon.exe ;
# Sign devcon binaries
& $signtool ($sign + "$path\installer\bin\x86\devcon.exe");
& $signtool ($sign + "$path\installer\bin\amd64\devcon.exe");

# Create an installer
$arg = "/DDRIVERSDIR=$path\deploy", "/DEXTPLUGINSDIR=$path\deploy\nsis\Plugins", "/DOUTPUT_DIR=$installer_output_dir", "$path\installer\installer.nsi" ;
& ${makensis} $arg ;
# Sign
& $signtool ($sign + "$installer_output_dir\particle_drivers.exe");
