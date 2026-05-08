@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "CODEX_DIR=%USERPROFILE%\.codex"
set "CONFIG=%CODEX_DIR%\config.toml"
set "SAFE=%CODEX_DIR%\config.toml.safe-mode"
set "STAMP=%DATE:~-4%%DATE:~3,2%%DATE:~0,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "STAMP=%STAMP: =0%"
set "BACKUP=%CONFIG%.backup-%STAMP%"

echo Codex config safe-mode helper
echo.
echo This script can back up the current Codex config and replace it with
echo a minimal workspace-write config for troubleshooting shell startup.
echo.
echo It does not touch Docker, WSL, npm, Maven, Gradle, projects, or caches.
echo.

if not exist "%CODEX_DIR%" (
  mkdir "%CODEX_DIR%"
)

> "%SAFE%" echo model = "gpt-5.5"
>> "%SAFE%" echo model_reasoning_effort = "high"
>> "%SAFE%" echo approval_policy = "on-request"
>> "%SAFE%" echo sandbox_mode = "workspace-write"
>> "%SAFE%" echo.
>> "%SAFE%" echo [sandbox_workspace_write]
>> "%SAFE%" echo network_access = false

echo Safe-mode config prepared:
echo %SAFE%
echo.

if exist "%CONFIG%" (
  echo Current config exists:
  echo %CONFIG%
  echo.
  echo Backup will be:
  echo %BACKUP%
) else (
  echo Current config does not exist:
  echo %CONFIG%
)

echo.
set /p APPLY="Apply safe-mode config now? Type YES to continue: "
if /I not "%APPLY%"=="YES" (
  echo Not changed.
  endlocal
  exit /b 0
)

if exist "%CONFIG%" (
  copy "%CONFIG%" "%BACKUP%" >nul
  if errorlevel 1 (
    echo Failed to create backup. Aborting.
    endlocal
    exit /b 1
  )
  echo Backup created:
  echo %BACKUP%
)

copy "%SAFE%" "%CONFIG%" >nul
if errorlevel 1 (
  echo Failed to write safe-mode config.
  endlocal
  exit /b 1
)

echo.
echo Safe-mode config applied:
echo %CONFIG%
echo.
echo Next test from a new cmd.exe window:
echo   cd /d D:\Projects\_system-setup
echo   codex
echo.
echo To restore manually:
echo   copy "%BACKUP%" "%CONFIG%"
endlocal
