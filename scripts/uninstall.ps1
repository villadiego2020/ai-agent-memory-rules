[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [ValidateSet('Codex', 'Claude', 'Both')]
    [string]$Platform = 'Codex',

    [string]$CodexHome = '',
    [string]$CodexSkillsHome = '',
    [string]$ClaudeHome = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/MemoryRules.Common.ps1')

$uninstallTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$managedHookMarker = '(ai-agent-memory-rules)'
$repositoryRoot = Get-MemoryRulesRepositoryRoot -CallingScriptRoot $PSScriptRoot
$pathStringComparer = if ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    [System.StringComparer]::OrdinalIgnoreCase
} else {
    [System.StringComparer]::Ordinal
}
$pathStringComparison = if ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    [System.StringComparison]::OrdinalIgnoreCase
} else {
    [System.StringComparison]::Ordinal
}

function Get-CanonicalPath {
    param([Parameter(Mandatory)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'A managed path cannot be empty.'
    }
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        throw "A managed path must be absolute: $Path"
    }

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

function Test-CanonicalPathInsideRoot {
    param(
        [Parameter(Mandatory)][string]$CanonicalPath,
        [Parameter(Mandatory)][string]$CanonicalRoot
    )

    $rootPrefix = $CanonicalRoot.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    return $CanonicalPath.StartsWith($rootPrefix, $pathStringComparison)
}

function Get-ExpectedManagedFiles {
    param(
        [Parameter(Mandatory)][string]$SelectedPlatform,
        [Parameter(Mandatory)][string]$ConfigurationHome
    )

    $definitions = [System.Collections.Generic.List[object]]::new()
    if ($SelectedPlatform -eq 'Codex') {
        $definitions.Add([pscustomobject]@{
            Source = Join-Path $repositoryRoot 'codex/AGENTS.md'
            Target = Join-Path $ConfigurationHome 'AGENTS.md'
        })
        Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'codex/agents') -Filter '*.toml' -File |
            Sort-Object Name |
            ForEach-Object {
                $definitions.Add([pscustomobject]@{
                    Source = $_.FullName
                    Target = Join-Path $ConfigurationHome "agents/$($_.Name)"
                })
            }
        $definitions.Add([pscustomobject]@{
            Source = Join-Path $repositoryRoot 'codex/hooks/load-project-memory.ps1'
            Target = Join-Path $ConfigurationHome 'hooks/load-project-memory.ps1'
        })
    } else {
        $definitions.Add([pscustomobject]@{
            Source = Join-Path $repositoryRoot 'RULES.md'
            Target = Join-Path $ConfigurationHome 'CLAUDE.md'
        })
        Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'agents') -Filter '*.md' -File |
            Where-Object Name -ne 'README.md' |
            Sort-Object Name |
            ForEach-Object {
                $definitions.Add([pscustomobject]@{
                    Source = $_.FullName
                    Target = Join-Path $ConfigurationHome "agents/$($_.Name)"
                })
            }
    }

    $skillsHome = if ($SelectedPlatform -eq 'Codex') { Get-CodexSkillsHome -OverridePath $CodexSkillsHome } else { Join-Path $ConfigurationHome 'skills' }
    foreach ($skillFile in @(Get-SharedSkillManagedFiles -RepositoryRoot $repositoryRoot -ConfigurationHome $ConfigurationHome -SkillsHome $skillsHome)) {
        $definitions.Add($skillFile)
    }
    return $definitions
}

