@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "ROOT=%~dp0"
set "CODEX_DIR=%USERPROFILE%\.codex"
set "CONFIG=%CODEX_DIR%\config.toml"
set "AGENTS=%CODEX_DIR%\AGENTS.md"
set "STAMP=%DATE:~-4%%DATE:~3,2%%DATE:~0,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "STAMP=%STAMP: =0%"
set "LOG=%ROOT%codex-shell-repair-and-audit-%STAMP%.log"

> "%LOG%" echo Codex shell repair and audit
>> "%LOG%" echo Generated: %DATE% %TIME%
>> "%LOG%" echo USERPROFILE=%USERPROFILE%
>> "%LOG%" echo ROOT=%ROOT%
>> "%LOG%" echo.

echo This will:
echo 1. Back up %USERPROFILE%\.codex\config.toml if it exists.
echo 2. Write a minimal Codex safe-mode config without [windows] sandbox override.
echo 3. Create/update only safe dev folders and user-level tool config.
echo 4. Run a non-blocking workstation audit.
echo.
echo It will not move Docker/WSL, delete caches, delete folders, commit, push, or touch production data.
echo.
set /p APPLY="Type YES to apply: "
if /I not "%APPLY%"=="YES" (
  echo Aborted.
  >> "%LOG%" echo Aborted by user.
  endlocal
  exit /b 0
)

if not exist "%CODEX_DIR%" (
  mkdir "%CODEX_DIR%" >> "%LOG%" 2>&1
)

>> "%LOG%" echo == Backup Codex config ==
if exist "%CONFIG%" (
  copy "%CONFIG%" "%CONFIG%.backup-%STAMP%" >> "%LOG%" 2>&1
  echo Backed up config to:
  echo %CONFIG%.backup-%STAMP%
) else (
  >> "%LOG%" echo config.toml missing; no backup needed.
)

>> "%LOG%" echo == Write safe-mode Codex config ==
> "%CONFIG%" echo model = "gpt-5.4"
>> "%CONFIG%" echo model_reasoning_effort = "medium"
>> "%CONFIG%" echo approval_policy = "on-request"
>> "%CONFIG%" echo sandbox_mode = "workspace-write"
>> "%CONFIG%" echo log_dir = "D:\\Tools\\codex-logs"
>> "%CONFIG%" echo.
>> "%CONFIG%" echo [sandbox_workspace_write]
>> "%CONFIG%" echo network_access = false
if errorlevel 1 (
  echo Failed to write Codex safe-mode config. See log:
  echo %LOG%
  endlocal
  exit /b 1
)

>> "%LOG%" echo == Ensure AGENTS.md exists ==
if not exist "%AGENTS%" (
  > "%AGENTS%" echo # Global instructions for Codex
  >> "%AGENTS%" echo.
  >> "%AGENTS%" echo - Always communicate with the user in Russian.
  >> "%AGENTS%" echo - Be precise, technical, and practical.
  >> "%AGENTS%" echo - Do not guess APIs, class names, method signatures, database schemas, protocol fields, or legal/tax details.
  >> "%AGENTS%" echo - Before editing code, inspect the project.
  >> "%AGENTS%" echo - Never print, copy, commit, or expose secrets.
  >> "%AGENTS%" echo - Do not touch .env, tokens, passwords, Cloudflare credentials, Telegram bot tokens, private certificates, or production configs.
  >> "%AGENTS%" echo - Do not run destructive commands without explicit confirmation.
  >> "%AGENTS%" echo - For Set Retail 10, use Java 8 as the default assumption.
  >> "%AGENTS%" echo - For Set Retail 10, do not add heavy dependencies without approval.
  >> "%AGENTS%" echo - Inspect metainf.xml, MANIFEST.MF generation, strings_ru.xml, strings_en.xml, and pom.xml.
  >> "%AGENTS%" echo - For SBG, use vendor SBG ^(Soft Business Group^).
  >> "%AGENTS%" echo - After important milestones, remind the user to sync changes with GitHub.
  >> "%LOG%" echo AGENTS.md created.
) else (
  >> "%LOG%" echo AGENTS.md already exists; not overwritten.
)

