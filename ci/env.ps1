# Set defaults
if (-not (Test-Path env:SIGNTOOL)) {
    $env:SIGNTOOL = "C:\Program Files (x86)\Windows Kits\10\bin\x86\signtool.exe";
}

if (-not (Test-Path env:INF2CAT)) {
    $env:INF2CAT = "C:\Program Files (x86)\Windows Kits\10\bin\x86\inf2cat.exe";
}

if (-not (Test-Path env:NSIS)) {
    $env:NSIS = "C:\Program Files (x86)\NSIS";
}

if (-not (Test-Path env:MAKENSIS)) {
    $env:MAKENSIS = "${env:NSIS}\makensis.exe";
}

if (-not (Test-Path env:MSBUILD)) {
    $env:MSBUILD = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\MSBuild\15.0\bin\msbuild.exe";
}