function Get-ValidatedInstallManifest {
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$SelectedPlatform,
        [Parameter(Mandatory)][string]$ConfigurationHome
    )

    try {
        $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    } catch {
        throw "Cannot safely uninstall because the installation manifest is invalid JSON: $ManifestPath"
    }
    if ($manifest -is [System.Array]) {
        throw "Cannot safely uninstall because the installation manifest must be one JSON object: $ManifestPath"
    }

    foreach ($requiredProperty in @('tool', 'platform', 'mode', 'managedFiles')) {
        if (-not $manifest.PSObject.Properties[$requiredProperty]) {
            throw "Cannot safely uninstall because the installation manifest is missing '$requiredProperty': $ManifestPath"
        }
    }
    if ($manifest.tool -ne 'ai-agent-memory-rules') {
        throw "Cannot safely uninstall from an unrecognized manifest: $ManifestPath"
    }
    if ($manifest.platform -ne $SelectedPlatform) {
        throw "Cannot safely uninstall because manifest platform '$($manifest.platform)' does not match '$SelectedPlatform'."
    }
    if ([string]$manifest.mode -notin @('Link', 'Copy')) {
        throw "Cannot safely uninstall because manifest mode '$($manifest.mode)' is not Link or Copy."
    }
    if ($manifest.managedFiles -isnot [System.Array]) {
        throw 'Cannot safely uninstall because managedFiles must be a JSON array.'
    }

    $canonicalConfigurationHome = Get-CanonicalPath -Path $ConfigurationHome
    $skillsHome = if ($SelectedPlatform -eq 'Codex') { Get-CodexSkillsHome -OverridePath $CodexSkillsHome } else { Join-Path $ConfigurationHome 'skills' }
    $canonicalSkillRoot = Get-CanonicalPath -Path (Join-Path $skillsHome 'game-workflow')
    $expectedByTarget = [System.Collections.Generic.Dictionary[string, object]]::new($pathStringComparer)
    foreach ($expectedFile in @(Get-ExpectedManagedFiles -SelectedPlatform $SelectedPlatform -ConfigurationHome $canonicalConfigurationHome)) {
        $canonicalTarget = Get-CanonicalPath -Path $expectedFile.Target
        $canonicalSource = Get-CanonicalPath -Path $expectedFile.Source
        if (-not (Test-CanonicalPathInsideRoot -CanonicalPath $canonicalTarget -CanonicalRoot $canonicalConfigurationHome) -and -not (Test-CanonicalPathInsideRoot -CanonicalPath $canonicalTarget -CanonicalRoot $canonicalSkillRoot)) {
            throw "Internal safety error: expected managed path is outside the selected configuration home: $canonicalTarget"
        }
        $expectedByTarget.Add($canonicalTarget, [pscustomobject]@{
            Source = $canonicalSource
            Target = $canonicalTarget
        })
    }

    $validatedRecords = [System.Collections.Generic.List[object]]::new()
    $seenTargets = [System.Collections.Generic.HashSet[string]]::new($pathStringComparer)
    foreach ($record in @($manifest.managedFiles)) {
        if ($record -is [System.Array]) {
            throw 'Cannot safely uninstall because each managedFiles entry must be one JSON object.'
        }
        foreach ($requiredProperty in @('source', 'target', 'installedHash')) {
            if (-not $record.PSObject.Properties[$requiredProperty]) {
                throw "Cannot safely uninstall because a managedFiles entry is missing '$requiredProperty'."
            }
            if ($record.$requiredProperty -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$record.$requiredProperty)) {
                throw "Cannot safely uninstall because managedFiles.$requiredProperty must be a non-empty string."
            }
        }
        if ([string]$record.installedHash -notmatch '^[A-Fa-f0-9]{64}$') {
            throw 'Cannot safely uninstall because managedFiles.installedHash must be a SHA-256 hash.'
        }

        $canonicalTarget = Get-CanonicalPath -Path ([string]$record.target)
        Assert-ManagedParentPathsSafe -Path $canonicalTarget
        if (-not (Test-CanonicalPathInsideRoot -CanonicalPath $canonicalTarget -CanonicalRoot $canonicalConfigurationHome) -and -not (Test-CanonicalPathInsideRoot -CanonicalPath $canonicalTarget -CanonicalRoot $canonicalSkillRoot)) {
            throw "Cannot safely uninstall because a manifest target is outside the selected configuration home: $canonicalTarget"
        }
        if (-not $expectedByTarget.ContainsKey($canonicalTarget)) {
            throw "Cannot safely uninstall because a manifest target is not owned by this installer: $canonicalTarget"
        }
        if (-not $seenTargets.Add($canonicalTarget)) {
            throw "Cannot safely uninstall because a manifest target is duplicated: $canonicalTarget"
        }

        $expectedFile = $expectedByTarget[$canonicalTarget]
        $canonicalSource = Get-CanonicalPath -Path ([string]$record.source)
        if (-not $pathStringComparer.Equals($canonicalSource, [string]$expectedFile.Source)) {
            throw "Cannot safely uninstall because a manifest source does not match this repository: $canonicalSource"
        }
        $validatedRecords.Add([pscustomobject]@{
            source = $expectedFile.Source
            target = $expectedFile.Target
            installedHash = ([string]$record.installedHash).ToUpperInvariant()
        })
    }

    # Older manifests predate shared skills. Require the original complete set;
    # any present skill records still pass the exact source/target allowlist above.
    foreach ($expectedTarget in $expectedByTarget.Keys) {
        if (-not (Test-MemoryPathInsideRoot -Path $expectedTarget -Root $canonicalSkillRoot) -and -not $seenTargets.Contains($expectedTarget)) {
            throw 'Cannot safely uninstall because the manifest does not contain every original installer-owned path exactly once.'
        }
    }

    return [pscustomobject]@{
        tool = 'ai-agent-memory-rules'
        platform = $SelectedPlatform
        mode = [string]$manifest.mode
        managedFiles = @($validatedRecords)
    }
}

