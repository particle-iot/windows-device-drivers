. "$PSScriptRoot\env.ps1";

# Building lowcdc driver
$arg = "lowcdc\lowcdc.proj", "/verbosity:minimal";
& ${msbuild} $arg;

# Building trustcertregister
$arg = "trustcertstore\trustcertregister.sln", "/p:Configuration=Release", "/p:Platform=Win32", "/verbosity:minimal";
& ${msbuild} $arg;

# Building devcon for amd64
$arg = "devcon\devcon.sln", "/p:Configuration=Release", "/p:Platform=x64", "/verbosity:minimal";
& ${msbuild} $arg;

# Building devcon for x86
$arg = "devcon\devcon.sln", "/p:Configuration=Release", "/p:Platform=Win32", "/verbosity:minimal";
& ${msbuild} $arg;
