@if "%DEBUG%" == "" @echo off
@rem ###########################################################################
@rem
@rem  hvigor startup script for Windows (TransmissionRemote)
@rem
@rem  This is a thin shim. All of the actual work — locating DevEco Studio,
@rem  exporting DEVECO_SDK_HOME / JAVA_HOME and running hvigor — lives in
@rem  scripts\run-hvigor.mjs, so that cmd.exe, Git Bash and CI all behave the
@rem  same way instead of each having its own drifting copy of the logic.
@rem
@rem  Usage:
@rem    hvigorw clean
@rem    hvigorw assembleHap -p product=default -p buildMode=debug
@rem    hvigorw --print-env
@rem
@rem  Set DEVECO_HOME if DevEco Studio is installed somewhere unusual:
@rem    set DEVECO_HOME=D:\Huawei\DevEco Studio
@rem
@rem ###########################################################################

if "%OS%" == "Windows_NT" setlocal

where node >NUL 2>&1
if not "%ERRORLEVEL%" == "0" (
  echo.
  echo ERROR: 'node' was not found in PATH.
  echo.
  echo hvigor itself needs Node.js. DevEco Studio bundles one at
  echo   "^<DevEco^>\tools\node"
  echo Add that directory to PATH, or install Node.js, and try again.
  exit /b 1
)

node "%~dp0scripts\run-hvigor.mjs" %*
if "%ERRORLEVEL%" == "0" goto :hvigorwEnd

set "HVIGORW_EXIT=%ERRORLEVEL%"
if "%OS%" == "Windows_NT" endlocal & exit /b %HVIGORW_EXIT%
exit /b %HVIGORW_EXIT%

:hvigorwEnd
if "%OS%" == "Windows_NT" endlocal
