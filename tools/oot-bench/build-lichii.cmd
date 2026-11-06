@echo off
rem Build Lichii on this PC with MSVC + Ninja, same flags as the Windows release workflow.
rem   build-lichii.cmd <source dir> <build dir> [build tag]
setlocal
set "SRC=%~1"
set "OUT=%~2"
set "TAG=%~3"
if "%TAG%"=="" set "TAG=local"
if "%SRC%"=="" goto usage
if "%OUT%"=="" goto usage

call "D:\BuildTools\VS2022\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
set "PATH=D:\BuildTools\cmake-4.1.2-windows-x86_64\bin;D:\BuildTools\ninja;D:\BuildTools\glslang\bin;D:\BuildTools\Qt\6.8.3\msvc2022_64\bin;%PATH%"
set "CPM_SOURCE_CACHE=D:\BuildTools\cpm-cache"

if not exist "%OUT%\build.ninja" (
  cmake -S "%SRC%" -B "%OUT%" -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ^
    -DBUILD_TESTING=OFF -DYUZU_TESTS=OFF -DYUZU_CMD=ON ^
    -DYUZU_ROOM=OFF -DYUZU_ROOM_STANDALONE=OFF ^
    -DYUZU_USE_BUNDLED_QT=OFF -DYUZU_USE_BUNDLED_SDL3=ON ^
    -DVulkanHeaders_FORCE_BUNDLED=ON ^
    -DENABLE_UPDATE_CHECKER=OFF -DUSE_DISCORD_PRESENCE=OFF ^
    -DLICHII_BUILD_TAG=%TAG% -DLICHII_BUILD_PLATFORM=windows-x86_64 ^
    "-DCMAKE_PREFIX_PATH=D:/BuildTools/Qt/6.8.3/msvc2022_64" || exit /b 1
)
if "%JOBS%"=="" set "JOBS=10"
cmake --build "%OUT%" --parallel %JOBS% || exit /b 1
exit /b 0

:usage
echo usage: build-lichii.cmd ^<source dir^> ^<build dir^> [build tag]
exit /b 2