>> "%LOG%" echo == Create directory layout ==
for %%P in (
  "D:\Projects"
  "D:\Projects\sbg"
  "D:\Projects\set10"
  "D:\Projects\clients"
  "D:\Projects\lab"
  "D:\Tools"
  "D:\Tools\npm-global"
  "D:\Tools\npm-cache"
  "D:\Tools\codex-logs"
  "D:\DevCache"
  "D:\DevCache\maven"
  "D:\DevCache\maven\repository"
  "D:\DevCache\gradle"
  "D:\DevCache\pnpm-store"
  "D:\DevCache\pip-cache"
  "D:\SDK"
  "D:\SDK\Set10"
  "E:\Backups"
  "E:\Backups\Projects"
  "E:\Backups\Postgres"
  "E:\Backups\Docker"
  "E:\Backups\Set10"
  "E:\Backups\FiscalDrive"
  "F:\Archive"
  "F:\Archive\OldProjects"
  "F:\Archive\Installers"
  "F:\Archive\ClientLogs"
  "F:\Archive\VMExports"
  "F:\Archive\ReleaseBuilds"
) do (
  if not exist %%~P mkdir %%~P >> "%LOG%" 2>&1
)

>> "%LOG%" echo == Configure npm if available ==
where npm >> "%LOG%" 2>&1
if not errorlevel 1 (
  set "NPM_CONFIG_CACHE=D:\Tools\npm-cache"
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "[Environment]::SetEnvironmentVariable('NPM_CONFIG_CACHE','D:\Tools\npm-cache','User')" >> "%LOG%" 2>&1
  call npm config set prefix "D:\Tools\npm-global" >> "%LOG%" 2>&1
  call npm config set cache "D:\Tools\npm-cache" --location=user >> "%LOG%" 2>&1
  call npm config set cache "D:\Tools\npm-cache" --location=global >> "%LOG%" 2>&1
) else (
  >> "%LOG%" echo npm not found; skipped.
)

>> "%LOG%" echo == Configure user PATH entry ==
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$entry='D:\Tools\npm-global'; $p=[Environment]::GetEnvironmentVariable('PATH','User'); if ([string]::IsNullOrWhiteSpace($p)) { [Environment]::SetEnvironmentVariable('PATH',$entry,'User') } elseif (-not (($p -split ';') | Where-Object { $_.TrimEnd('\') -ieq $entry.TrimEnd('\') })) { [Environment]::SetEnvironmentVariable('PATH',(($p -split ';' | Where-Object { $_ }) + $entry -join ';'),'User') }" >> "%LOG%" 2>&1

>> "%LOG%" echo == Configure Maven local repository ==
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$m2=Join-Path $env:USERPROFILE '.m2'; $settings=Join-Path $m2 'settings.xml'; New-Item -ItemType Directory -Force -Path $m2 | Out-Null; if (Test-Path $settings) { Copy-Item $settings ($settings + '.backup-%STAMP%') -Force; [xml]$xml=Get-Content $settings -Raw; if ($xml.DocumentElement.LocalName -ne 'settings') { throw 'Invalid settings.xml root' } } else { [xml]$xml='<settings xmlns=\"http://maven.apache.org/SETTINGS/1.0.0\"></settings>' }; $ns=$xml.DocumentElement.NamespaceURI; $node=$xml.DocumentElement.ChildNodes | Where-Object { $_.LocalName -eq 'localRepository' } | Select-Object -First 1; if ($null -eq $node) { if ([string]::IsNullOrWhiteSpace($ns)) { $node=$xml.CreateElement('localRepository') } else { $node=$xml.CreateElement('localRepository',$ns) }; [void]$xml.DocumentElement.AppendChild($node) }; $node.InnerText='D:\DevCache\maven\repository'; $xml.Save($settings)" >> "%LOG%" 2>&1

>> "%LOG%" echo == Configure Gradle user home ==
setx GRADLE_USER_HOME "D:\DevCache\gradle" >> "%LOG%" 2>&1

>> "%LOG%" echo == Configure pnpm if available ==
where pnpm >> "%LOG%" 2>&1
if not errorlevel 1 (
  pnpm config set store-dir "D:\DevCache\pnpm-store" >> "%LOG%" 2>&1
) else (
  >> "%LOG%" echo pnpm not found; skipped.
)

>> "%LOG%" echo == Configure pip if available ==
where pip >> "%LOG%" 2>&1
if not errorlevel 1 (
  pip config set global.cache-dir "D:\DevCache\pip-cache" >> "%LOG%" 2>&1
) else (
  >> "%LOG%" echo pip not found; skipped.
)

>> "%LOG%" echo == Run non-blocking audit ==
call "%ROOT%audit-dev-workstation.cmd" >> "%LOG%" 2>&1

echo.
echo Done.
echo Log:
echo %LOG%
echo Audit:
echo %ROOT%dev-layout-audit.txt
echo.
echo Close this window, open a new cmd.exe, then run:
echo   cd /d D:\Projects\_system-setup
echo   codex
echo.
echo If Codex shell works after restart, ask Codex to continue the audit.
endlocal
