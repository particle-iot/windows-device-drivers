. "$PSScriptRoot\env.ps1";

cmd.exe /c "`"${env:MSBUILD}`" lowcdc\lowcdc.proj /verbosity:minimal";
cmd.exe /c "`"${env:MSBUILD}`" trustcertstore\trustcertregister.sln /p:Configuration=Release /p:Platform=Win32 /verbosity:minimal";
cmd.exe /c "`"${env:MSBUILD}`" devcon\devcon.sln /p:Configuration=Release /p:Platform=x64 /verbosity:minimal";
cmd.exe /c "`"${env:MSBUILD}`" devcon\devcon.sln /p:Configuration=Release /p:Platform=Win32 /verbosity:minimal";
