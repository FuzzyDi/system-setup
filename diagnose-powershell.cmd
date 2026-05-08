@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "OUT=%~dp0powershell-diagnostics.txt"

> "%OUT%" echo PowerShell diagnostics
>> "%OUT%" echo Generated: %DATE% %TIME%
>> "%OUT%" echo Working directory: %CD%
>> "%OUT%" echo.

>> "%OUT%" echo == Windows ==
ver >> "%OUT%" 2>&1
>> "%OUT%" echo.

>> "%OUT%" echo == Current user context ==
whoami >> "%OUT%" 2>&1
>> "%OUT%" echo USERPROFILE=%USERPROFILE%
>> "%OUT%" echo.

>> "%OUT%" echo == Executables ==
where powershell >> "%OUT%" 2>&1
where pwsh >> "%OUT%" 2>&1
where dotnet >> "%OUT%" 2>&1
>> "%OUT%" echo.

>> "%OUT%" echo == Windows PowerShell registry ==
reg query "HKLM\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine" /v PowerShellVersion >> "%OUT%" 2>&1
reg query "HKLM\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine" /v ApplicationBase >> "%OUT%" 2>&1
reg query "HKLM\SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine" /v PowerShellVersion >> "%OUT%" 2>&1
>> "%OUT%" echo.

>> "%OUT%" echo == PowerShell Core registry ==
reg query "HKLM\SOFTWARE\Microsoft\PowerShellCore\InstalledVersions" /s >> "%OUT%" 2>&1
>> "%OUT%" echo.

>> "%OUT%" echo == .NET Framework registry ==
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release >> "%OUT%" 2>&1
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Version >> "%OUT%" 2>&1
>> "%OUT%" echo.

>> "%OUT%" echo == Crypto service ==
sc query cryptsvc >> "%OUT%" 2>&1
>> "%OUT%" echo.

>> "%OUT%" echo == Profile file presence only, no content ==
if exist "%USERPROFILE%\Documents\WindowsPowerShell\profile.ps1" (
  >> "%OUT%" echo exists: %USERPROFILE%\Documents\WindowsPowerShell\profile.ps1
) else (
  >> "%OUT%" echo missing: %USERPROFILE%\Documents\WindowsPowerShell\profile.ps1
)
if exist "%USERPROFILE%\Documents\PowerShell\profile.ps1" (
  >> "%OUT%" echo exists: %USERPROFILE%\Documents\PowerShell\profile.ps1
) else (
  >> "%OUT%" echo missing: %USERPROFILE%\Documents\PowerShell\profile.ps1
)
if exist "%WINDIR%\System32\WindowsPowerShell\v1.0\profile.ps1" (
  >> "%OUT%" echo exists: %WINDIR%\System32\WindowsPowerShell\v1.0\profile.ps1
) else (
  >> "%OUT%" echo missing: %WINDIR%\System32\WindowsPowerShell\v1.0\profile.ps1
)
>> "%OUT%" echo.

>> "%OUT%" echo == Test: powershell.exe -NoProfile ==
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$PSVersionTable | Out-String" >> "%OUT%" 2>&1
>> "%OUT%" echo exit code: %ERRORLEVEL%
>> "%OUT%" echo.

>> "%OUT%" echo == Test: powershell.exe minimal Get-Date ==
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-Date" >> "%OUT%" 2>&1
>> "%OUT%" echo exit code: %ERRORLEVEL%
>> "%OUT%" echo.

>> "%OUT%" echo == Test: pwsh.exe if installed ==
pwsh.exe -NoLogo -NoProfile -NonInteractive -Command "$PSVersionTable | Out-String" >> "%OUT%" 2>&1
>> "%OUT%" echo exit code: %ERRORLEVEL%
>> "%OUT%" echo.

>> "%OUT%" echo == dotnet --info if installed ==
dotnet --info >> "%OUT%" 2>&1
>> "%OUT%" echo exit code: %ERRORLEVEL%
>> "%OUT%" echo.

echo Diagnostics written to:
echo %OUT%
echo.
echo Open the file and send the sections around failed PowerShell tests.
endlocal