function Test-InstalledFileUnchanged {
    param(
        [Parameter(Mandatory)]$ManagedFile,
        [Parameter(Mandatory)][string]$InstallMode
    )

    if ($InstallMode -eq 'Link') {
        return Test-SymbolicLinkTargetsPath -LinkPath $ManagedFile.target -ExpectedTarget $ManagedFile.source
    }

    if (-not (Test-Path -LiteralPath $ManagedFile.target -PathType Leaf)) {
        return $false
    }

    return (Get-FileSha256 -Path $ManagedFile.target) -eq [string]$ManagedFile.installedHash
}

function Backup-FileBeforeForcedRemoval {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ConfigurationHome,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Records
    )

    $backupRoot = Join-Path $ConfigurationHome ".ai-agent-memory-rules/backups/uninstall-$uninstallTimestamp"
    New-DirectoryIfMissing -Path $backupRoot -CommandContext $PSCmdlet
    $leafName = [System.IO.Path]::GetFileName($Path) -replace '[^A-Za-z0-9._-]', '_'
    $safeName = "$leafName.$([Guid]::NewGuid().ToString('N').Substring(0, 8)).backup"
    $backupPath = Join-Path $backupRoot $safeName
    $item = Get-Item -LiteralPath $Path -Force

    if ($PSCmdlet.ShouldProcess($Path, "Back up modified file to $backupPath")) {
        if ($item.LinkType -eq 'SymbolicLink') {
            [System.IO.File]::WriteAllText($backupPath + '.link-target.txt', [string](@($item.Target)[0]))
            $recordedBackup = $backupPath + '.link-target.txt'
        } else {
            Copy-Item -LiteralPath $Path -Destination $backupPath -Force
            $recordedBackup = $backupPath
        }
        $Records.Add([pscustomobject]@{
            OriginalPath = $Path
            BackupPath = $recordedBackup
            CreatedAt = (Get-Date).ToString('o')
        })
    }
}

function Remove-ManagedHooks {
    param(
        [Parameter(Mandatory)][string]$ConfigurationHome,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$BackupRecords
    )

    $hooksPath = Join-Path $ConfigurationHome 'hooks.json'
    if (-not (Test-Path -LiteralPath $hooksPath -PathType Leaf)) {
        return
    }

    $hooksDocument = Get-Content -LiteralPath $hooksPath -Raw | ConvertFrom-Json
    if (-not $hooksDocument.PSObject.Properties['hooks']) {
        return
    }

    $changed = $false
    foreach ($eventName in @('SessionStart', 'SubagentStart')) {
        if (-not $hooksDocument.hooks.PSObject.Properties[$eventName]) {
            continue
        }

        $originalGroups = @($hooksDocument.hooks.$eventName)
        $preservedGroups = @($originalGroups | Where-Object {
            $isManaged = $false
            foreach ($handler in @($_.hooks)) {
                if ([string]$handler.statusMessage -like "*$managedHookMarker*") {
                    $isManaged = $true
                }
            }
            -not $isManaged
        })
        if ($preservedGroups.Count -ne $originalGroups.Count) {
            $hooksDocument.hooks.$eventName = $preservedGroups
            $changed = $true
        }
    }

    if (-not $changed) {
        return
    }

    Backup-FileBeforeForcedRemoval -Path $hooksPath -ConfigurationHome $ConfigurationHome -Records $BackupRecords
    if ($PSCmdlet.ShouldProcess($hooksPath, 'Remove only ai-agent-memory-rules hook entries')) {
        [System.IO.File]::WriteAllText($hooksPath, (ConvertTo-PortableJson -Value $hooksDocument))
    }
}

