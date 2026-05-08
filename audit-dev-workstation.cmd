@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "OUT=%~dp0dev-layout-audit.txt"

> "%OUT%" echo Dev workstation audit
>> "%OUT%" echo Generated: %DATE% %TIME%
>> "%OUT%" echo Working directory: %CD%
>> "%OUT%" echo User: %USERNAME%
>> "%OUT%" echo USERPROFILE=%USERPROFILE%
>> "%OUT%" echo.

>> "%OUT%" echo == Disk space C D E F ==
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.DeviceID -in @('C:','D:','E:','F:') } | Select-Object DeviceID,VolumeName,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},@{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,2)}},@{n='FreePercent';e={[math]::Round(($_.FreeSpace/$_.Size)*100,1)}} | Format-Table -AutoSize" >> "%OUT%" 2>&1
if errorlevel 1 (
  >> "%OUT%" echo PowerShell disk query failed; falling back to dir summaries.
  for %%D in (C D E F) do (
    >> "%OUT%" echo -- %%D: --
    dir %%D:\ >> "%OUT%" 2>&1
  )
)
>> "%OUT%" echo.

>> "%OUT%" echo == Executable locations ==
for %%N in (node npm codex git java mvn docker pnpm pip powershell) do (
  >> "%OUT%" echo -- %%N --
  where %%N >> "%OUT%" 2>&1
)
>> "%OUT%" echo.

>> "%OUT%" echo == Tool versions ==
node --version >> "%OUT%" 2>&1
call npm --version >> "%OUT%" 2>&1
>> "%OUT%" echo git --version skipped: keep audit non-blocking.
>> "%OUT%" echo java -version skipped: keep audit non-blocking.
>> "%OUT%" echo mvn --version skipped: keep audit non-blocking.
>> "%OUT%" echo pnpm --version skipped: keep audit non-blocking.
>> "%OUT%" echo pip --version skipped: keep audit non-blocking.
>> "%OUT%" echo codex --version skipped: may start interactive CLI or hang in current environment.
>> "%OUT%" echo docker --version skipped: docker executable was already checked by where.
>> "%OUT%" echo.

>> "%OUT%" echo == npm config ==
call npm config get prefix >> "%OUT%" 2>&1
call npm config get cache >> "%OUT%" 2>&1
>> "%OUT%" echo.

>> "%OUT%" echo == npm global packages depth 0 ==
call npm list -g --depth=0 >> "%OUT%" 2>&1
>> "%OUT%" echo.

>> "%OUT%" echo == User environment variables from HKCU Environment ==
reg query HKCU\Environment /v PATH >> "%OUT%" 2>&1
reg query HKCU\Environment /v JAVA_HOME >> "%OUT%" 2>&1
reg query HKCU\Environment /v MAVEN_HOME >> "%OUT%" 2>&1
reg query HKCU\Environment /v GRADLE_USER_HOME >> "%OUT%" 2>&1
>> "%OUT%" echo.

>> "%OUT%" echo == Process environment snapshot, selected only ==
>> "%OUT%" echo PATH=%PATH%
>> "%OUT%" echo JAVA_HOME=%JAVA_HOME%
>> "%OUT%" echo MAVEN_HOME=%MAVEN_HOME%
>> "%OUT%" echo GRADLE_USER_HOME=%GRADLE_USER_HOME%
>> "%OUT%" echo.

>> "%OUT%" echo == Docker Desktop presence ==
where docker >> "%OUT%" 2>&1
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Docker Desktop" >> "%OUT%" 2>&1
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Docker Desktop" >> "%OUT%" 2>&1
sc query com.docker.service >> "%OUT%" 2>&1
>> "%OUT%" echo.

>> "%OUT%" echo == WSL presence ==
where wsl >> "%OUT%" 2>&1
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$null = & wsl --status 2>$null; if ($LASTEXITCODE -eq 0) { 'wsl --status: ok' } else { 'wsl --status: failed or WSL is not installed/initialized' }; $lxss='HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'; if (Test-Path $lxss) { 'WSL distro registry entries:'; Get-ChildItem $lxss | ForEach-Object { $p=Get-ItemProperty $_.PSPath; ' - ' + $p.DistributionName } } else { 'WSL distro registry entries: none' }" >> "%OUT%" 2>&1
>> "%OUT%" echo.

>> "%OUT%" echo == Folder presence ==
for %%P in (
  "D:\Projects"
  "D:\Tools"
  "D:\DevCache"
  "D:\SDK"
  "D:\Docker"
  "E:\Backups"
  "F:\Archive"
) do (
  if exist %%~P (
    >> "%OUT%" echo exists: %%~P
  ) else (
    >> "%OUT%" echo missing: %%~P
  )
)
>> "%OUT%" echo.

>> "%OUT%" echo == Codex files presence only ==
if exist "%USERPROFILE%\.codex\config.toml" (
  >> "%OUT%" echo exists: %USERPROFILE%\.codex\config.toml
) else (
  >> "%OUT%" echo missing: %USERPROFILE%\.codex\config.toml
)
if exist "%USERPROFILE%\.codex\AGENTS.md" (
  >> "%OUT%" echo exists: %USERPROFILE%\.codex\AGENTS.md
) else (
  >> "%OUT%" echo missing: %USERPROFILE%\.codex\AGENTS.md
)
>> "%OUT%" echo.

>> "%OUT%" echo == Codex config safe key scan, no full file dump ==
if exist "%USERPROFILE%\.codex\config.toml" (
  findstr /R /I /C:"^[ ]*model[ ]*=" /C:"^[ ]*model_reasoning_effort[ ]*=" /C:"^[ ]*approval_policy[ ]*=" /C:"^[ ]*sandbox_mode[ ]*=" /C:"^[ ]*log_dir[ ]*=" /C:"^\[windows\]" /C:"^\[sandbox_workspace_write\]" /C:"^\[shell_environment_policy\]" "%USERPROFILE%\.codex\config.toml" >> "%OUT%" 2>&1
  findstr /R /I /C:"^[ ]*network_access[ ]*=" "%USERPROFILE%\.codex\config.toml" >> "%OUT%" 2>&1
) else (
  >> "%OUT%" echo config.toml not found
)
>> "%OUT%" echo.

echo Audit written to:
echo %OUT%
echo.
echo This script did not change system settings.
endlocal
