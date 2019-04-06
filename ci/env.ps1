# Set defaults
if (-not (Test-Path env:SIGNTOOL)) {
    $signtool = "C:\Program Files (x86)\Windows Kits\10\Tools\bin\i386\signtool.exe";
} else {
    $signtool = ${env:SIGNTOOL};
}

if (-not (Test-Path env:INF2CAT)) {
    $inf2cat = "C:\Program Files (x86)\Windows Kits\10\bin\x86\inf2cat.exe";
} else {
    $inf2cat = ${env:INF2CAT};
}

if (-not (Test-Path env:NSIS)) {
    $nsis = "C:\Program Files (x86)\NSIS";
} else {
    $nsis = ${env:NSIS};
}

if (-not (Test-Path env:MAKENSIS)) {
    $makensis = "${nsis}\makensis.exe";
} else {
    $makensis = ${env:MAKENSIS};
}

if (-not (Test-Path env:MSBUILD)) {
    $msbuild = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\MSBuild\15.0\bin\msbuild.exe";
} else {
    $msbuild = ${env:MSBUILD};
}

if (-not (Test-Path env:7ZIP)) {
    $7zip = "C:\Program Files\7-Zip\7z.exe";
} else {
    $7zip = ${env:7ZIP};
}

if (-not (Test-Path env:OPENSSL)) {
    $openssl = "openssl";
} else {
    $openssl = ${env:OPENSSL};
}

# Get build path
if (-not (Test-Path env:APPVEYOR_BUILD_FOLDER)) {
    $path = "$PSScriptRoot\..\";
} else {
    $path = $env:APPVEYOR_BUILD_FOLDER;
}
