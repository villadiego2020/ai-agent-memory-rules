Set-StrictMode -Version Latest

function Get-MemoryRulesRepositoryRoot {
    param([Parameter(Mandatory)][string]$CallingScriptRoot)

    return [System.IO.Path]::GetFullPath((Join-Path $CallingScriptRoot '..'))
}

function Get-CodexConfigurationHome {
    param([string]$OverridePath = '')

    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        return [System.IO.Path]::GetFullPath($OverridePath)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        return [System.IO.Path]::GetFullPath($env:CODEX_HOME)
    }

    return Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
}

function Get-ClaudeConfigurationHome {
    param([string]$OverridePath = '')

    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        return [System.IO.Path]::GetFullPath($OverridePath)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:CLAUDE_CONFIG_DIR)) {
        return [System.IO.Path]::GetFullPath($env:CLAUDE_CONFIG_DIR)
    }

    return Join-Path ([Environment]::GetFolderPath('UserProfile')) '.claude'
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

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
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
