Set-StrictMode -Version Latest

function Get-MemoryRulesRepositoryRoot {
    param([Parameter(Mandatory)][string]$CallingScriptRoot)

    return [System.IO.Path]::GetFullPath((Join-Path $CallingScriptRoot '..'))
}

function Get-MemoryRulesUserProfile {
    $profilePath = [Environment]::GetFolderPath('UserProfile')
    if ([string]::IsNullOrWhiteSpace($profilePath)) {
        $profilePath = $env:USERPROFILE
    }
    if ([string]::IsNullOrWhiteSpace($profilePath)) {
        $profilePath = $env:HOME
    }
    if ([string]::IsNullOrWhiteSpace($profilePath) -or -not [System.IO.Path]::IsPathRooted($profilePath)) {
        throw 'Cannot resolve an absolute user profile directory. Specify -CodexHome or -ClaudeHome.'
    }
    return [System.IO.Path]::GetFullPath($profilePath)
}

function Get-CodexSkillsHome {
    param([string]$OverridePath = '')
    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        return [System.IO.Path]::GetFullPath($OverridePath)
    }
    return Join-Path (Get-MemoryRulesUserProfile) '.agents/skills'
}

function Get-SharedSkillManagedFiles {
    param([string]$RepositoryRoot, [string]$ConfigurationHome, [string]$SkillsHome = '')
    if ([string]::IsNullOrWhiteSpace($SkillsHome)) { $SkillsHome = Join-Path $ConfigurationHome 'skills' }
    $skillRoot = Join-Path $RepositoryRoot 'skills/game-workflow'
    if (-not (Test-Path -LiteralPath (Join-Path $skillRoot 'SKILL.md') -PathType Leaf)) {
        throw "Missing shared skill: $skillRoot"
    }
    Get-ChildItem -LiteralPath $skillRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relativePath = $_.FullName.Substring($skillRoot.Length).TrimStart('\', '/')
        [pscustomobject]@{
            Source = $_.FullName
            Target = Join-Path $SkillsHome "game-workflow/$relativePath"
        }
    }
}

function Assert-ManagedParentPathsSafe {
    param([string]$Path)
    $parentPath = Split-Path -Parent ([System.IO.Path]::GetFullPath($Path))
    while (-not [string]::IsNullOrWhiteSpace($parentPath)) {
        Assert-MemoryPathIsNotReparsePoint -Path $parentPath -Purpose 'Managed parent directory'
        $nextParent = Split-Path -Parent $parentPath
        if ($nextParent -eq $parentPath) { break }
        $parentPath = $nextParent
    }
}

function Get-CodexConfigurationHome {
    param([string]$OverridePath = '')

    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        return [System.IO.Path]::GetFullPath($OverridePath)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        return [System.IO.Path]::GetFullPath($env:CODEX_HOME)
    }

    return Join-Path (Get-MemoryRulesUserProfile) '.codex'
}

function Get-ClaudeConfigurationHome {
    param([string]$OverridePath = '')

    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        return [System.IO.Path]::GetFullPath($OverridePath)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:CLAUDE_CONFIG_DIR)) {
        return [System.IO.Path]::GetFullPath($env:CLAUDE_CONFIG_DIR)
    }

    return Join-Path (Get-MemoryRulesUserProfile) '.claude'
}

function Get-MemoryProjectRoot {
    param([Parameter(Mandatory)][string]$WorkingDirectory)

    $resolvedDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory)
    $currentDirectory = [System.IO.DirectoryInfo]::new($resolvedDirectory)
    while ($currentDirectory) {
        if (Test-Path -LiteralPath (Join-Path $currentDirectory.FullName '.git')) {
            return $currentDirectory.FullName
        }

        $currentDirectory = $currentDirectory.Parent
    }

    $pathRoot = [System.IO.Path]::GetPathRoot($resolvedDirectory)
    if ($resolvedDirectory -eq $pathRoot) {
        return $resolvedDirectory
    }

    return $resolvedDirectory.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Get-MemoryCanonicalPath {
    param([Parameter(Mandatory)][string]$Path)

    $canonicalPath = [System.IO.Path]::GetFullPath($Path).Normalize([System.Text.NormalizationForm]::FormC)
    $pathRoot = [System.IO.Path]::GetPathRoot($canonicalPath)
    if ($canonicalPath -eq $pathRoot) {
        return $canonicalPath
    }

    return $canonicalPath.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Test-MemoryPathInsideRoot {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root
    )

    $canonicalPath = Get-MemoryCanonicalPath -Path $Path
    $canonicalRoot = Get-MemoryCanonicalPath -Path $Root
    $comparison = if ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }
    $rootPrefix = $canonicalRoot.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    return $canonicalPath.StartsWith($rootPrefix, $comparison)
}

function Assert-MemoryPathIsNotReparsePoint {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Purpose
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw "$Purpose cannot be a symbolic link or reparse point: $Path"
    }
}

function Get-FileSha256 {
    param([Parameter(Mandatory)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Cannot calculate SHA-256 because the file path is empty.'
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Cannot calculate SHA-256 because the file does not exist: $Path"
    }

    $stream = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite
    )
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $algorithm.ComputeHash($stream)
        return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '')
    } finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
}

function Test-FileContentEqual {
    param(
        [Parameter(Mandatory)][string]$FirstPath,
        [Parameter(Mandatory)][string]$SecondPath
    )

    if (-not (Test-Path -LiteralPath $FirstPath -PathType Leaf)) {
        return $false
    }

    if (-not (Test-Path -LiteralPath $SecondPath -PathType Leaf)) {
        return $false
    }

    return (Get-FileSha256 -Path $FirstPath) -eq (Get-FileSha256 -Path $SecondPath)
}

function Test-SymbolicLinkTargetsPath {
    param(
        [Parameter(Mandatory)][string]$LinkPath,
        [Parameter(Mandatory)][string]$ExpectedTarget
    )

    $item = Get-Item -LiteralPath $LinkPath -Force -ErrorAction SilentlyContinue
    if (-not $item -or $item.LinkType -ne 'SymbolicLink') {
        return $false
    }

    $targetValue = @($item.Target)[0]
    if ([string]::IsNullOrWhiteSpace([string]$targetValue)) {
        return $false
    }

    $resolvedTarget = if ([System.IO.Path]::IsPathRooted([string]$targetValue)) {
        [System.IO.Path]::GetFullPath([string]$targetValue)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $item.DirectoryName ([string]$targetValue)))
    }

    return $resolvedTarget -eq [System.IO.Path]::GetFullPath($ExpectedTarget)
}

function New-DirectoryIfMissing {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$CommandContext
    )

    if (Test-Path -LiteralPath $Path -PathType Container) {
        return
    }
    if (Test-Path -LiteralPath $Path) {
        throw "Cannot create a directory because another item already occupies the path: $Path"
    }

    if ($CommandContext.ShouldProcess($Path, 'Create directory')) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function ConvertTo-PortableJson {
    param([Parameter(Mandatory)]$Value)

    return ($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine
}
