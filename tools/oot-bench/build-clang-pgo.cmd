@echo off
rem Build with clang-cl + PGO (the repo's eglantine.profdata) + ThinLTO, the recipe Frizti v3 ships
rem with (~15% faster than MSVC by its author's measurement). Needs LLVM 23+ (the profile's writer).
rem   build-clang-pgo.cmd <source dir> <build dir> [build tag]
setlocal
set "SRC=%~1"
set "OUT=%~2"
set "TAG=%~3"
if "%TAG%"=="" set "TAG=local-clang-pgo"
if "%SRC%"=="" goto usage
if "%OUT%"=="" goto usage
if "%JOBS%"=="" set "JOBS=10"
if "%LLVM%"=="" set "LLVM=D:\BuildTools\clang+llvm-23.1.5-x86_64-pc-windows-msvc"

call "D:\BuildTools\VS2022\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
set "PATH=%LLVM%\bin;D:\BuildTools\cmake-4.1.2-windows-x86_64\bin;D:\BuildTools\ninja;D:\BuildTools\glslang\bin;D:\BuildTools\Qt\6.8.3\msvc2022_64\bin;%PATH%"
set "PROFILE=%SRC:\=/%/eglantine.profdata"
set "PGO=-fprofile-use=%PROFILE% -Wno-backend-plugin -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date -flto=thin"

if not exist "%OUT%\build.ninja" (
  cmake -S "%SRC%" -B "%OUT%" -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ^
    -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl ^
    -DCMAKE_LINKER=lld-link -DCMAKE_AR=llvm-lib ^
    "-DCMAKE_C_FLAGS=%PGO%" "-DCMAKE_CXX_FLAGS=%PGO%" ^
    -DBUILD_TESTING=OFF -DYUZU_TESTS=OFF -DYUZU_CMD=ON ^
    -DYUZU_ROOM=OFF -DYUZU_ROOM_STANDALONE=OFF ^
    -DYUZU_USE_BUNDLED_QT=OFF -DYUZU_USE_BUNDLED_SDL3=ON ^
    -DVulkanHeaders_FORCE_BUNDLED=ON ^
    -DENABLE_UPDATE_CHECKER=OFF -DUSE_DISCORD_PRESENCE=OFF ^
    -DLICHII_BUILD_TAG=%TAG% -DLICHII_BUILD_PLATFORM=windows-x86_64 ^
    "-DCMAKE_PREFIX_PATH=D:/BuildTools/Qt/6.8.3/msvc2022_64" || exit /b 1
)
cmake --build "%OUT%" --parallel %JOBS% || exit /b 1
exit /b 0

:usage
echo usage: build-clang-pgo.cmd ^<source dir^> ^<build dir^> [build tag]
exit /b 2
