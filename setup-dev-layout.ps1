param(
    [switch]$ApplyCodexConfig,
    [switch]$ApplyCodexAgents,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host ''
    Write-Host "== $Message =="
}

function New-DirectoryIfMissing {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "created: $Path"
    } else {
        Write-Host "exists:  $Path"
    }
}

function Backup-File {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupPath = "$Path.backup-$stamp"
        Copy-Item -LiteralPath $Path -Destination $backupPath -Force
        Write-Host "backup: $backupPath"
        return $backupPath
    }
    return $null
}

function Confirm-Write {
    param(
        [string]$Prompt,
        [switch]$AutoYes
    )
    if ($AutoYes) {
        return $true
    }
    $answer = Read-Host "$Prompt [y/N]"
    return $answer -match '^(y|yes)$'
}

function Set-UserPathEntry {
    param([string]$Entry)

    $current = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ([string]::IsNullOrWhiteSpace($current)) {
        [Environment]::SetEnvironmentVariable('PATH', $Entry, 'User')
        Write-Host "user PATH initialized with: $Entry"
        return
    }

    $parts = $current -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $exists = $parts | Where-Object { $_.TrimEnd('\') -ieq $Entry.TrimEnd('\') }
    if ($exists) {
        Write-Host "user PATH already contains: $Entry"
        return
    }

    $updated = ($parts + $Entry) -join ';'
    [Environment]::SetEnvironmentVariable('PATH', $updated, 'User')
    Write-Host "user PATH appended: $Entry"
}

function Set-OrAppend-XmlElementText {
    param(
        [xml]$Xml,
        [string]$ElementName,
        [string]$Value
    )

    $namespace = $Xml.DocumentElement.NamespaceURI
    $node = $Xml.DocumentElement.ChildNodes | Where-Object { $_.LocalName -eq $ElementName } | Select-Object -First 1
    if ($null -eq $node) {
        if ([string]::IsNullOrWhiteSpace($namespace)) {
            $newNode = $Xml.CreateElement($ElementName)
        } else {
            $newNode = $Xml.CreateElement($ElementName, $namespace)
        }
        $newNode.InnerText = $Value
        [void]$Xml.DocumentElement.AppendChild($newNode)
    } else {
        $node.InnerText = $Value
    }
}

function Update-MavenSettings {
    param([string]$RepositoryPath)

    $m2Dir = Join-Path $env:USERPROFILE '.m2'
    $settingsPath = Join-Path $m2Dir 'settings.xml'
    New-DirectoryIfMissing -Path $m2Dir

    if (Test-Path -LiteralPath $settingsPath) {
        Backup-File -Path $settingsPath | Out-Null
        [xml]$xml = Get-Content -LiteralPath $settingsPath -Raw
        if ($null -eq $xml.DocumentElement -or $xml.DocumentElement.LocalName -ne 'settings') {
            throw "Existing Maven settings.xml has no <settings> root: $settingsPath"
        }
    } else {
        [xml]$xml = '<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd"></settings>'
    }

    Set-OrAppend-XmlElementText -Xml $xml -ElementName 'localRepository' -Value $RepositoryPath
    $xml.Save($settingsPath)
    Write-Host "maven localRepository set: $RepositoryPath"
}

function Get-ToolHomeFromBinCommand {
    param(
        [string]$CommandName,
        [string]$ExpectedBinLeaf
    )

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command -or [string]::IsNullOrWhiteSpace($command.Source)) {
        return $null
    }

    $binPath = Split-Path -Parent $command.Source
    if ([string]::IsNullOrWhiteSpace($binPath) -or ((Split-Path -Leaf $binPath) -ine $ExpectedBinLeaf)) {
        return $null
    }

    return Split-Path -Parent $binPath
}

function Set-TomlScalar {
    param(
        [string]$Text,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )

    $lines = if ([string]::IsNullOrEmpty($Text)) { @() } else { $Text -split "`r?`n" }
    $output = New-Object System.Collections.Generic.List[string]
    $targetRoot = [string]::IsNullOrEmpty($Section)
    $inTarget = $targetRoot
    $sectionSeen = $targetRoot
    $keyWritten = $false
    $sectionPattern = if ($targetRoot) { $null } else { "^\[$([regex]::Escape($Section))\]\s*$" }

    foreach ($line in $lines) {
        $trim = $line.Trim()
        $isSectionHeader = $trim -match '^\[.+\]\s*$'

        if ($targetRoot -and $isSectionHeader) {
            if (-not $keyWritten) {
                $output.Add("$Key = $Value")
                $keyWritten = $true
            }
            $inTarget = $false
            $output.Add($line)
            continue
        }

        if (-not $targetRoot -and $isSectionHeader) {
            if ($inTarget -and -not $keyWritten) {
                $output.Add("$Key = $Value")
                $keyWritten = $true
            }
            $inTarget = $trim -match $sectionPattern
            if ($inTarget) {
                $sectionSeen = $true
            }
            $output.Add($line)
            continue
        }

        if ($inTarget -and $trim -match "^$([regex]::Escape($Key))\s*=") {
            if (-not $keyWritten) {
                $output.Add("$Key = $Value")
                $keyWritten = $true
            }
            continue
        }

        $output.Add($line)
    }

    if ($targetRoot -and -not $keyWritten) {
        $output.Add("$Key = $Value")
    } elseif (-not $targetRoot -and -not $sectionSeen) {
        if ($output.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($output[$output.Count - 1])) {
            $output.Add('')
        }
        $output.Add("[$Section]")
        $output.Add("$Key = $Value")
    } elseif (-not $targetRoot -and $inTarget -and -not $keyWritten) {
        $output.Add("$Key = $Value")
    }

    return (($output -join "`r`n").TrimEnd() + "`r`n")
}

function Set-TomlBlock {
    param(
        [string]$Text,
        [string]$Section,
        [string]$Key,
        [string[]]$BlockLines
    )

    $lines = if ([string]::IsNullOrEmpty($Text)) { @() } else { $Text -split "`r?`n" }
    $output = New-Object System.Collections.Generic.List[string]
    $sectionPattern = "^\[$([regex]::Escape($Section))\]\s*$"
    $inTarget = $false
    $sectionSeen = $false
    $blockWritten = $false
    $skipOldBlock = $false

    foreach ($line in $lines) {
        $trim = $line.Trim()
        $isSectionHeader = $trim -match '^\[.+\]\s*$'

        if ($isSectionHeader) {
            if ($inTarget -and -not $blockWritten) {
                $BlockLines | ForEach-Object { $output.Add($_) }
                $blockWritten = $true
            }
            $inTarget = $trim -match $sectionPattern
            if ($inTarget) {
                $sectionSeen = $true
            }
            $skipOldBlock = $false
            $output.Add($line)
            continue
        }

        if ($inTarget -and $trim -match "^$([regex]::Escape($Key))\s*=") {
            if (-not $blockWritten) {
                $BlockLines | ForEach-Object { $output.Add($_) }
                $blockWritten = $true
            }
            if ($trim -match '\[\s*$' -and $trim -notmatch '\]\s*$') {
                $skipOldBlock = $true
            }
            continue
        }

        if ($skipOldBlock) {
            if ($trim -match '^\]\s*$') {
                $skipOldBlock = $false
            }
            continue
        }

        $output.Add($line)
    }

    if (-not $sectionSeen) {
        if ($output.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($output[$output.Count - 1])) {
            $output.Add('')
        }
        $output.Add("[$Section]")
        $BlockLines | ForEach-Object { $output.Add($_) }
    } elseif ($inTarget -and -not $blockWritten) {
        $BlockLines | ForEach-Object { $output.Add($_) }
    }

    return (($output -join "`r`n").TrimEnd() + "`r`n")
}

function Update-CodexConfigText {
    param([string]$ExistingText)

    $text = $ExistingText
    $text = Set-TomlScalar -Text $text -Section '' -Key 'model' -Value '"gpt-5.4"'
    $text = Set-TomlScalar -Text $text -Section '' -Key 'model_reasoning_effort' -Value '"medium"'
    $text = Set-TomlScalar -Text $text -Section '' -Key 'personality' -Value '"pragmatic"'
    $text = Set-TomlScalar -Text $text -Section '' -Key 'approval_policy' -Value '"on-request"'
    $text = Set-TomlScalar -Text $text -Section '' -Key 'sandbox_mode' -Value '"workspace-write"'
    $text = Set-TomlScalar -Text $text -Section '' -Key 'log_dir' -Value '"D:\\Tools\\codex-logs"'
    $text = Set-TomlScalar -Text $text -Section 'sandbox_workspace_write' -Key 'network_access' -Value 'false'
    $text = Set-TomlBlock -Text $text -Section 'shell_environment_policy' -Key 'include_only' -BlockLines @(
        'include_only = [',
        '  "PATH",',
        '  "HOME",',
        '  "USERPROFILE",',
        '  "TEMP",',
        '  "TMP",',
        '  "JAVA_HOME",',
        '  "MAVEN_HOME",',
        '  "GRADLE_USER_HOME",',
        '  "NODE_HOME"',
        ']'
    )
    $text = Set-TomlScalar -Text $text -Section 'profiles.readonly' -Key 'approval_policy' -Value '"on-request"'
    $text = Set-TomlScalar -Text $text -Section 'profiles.readonly' -Key 'sandbox_mode' -Value '"read-only"'
    $text = Set-TomlScalar -Text $text -Section 'profiles.net' -Key 'approval_policy' -Value '"on-request"'
    $text = Set-TomlScalar -Text $text -Section 'profiles.net' -Key 'sandbox_mode' -Value '"workspace-write"'
    $text = Set-TomlScalar -Text $text -Section 'profiles.net.sandbox_workspace_write' -Key 'network_access' -Value 'true'
    return $text
}

function Show-FileDiff {
    param(
        [string]$CurrentPath,
        [string]$ProposedPath
    )

    if (Get-Command git -ErrorAction SilentlyContinue) {
        git --no-pager diff --no-index -- "$CurrentPath" "$ProposedPath"
    } else {
        Write-Host "git not found; proposed file written for manual review: $ProposedPath"
    }
}

function Update-CodexConfig {
    param(
        [switch]$Apply,
        [switch]$AutoYes
    )

    $codexDir = Join-Path $env:USERPROFILE '.codex'
    $configPath = Join-Path $codexDir 'config.toml'
    $proposedPath = Join-Path $codexDir 'config.toml.proposed'
    New-DirectoryIfMissing -Path $codexDir

    $existing = ''
    if (Test-Path -LiteralPath $configPath) {
        $existing = Get-Content -LiteralPath $configPath -Raw
    }

    $proposed = Update-CodexConfigText -ExistingText $existing
    Set-Content -LiteralPath $proposedPath -Value $proposed -Encoding UTF8
    Write-Host "proposed Codex config: $proposedPath"

    if (Test-Path -LiteralPath $configPath) {
        Show-FileDiff -CurrentPath $configPath -ProposedPath $proposedPath
    } else {
        Write-Host "Codex config does not exist yet; proposed file was generated."
    }

    if ($Apply -or (Confirm-Write -Prompt "Write proposed Codex config to $configPath?" -AutoYes:$AutoYes)) {
        Backup-File -Path $configPath | Out-Null
        Copy-Item -LiteralPath $proposedPath -Destination $configPath -Force
        Write-Host "codex config updated: $configPath"
    } else {
        Write-Host "codex config not changed"
    }
}

function Get-AgentsContent {
    $agentsSource = Join-Path $PSScriptRoot 'AGENTS.md'
    if (-not (Test-Path -LiteralPath $agentsSource)) {
        throw "Canonical AGENTS.md not found: $agentsSource"
    }

    $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
    return [System.IO.File]::ReadAllText($agentsSource, $utf8Strict)
}

function Update-CodexAgents {
    param(
        [switch]$Apply,
        [switch]$AutoYes
    )

    $codexDir = Join-Path $env:USERPROFILE '.codex'
    $agentsPath = Join-Path $codexDir 'AGENTS.md'
    $proposedPath = Join-Path $codexDir 'AGENTS.md.proposed'
    New-DirectoryIfMissing -Path $codexDir

    $content = Get-AgentsContent
    Set-Content -LiteralPath $proposedPath -Value $content -Encoding UTF8
    Write-Host "proposed Codex AGENTS.md: $proposedPath"

    if (Test-Path -LiteralPath $agentsPath) {
        Show-FileDiff -CurrentPath $agentsPath -ProposedPath $proposedPath
    } else {
        Write-Host "Codex AGENTS.md does not exist yet; proposed file was generated."
    }

    if ($Apply -or (Confirm-Write -Prompt "Write proposed Codex AGENTS.md to $agentsPath?" -AutoYes:$AutoYes)) {
        Backup-File -Path $agentsPath | Out-Null
        Copy-Item -LiteralPath $proposedPath -Destination $agentsPath -Force
        Write-Host "codex AGENTS.md updated: $agentsPath"
    } else {
        Write-Host "codex AGENTS.md not changed"
    }
}

Write-Step "Create directory layout"
$directories = @(
    'D:\Projects',
    'D:\Projects\sbg',
    'D:\Projects\set10',
    'D:\Projects\clients',
    'D:\Projects\lab',
    'D:\Tools',
    'D:\Tools\npm-global',
    'D:\Tools\npm-cache',
    'D:\Tools\codex-logs',
    'D:\DevCache',
    'D:\DevCache\maven\repository',
    'D:\DevCache\gradle',
    'D:\DevCache\pnpm-store',
    'D:\DevCache\pip-cache',
    'D:\SDK',
    'D:\SDK\Set10',
    'E:\Backups',
    'E:\Backups\Projects',
    'E:\Backups\Postgres',
    'E:\Backups\Docker',
    'E:\Backups\Set10',
    'E:\Backups\FiscalDrive',
    'F:\Archive',
    'F:\Archive\OldProjects',
    'F:\Archive\Installers',
    'F:\Archive\ClientLogs',
    'F:\Archive\VMExports',
    'F:\Archive\ReleaseBuilds'
)
$directories | ForEach-Object { New-DirectoryIfMissing -Path $_ }

Write-Step "Configure npm"
if (Get-Command npm -ErrorAction SilentlyContinue) {
    [Environment]::SetEnvironmentVariable('NPM_CONFIG_CACHE', 'D:\Tools\npm-cache', 'User')
    $env:NPM_CONFIG_CACHE = 'D:\Tools\npm-cache'
    npm config set prefix 'D:\Tools\npm-global'
    npm config set cache 'D:\Tools\npm-cache' --location=user
    npm config set cache 'D:\Tools\npm-cache' --location=global
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $pwsh -and -not [string]::IsNullOrWhiteSpace($pwsh.Source)) {
        npm config set script-shell $pwsh.Source
        Write-Host "npm script-shell set: $($pwsh.Source)"
    } else {
        Write-Host 'pwsh not found; npm script-shell left unchanged'
    }
    Write-Host 'npm prefix/cache configured'
    Write-Host 'NPM_CONFIG_CACHE set: D:\Tools\npm-cache'
} else {
    Write-Host 'npm not found; skipped'
}

