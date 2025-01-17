REM execute this script inside elevated (Run as Administrator) console "x64 Native Tools Command Prompt for VS 2019"

echo off

echo Installing chocolatey windows package manager...
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
choco -?
IF %errorlevel% NEQ 0 (
  echo Can't install chocolatey
  exit /b %errorlevel%
)

choco feature enable -n allowEmptyChecksums

echo Installing pkgconfiglite...
choco install -y pkgconfiglite
IF %errorlevel% NEQ 0 (
  echo Can't install pkgconfiglite
  exit /b %errorlevel%
)

echo Installing ninja...
choco install -y ninja
IF %errorlevel% NEQ 0 (
  echo Can't install ninja
  exit /b %errorlevel%
)

echo Installing nasm...
choco install -y nasm
where nasm
SET PATH=%PATH%;C:\Program Files\NASM
IF %errorlevel% NEQ 0 (
  echo Can't install nasm
  exit /b %errorlevel%
)

mkdir third_libs
cd third_libs

set third_libs=%cd%
echo %third_libs%

if not exist "zlib" (
  git clone https://github.com/madler/zlib.git
  cd zlib
  git checkout v1.3.1
  cd contrib\vstudio\vc14
  msbuild zlibstat.vcxproj /p:Configuration=ReleaseWithoutAsm /p:platform=x64 -p:PlatformToolset=v142
  cd ..\..\..\..
) else (
  echo Using zlib...
)

if not exist "lz4" (
  git clone https://github.com/lz4/lz4.git
  cd lz4
  git checkout v1.9.4
  cd build\VS2017\liblz4
  msbuild liblz4.vcxproj /p:Configuration=Release /p:platform=x64 -p:PlatformToolset=v142
  cd ..\..\..\..
) else (
  echo Using lz4...
)

if not exist "libsodium" (
  git clone https://github.com/jedisct1/libsodium
  cd libsodium
  git checkout 1.0.18-RELEASE
  msbuild libsodium.vcxproj /p:Configuration=Release /p:platform=x64 -p:PlatformToolset=v142
  cd ..
) else (
  echo Using libsodium...
)

if not exist "openssl" (
  git clone https://github.com/openssl/openssl.git
  cd openssl
  git checkout openssl-3.1.4
  where perl
  perl Configure VC-WIN64A
  IF %errorlevel% NEQ 0 (
    echo Can't configure openssl
    exit /b %errorlevel%
  )
  nmake
  cd ..
) else (
  echo Using openssl...
)

if not exist "libmicrohttpd" (
  git clone https://github.com/Karlson2k/libmicrohttpd.git
  cd libmicrohttpd
  git checkout v1.0.1
  cd w32\VS2019
  msbuild libmicrohttpd.vcxproj /p:Configuration=Release-static /p:platform=x64 -p:PlatformToolset=v142
  IF %errorlevel% NEQ 0 (
    echo Can't compile libmicrohttpd
    exit /b %errorlevel%
  )
  cd ../../..
) else (
  echo Using libmicrohttpd...
)

cd ..
echo Current dir %cd%

mkdir build
cd build
cmake -GNinja  -DCMAKE_BUILD_TYPE=Debug ^
-DPORTABLE=1 ^
-DSODIUM_USE_STATIC_LIBS=1 ^
-DSODIUM_LIBRARY_RELEASE=%third_libs%\libsodium\Build\Release\x64\libsodium.lib ^
-DSODIUM_LIBRARY_DEBUG=%third_libs%\libsodium\Build\Release\x64\libsodium.lib ^
-DSODIUM_INCLUDE_DIR=%third_libs%\libsodium\src\libsodium\include ^
-DLZ4_FOUND=1 ^
-DLZ4_INCLUDE_DIRS=%third_libs%\lz4\lib ^
-DLZ4_LIBRARIES=%third_libs%\lz4\build\VS2017\liblz4\bin\x64_Release\liblz4_static.lib ^
-DMHD_FOUND=1 ^
-DMHD_LIBRARY=%third_libs%\libmicrohttpd\w32\VS2019\Output\x64\libmicrohttpd.lib ^
-DMHD_INCLUDE_DIR=%third_libs%\libmicrohttpd\src\include ^
-DZLIB_FOUND=1 ^
-DZLIB_INCLUDE_DIR=%third_libs%\zlib ^
-DZLIB_LIBRARIES=%third_libs%\zlib\contrib\vstudio\vc14\x64\ZlibStatReleaseWithoutAsm\zlibstat.lib ^
-DOPENSSL_FOUND=1 ^
-DOPENSSL_INCLUDE_DIR=%third_libs%\openssl\include ^
-DOPENSSL_CRYPTO_LIBRARY=%third_libs%\openssl\libcrypto_static.lib ^
-DCMAKE_CXX_FLAGS="/DTD_WINDOWS=1 /EHsc /bigobj" ..

IF %errorlevel% NEQ 0 (
  echo Can't configure TON
  exit /b %errorlevel%
)

ninja contest-grader

echo Copy artifacts
cd ..
mkdir artifacts

xcopy /e /k /h /i build\contest artifacts\contest
