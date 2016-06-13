# Get build path
$path = $env:APPVEYOR_BUILD_FOLDER;
# Create deploy folder
mkdir $path\deploy;
# Copy *.sys files from Release folder preserving directory structure
robocopy $path\lowcdc\Release $path\deploy *.sys /s ;
# Copy particle.inf into deploy folder
Copy-Item $path\particle.inf $path\deploy\particle.inf ;
# Create a zip
7z a windows-device-drivers.zip $path\deploy\* ;

exit