Write-Step "Configure user PATH"
Set-UserPathEntry -Entry 'D:\Tools\npm-global'

Write-Step "Configure Maven local repository"
Update-MavenSettings -RepositoryPath 'D:\DevCache\maven\repository'
$mavenHome = Get-ToolHomeFromBinCommand -CommandName 'mvn' -ExpectedBinLeaf 'bin'
if ($mavenHome) {
    [Environment]::SetEnvironmentVariable('MAVEN_HOME', $mavenHome, 'User')
    Write-Host "MAVEN_HOME set: $mavenHome"
} else {
    Write-Host 'mvn not found in a standard bin directory; MAVEN_HOME left unchanged'
}

Write-Step "Configure Gradle user home"
[Environment]::SetEnvironmentVariable('GRADLE_USER_HOME', 'D:\DevCache\gradle', 'User')
Write-Host 'GRADLE_USER_HOME set: D:\DevCache\gradle'

Write-Step "Configure pnpm store if pnpm is installed"
if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    pnpm config set store-dir 'D:\DevCache\pnpm-store'
    Write-Host 'pnpm store-dir configured'
} else {
    Write-Host 'pnpm not found; skipped'
}

Write-Step "Configure pip cache if pip is installed"
if (Get-Command pip -ErrorAction SilentlyContinue) {
    pip config set global.cache-dir 'D:\DevCache\pip-cache'
    Write-Host 'pip cache-dir configured'
} else {
    Write-Host 'pip not found; skipped'
}

Write-Step "Prepare Codex config"
Update-CodexConfig -Apply:$ApplyCodexConfig -AutoYes:$NonInteractive

Write-Step "Prepare Codex AGENTS.md"
Update-CodexAgents -Apply:$ApplyCodexAgents -AutoYes:$NonInteractive

Write-Step "Done"
Write-Host 'Docker Desktop and WSL were not moved or modified.'
Write-Host 'Open a new terminal session so user PATH and GRADLE_USER_HOME are visible to new processes.'
