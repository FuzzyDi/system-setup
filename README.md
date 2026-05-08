# System Setup Workspace

Набор локальных скриптов для диагностики и безопасной настройки рабочей станции разработки.

GitHub repository:

```text
https://github.com/FuzzyDi/system-setup
```

## Назначение

- `audit-dev-workstation.cmd` - только читает состояние и формирует `dev-layout-audit.txt`.
- `setup-dev-layout.ps1` - создает целевые каталоги и настраивает user-level cache/config для npm, Maven, Gradle, pnpm, pip и Codex.
- `run-codex-shell-repair-and-audit.cmd` - интерактивно применяет safe-mode Codex config, создает dev-layout и запускает аудит.
- `codex-config-safe-mode.cmd` - интерактивно заменяет только Codex config на минимальный safe-mode вариант.
- `diagnose-powershell.cmd` - собирает диагностику PowerShell в `powershell-diagnostics.txt`.

## Текущий стандарт раскладки

- Projects: `D:\Projects`
- Tools: `D:\Tools`
- npm global: `D:\Tools\npm-global`
- npm cache: `D:\Tools\npm-cache`
- Maven local repository: `D:\DevCache\maven\repository`
- Gradle user home: `D:\DevCache\gradle`
- pnpm store: `D:\DevCache\pnpm-store`
- pip cache: `D:\DevCache\pip-cache`
- SDK: `D:\SDK`
- Backups: `E:\Backups`
- Archive: `F:\Archive`

Docker Desktop и WSL этими скриптами не переносятся.

## Bootstrap на новой машине

1. Установить Git.

2. Клонировать репозиторий:

```cmd
cd /d D:\Projects
git clone https://github.com/FuzzyDi/system-setup.git _system-setup
cd /d D:\Projects\_system-setup
```

3. Проверить shell:

```powershell
Get-Date
```

4. Запустить read-only аудит:

```cmd
D:\Projects\_system-setup\audit-dev-workstation.cmd
```

5. Проверить ключевые строки в `dev-layout-audit.txt`:

```text
npm prefix: D:\Tools\npm-global
npm cache:  D:\Tools\npm-cache
sandbox_mode = "workspace-write"
network_access = false
```

## Применение настроек

`setup-dev-layout.ps1` меняет user-level настройки инструментов. Перед применением нужно понимать, что будут изменены:

- `%USERPROFILE%\.m2\settings.xml`
- `%USERPROFILE%\.codex\config.toml`, если применить `-ApplyCodexConfig`
- `%USERPROFILE%\.codex\AGENTS.md`, если применить `-ApplyCodexAgents`
- user environment variables: `GRADLE_USER_HOME`, `NPM_CONFIG_CACHE`
- npm, pnpm и pip user/global config

Интерактивный запуск:

```powershell
PowerShell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\_system-setup\setup-dev-layout.ps1
```

Не использовать `-NonInteractive`, если не готов принять все записи без подтверждения.

## Codex safe-mode

Текущий безопасный минимум для `C:\Users\Rashid\.codex\config.toml`:

```toml
model = "gpt-5.5"
model_reasoning_effort = "high"
approval_policy = "on-request"
sandbox_mode = "workspace-write"
log_dir = "D:\\Tools\\codex-logs"

[sandbox_workspace_write]
network_access = false
```

Секция `[windows] sandbox = "elevated"` не используется в safe-mode конфигурации.

## Проверка PowerShell

Быстрая проверка:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Get-Date; 'OK'"
```

Полная локальная диагностика:

```cmd
D:\Projects\_system-setup\diagnose-powershell.cmd
```

Отчет `powershell-diagnostics.txt` не коммитится.

## Что не делать без отдельного подтверждения

- Не удалять cache/directories.
- Не запускать Docker/WSL migration.
- Не выполнять `git reset --hard`, `git clean -fdx`, `rm -rf`.
- Не печатать содержимое `.env`, `auth.json`, tokens, credentials, certificates или production configs.
- Не выполнять production migrations и команды, которые трогают POS/fiscal/printer devices.

## Git workflow

Локальный репозиторий синхронизирован с GitHub:

```cmd
git remote -v
git status --short --branch
git log --oneline -3
```

Сгенерированные отчеты, логи и backup-файлы исключены через `.gitignore`, потому что содержат локальные пути и состояние конкретной рабочей станции.

Перед важным изменением:

```cmd
git status --short --branch
```

После изменения:

```cmd
git add <files>
git commit -m "<message>"
git push
```