function Uninstall-Platform {
    param(
        [Parameter(Mandatory)][string]$SelectedPlatform,
        [Parameter(Mandatory)][string]$ConfigurationHome
    )

    $manifestPath = Join-Path $ConfigurationHome '.ai-agent-memory-rules/install-manifest.json'
    Assert-ManagedParentPathsSafe -Path $manifestPath
    Assert-MemoryPathIsNotReparsePoint -Path $manifestPath -Purpose 'Installation manifest'
    Assert-ManagedParentPathsSafe -Path (Join-Path $ConfigurationHome '.ai-agent-memory-rules/backups/manifest.json')
    Assert-MemoryPathIsNotReparsePoint -Path (Join-Path $ConfigurationHome 'hooks.json') -Purpose 'Hooks configuration'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Cannot safely uninstall $SelectedPlatform because its manifest is missing: $manifestPath"
    }

    $manifest = Get-ValidatedInstallManifest -ManifestPath $manifestPath -SelectedPlatform $SelectedPlatform -ConfigurationHome $ConfigurationHome

    $modifiedTargets = [System.Collections.Generic.List[string]]::new()
    foreach ($managedFile in @($manifest.managedFiles)) {
        $item = Get-Item -LiteralPath $managedFile.target -Force -ErrorAction SilentlyContinue
        if ($item -and $item.PSIsContainer) { throw "Cannot safely uninstall a directory at a managed file path: $($managedFile.target)" }
        if ($item -and -not (Test-InstalledFileUnchanged -ManagedFile $managedFile -InstallMode ([string]$manifest.mode))) {
            $modifiedTargets.Add([string]$managedFile.target)
        }
    }
    if ($modifiedTargets.Count -gt 0 -and -not $Force) {
        throw "Uninstall stopped because managed files changed after installation:`n$($modifiedTargets -join [Environment]::NewLine)`nRerun with -Force to back them up before removal."
    }

    $backupRecords = [System.Collections.Generic.List[object]]::new()
    foreach ($managedFile in @($manifest.managedFiles)) {
        $item = Get-Item -LiteralPath $managedFile.target -Force -ErrorAction SilentlyContinue
        if (-not $item) {
            continue
        }

        $unchanged = Test-InstalledFileUnchanged -ManagedFile $managedFile -InstallMode ([string]$manifest.mode)
        if (-not $unchanged) {
            Backup-FileBeforeForcedRemoval -Path $managedFile.target -ConfigurationHome $ConfigurationHome -Records $backupRecords
        }

        if ($PSCmdlet.ShouldProcess($managedFile.target, 'Remove installed managed file')) {
            Remove-Item -LiteralPath $managedFile.target -Force
        }
    }

    if ($SelectedPlatform -eq 'Codex') {
        Remove-ManagedHooks -ConfigurationHome $ConfigurationHome -BackupRecords $backupRecords
    }

    if ($backupRecords.Count -gt 0) {
        $backupRoot = Join-Path $ConfigurationHome ".ai-agent-memory-rules/backups/uninstall-$uninstallTimestamp"
        $backupManifestPath = Join-Path $backupRoot 'manifest.json'
        if ($PSCmdlet.ShouldProcess($backupManifestPath, 'Write uninstall backup manifest')) {
            $backupManifest = [ordered]@{
                tool = 'ai-agent-memory-rules'
                createdAt = (Get-Date).ToString('o')
                files = @($backupRecords)
            }
            [System.IO.File]::WriteAllText($backupManifestPath, (ConvertTo-PortableJson -Value $backupManifest))
        }
    }

    if ($PSCmdlet.ShouldProcess($manifestPath, 'Remove installation manifest')) {
        Remove-Item -LiteralPath $manifestPath -Force
    }

    if ($WhatIfPreference) {
        Write-Host "$SelectedPlatform uninstall preview completed. Project-local .agent-memory directories would remain unchanged."
    } else {
        Write-Host "$SelectedPlatform integration uninstalled. Project-local .agent-memory directories were not changed."
    }
}

$selectedPlatforms = if ($Platform -eq 'Both') { @('Codex', 'Claude') } else { @($Platform) }
foreach ($selectedPlatform in $selectedPlatforms) {
    $configurationHome = if ($selectedPlatform -eq 'Codex') {
        Get-CodexConfigurationHome -OverridePath $CodexHome
    } else {
        Get-ClaudeConfigurationHome -OverridePath $ClaudeHome
    }
    Uninstall-Platform -SelectedPlatform $selectedPlatform -ConfigurationHome $configurationHome
}
