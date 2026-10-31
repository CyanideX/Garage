@echo off
rem run.bat <build dir> [--poses out.json] <folder>...   builds verify_v3 and runs it over converted data
set "PATH=%PATH%;C:\Program Files (x86)\Microsoft Visual Studio\Installer"
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=amd64 >nul
where ninja >nul 2>nul || set "PATH=%LOCALAPPDATA%\Microsoft\WinGet\Packages\Ninja-build.Ninja_Microsoft.Winget.Source_8wekyb3d8bbwe;%PATH%"
rem shift moves %0 too, so grab the script's folder first
set "HERE=%~dp0."
set "B=%~1"
shift
if not exist "%B%\build.ninja" cmake -S "%HERE%" -B "%B%" -G Ninja -DCMAKE_CXX_COMPILER=cl -DCMAKE_BUILD_TYPE=Release >nul || exit /b 1
cmake --build "%B%" --target verify_v3 || exit /b 1
"%B%\verify_v3.exe" %1 %2 %3 %4 %5 %6 %7 %8 %9
