[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('Codex', 'Claude', 'Both')]
    [string]$Platform = 'Codex',

    [ValidateSet('Link', 'Copy')]
    [string]$Mode = 'Link',

    [string]$CodexHome = '',
    [string]$ClaudeHome = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/MemoryRules.Common.ps1')

$repositoryRoot = Get-MemoryRulesRepositoryRoot -CallingScriptRoot $PSScriptRoot
$installationTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$managedHookMarker = '(ai-agent-memory-rules)'

function Get-ManagedFiles {
    param(
        [Parameter(Mandatory)][string]$SelectedPlatform,
        [Parameter(Mandatory)][string]$ConfigurationHome
    )

    $files = [System.Collections.Generic.List[object]]::new()
    if ($SelectedPlatform -eq 'Codex') {
        $files.Add([pscustomobject]@{
            Source = Join-Path $repositoryRoot 'codex/AGENTS.md'
            Target = Join-Path $ConfigurationHome 'AGENTS.md'
        })

        Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'codex/agents') -Filter '*.toml' -File |
            Sort-Object Name |
            ForEach-Object {
                $files.Add([pscustomobject]@{
                    Source = $_.FullName
                    Target = Join-Path $ConfigurationHome "agents/$($_.Name)"
                })
            }

        $files.Add([pscustomobject]@{
            Source = Join-Path $repositoryRoot 'codex/hooks/load-project-memory.ps1'
            Target = Join-Path $ConfigurationHome 'hooks/load-project-memory.ps1'
        })
    } else {
        $files.Add([pscustomobject]@{
            Source = Join-Path $repositoryRoot 'RULES.md'
            Target = Join-Path $ConfigurationHome 'CLAUDE.md'
        })

        Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'agents') -Filter '*.md' -File |
            Where-Object Name -ne 'README.md' |
            Sort-Object Name |
            ForEach-Object {
                $files.Add([pscustomobject]@{
                    Source = $_.FullName
                    Target = Join-Path $ConfigurationHome "agents/$($_.Name)"
                })
            }
    }

    return $files
}

function Test-ManagedFileCurrent {
    param(
        [Parameter(Mandatory)]$ManagedFile,
        [Parameter(Mandatory)][string]$InstallMode
    )

    if ($InstallMode -eq 'Link') {
        return Test-SymbolicLinkTargetsPath -LinkPath $ManagedFile.Target -ExpectedTarget $ManagedFile.Source
    }

    return Test-FileContentEqual -FirstPath $ManagedFile.Source -SecondPath $ManagedFile.Target
}

function Assert-LinkModeAvailable {
    param([Parameter(Mandatory)][string]$ConfigurationHome)

    if ($WhatIfPreference) {
        return
    }

    New-Item -ItemType Directory -Path $ConfigurationHome -Force | Out-Null
    $testIdentifier = [Guid]::NewGuid().ToString('N')
    $testSource = Join-Path ([System.IO.Path]::GetTempPath()) "memory-rules-$testIdentifier.txt"
    $testLink = Join-Path $ConfigurationHome ".memory-rules-link-test-$testIdentifier"

    try {
        [System.IO.File]::WriteAllText($testSource, 'link-test')
        New-Item -ItemType SymbolicLink -Path $testLink -Target $testSource -ErrorAction Stop | Out-Null
    } catch {
        throw "Link mode is unavailable for '$ConfigurationHome'. Enable Windows Developer Mode or rerun with -Mode Copy. $($_.Exception.Message)"
    } finally {
        if (Test-Path -LiteralPath $testLink) {
            Remove-Item -LiteralPath $testLink -Force
        }
        if (Test-Path -LiteralPath $testSource) {
            Remove-Item -LiteralPath $testSource -Force
        }
    }
}

function New-BackupContext {
    param([Parameter(Mandatory)][string]$ConfigurationHome)

    return [pscustomobject]@{
        Root = Join-Path $ConfigurationHome ".ai-agent-memory-rules/backups/$installationTimestamp"
        Records = [System.Collections.Generic.List[object]]::new()
    }
}

function Backup-ExistingFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$BackupContext
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) {
        return
    }

    $leafName = [System.IO.Path]::GetFileName($item.FullName) -replace '[^A-Za-z0-9._-]', '_'
    $safeName = "$leafName.$([Guid]::NewGuid().ToString('N').Substring(0, 8)).backup"
    $backupPath = Join-Path $BackupContext.Root $safeName
    New-DirectoryIfMissing -Path $BackupContext.Root -CommandContext $PSCmdlet

    if ($PSCmdlet.ShouldProcess($Path, "Back up to $backupPath")) {
        if ($item.LinkType -eq 'SymbolicLink') {
            [System.IO.File]::WriteAllText($backupPath + '.link-target.txt', [string](@($item.Target)[0]))
            $recordedBackup = $backupPath + '.link-target.txt'
        } else {
            Copy-Item -LiteralPath $Path -Destination $backupPath -Force
            $recordedBackup = $backupPath
        }

        $BackupContext.Records.Add([pscustomobject]@{
            OriginalPath = $item.FullName
            BackupPath = $recordedBackup
            CreatedAt = (Get-Date).ToString('o')
        })
    }
}

function Save-BackupManifest {
    param([Parameter(Mandatory)]$BackupContext)

    if ($BackupContext.Records.Count -eq 0) {
        return
    }

    $manifestPath = Join-Path $BackupContext.Root 'manifest.json'
    if ($PSCmdlet.ShouldProcess($manifestPath, 'Write backup manifest')) {
        $manifest = [ordered]@{
            tool = 'ai-agent-memory-rules'
            createdAt = (Get-Date).ToString('o')
            files = @($BackupContext.Records)
        }
        [System.IO.File]::WriteAllText($manifestPath, (ConvertTo-PortableJson -Value $manifest))
    }
}

function Assert-ManagedFileConflicts {
    param([Parameter(Mandatory)][object[]]$ManagedFiles)

    $conflicts = [System.Collections.Generic.List[string]]::new()
    foreach ($managedFile in $ManagedFiles) {
        $item = Get-Item -LiteralPath $managedFile.Target -Force -ErrorAction SilentlyContinue
        if ($item -and $item.PSIsContainer) {
            throw "Installation stopped because a directory occupies the managed file path: $($managedFile.Target)"
        }
        if ($item -and -not (Test-ManagedFileCurrent -ManagedFile $managedFile -InstallMode $Mode)) {
            $conflicts.Add($managedFile.Target)
        }
    }

    if ($conflicts.Count -gt 0 -and -not $Force) {
        $formattedConflicts = $conflicts -join [Environment]::NewLine
        throw "Installation stopped because managed targets already contain different content:`n$formattedConflicts`nRerun with -Force to create timestamped backups before replacement."
    }
}

function Assert-CodexHooksReadable {
    param([Parameter(Mandatory)][string]$ConfigurationHome)

    $hooksPath = Join-Path $ConfigurationHome 'hooks.json'
    if (-not (Test-Path -LiteralPath $hooksPath)) {
        return
    }
    if (-not (Test-Path -LiteralPath $hooksPath -PathType Leaf)) {
        throw "Installation stopped because hooks.json is not a file: $hooksPath"
    }

    $existingJson = Get-Content -LiteralPath $hooksPath -Raw
    Get-UpdatedHooksJson -ConfigurationHome $ConfigurationHome -ExistingHooksJson $existingJson | Out-Null
}

function Assert-InstallManifestSafe {
    param([Parameter(Mandatory)][string]$ConfigurationHome)

    $manifestPath = Join-Path $ConfigurationHome '.ai-agent-memory-rules/install-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        return
    }
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Installation stopped because the expected manifest path is not a file: $manifestPath"
    }

    try {
        $existingDocument = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    } catch {
        if ($Force) {
            return
        }
        throw "Installation stopped because the existing manifest is invalid. Use -Force only after reviewing it: $manifestPath"
    }

    if ($existingDocument.tool -ne 'ai-agent-memory-rules' -and -not $Force) {
        throw "Installation stopped because '$manifestPath' is not an ai-agent-memory-rules manifest."
    }
}

function Install-ManagedFile {
    param(
        [Parameter(Mandatory)]$ManagedFile,
        [Parameter(Mandatory)]$BackupContext
    )

    if (Test-ManagedFileCurrent -ManagedFile $ManagedFile -InstallMode $Mode) {
        return
    }

    $existingItem = Get-Item -LiteralPath $ManagedFile.Target -Force -ErrorAction SilentlyContinue
    if ($existingItem) {
        Backup-ExistingFile -Path $ManagedFile.Target -BackupContext $BackupContext
        if ($PSCmdlet.ShouldProcess($ManagedFile.Target, 'Remove existing managed target after backup')) {
            Remove-Item -LiteralPath $ManagedFile.Target -Force
        }
    }

    New-DirectoryIfMissing -Path (Split-Path -Parent $ManagedFile.Target) -CommandContext $PSCmdlet
    if (-not $PSCmdlet.ShouldProcess($ManagedFile.Target, "$Mode from $($ManagedFile.Source)")) {
        return
    }

    if ($Mode -eq 'Link') {
        try {
            New-Item -ItemType SymbolicLink -Path $ManagedFile.Target -Target $ManagedFile.Source -ErrorAction Stop | Out-Null
        } catch {
            throw "Could not create '$($ManagedFile.Target)'. Installation stopped. Rerun with -Mode Copy if symbolic links are unavailable. $($_.Exception.Message)"
        }
    } else {
        Copy-Item -LiteralPath $ManagedFile.Source -Destination $ManagedFile.Target -Force
    }
}

function Test-ManagedHookGroup {
    param([Parameter(Mandatory)]$Group)

    foreach ($handler in @($Group.hooks)) {
        if ([string]$handler.statusMessage -like "*$managedHookMarker*") {
            return $true
        }
    }

    return $false
}

function Get-UpdatedHooksJson {
    param(
        [Parameter(Mandatory)][string]$ConfigurationHome,
        [Parameter(Mandatory)][AllowEmptyString()][string]$ExistingHooksJson
    )

    $hooksDocument = if ([string]::IsNullOrWhiteSpace($ExistingHooksJson)) {
        [pscustomobject]@{
            description = 'User-level Codex lifecycle hooks.'
            hooks = [pscustomobject]@{}
        }
    } else {
        $ExistingHooksJson | ConvertFrom-Json
    }

    if ($hooksDocument -is [System.Array]) {
        throw 'Codex hooks.json must contain one JSON object, not a top-level array.'
    }

    if (-not $hooksDocument.PSObject.Properties['hooks']) {
        $hooksDocument | Add-Member -MemberType NoteProperty -Name hooks -Value ([pscustomobject]@{})
    }

    $fragmentPath = Join-Path $repositoryRoot 'codex/hooks.fragment.json'
    $fragment = Get-Content -LiteralPath $fragmentPath -Raw | ConvertFrom-Json
    $loaderPath = Join-Path $ConfigurationHome 'hooks/load-project-memory.ps1'
    $portableLoaderPath = $loaderPath -replace '\\', '/'
    $loaderCommand = "pwsh -NoProfile -File `"$portableLoaderPath`""
    $loaderCommandWindows = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$loaderPath`""

    foreach ($eventName in @('SessionStart', 'SubagentStart')) {
        $fragmentGroup = @($fragment.hooks.$eventName)[0]
        $fragmentHandler = @($fragmentGroup.hooks)[0]
        $fragmentHandler.command = $loaderCommand
        $fragmentHandler.commandWindows = $loaderCommandWindows

        $existingGroups = if ($hooksDocument.hooks.PSObject.Properties[$eventName]) {
            @($hooksDocument.hooks.$eventName) | Where-Object { -not (Test-ManagedHookGroup -Group $_) }
        } else {
            @()
        }
        $updatedGroups = @($existingGroups) + @($fragmentGroup)

        if ($hooksDocument.hooks.PSObject.Properties[$eventName]) {
            $hooksDocument.hooks.$eventName = $updatedGroups
        } else {
            $hooksDocument.hooks | Add-Member -MemberType NoteProperty -Name $eventName -Value $updatedGroups
        }
    }

    return ConvertTo-PortableJson -Value $hooksDocument
}

function Install-CodexHooks {
    param(
        [Parameter(Mandatory)][string]$ConfigurationHome,
        [Parameter(Mandatory)]$BackupContext
    )

    $hooksPath = Join-Path $ConfigurationHome 'hooks.json'
    $existingJson = if (Test-Path -LiteralPath $hooksPath -PathType Leaf) {
        Get-Content -LiteralPath $hooksPath -Raw
    } else {
        ''
    }
    $updatedJson = Get-UpdatedHooksJson -ConfigurationHome $ConfigurationHome -ExistingHooksJson $existingJson

    if ($existingJson -eq $updatedJson) {
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($existingJson)) {
        Backup-ExistingFile -Path $hooksPath -BackupContext $BackupContext
    }
    New-DirectoryIfMissing -Path $ConfigurationHome -CommandContext $PSCmdlet
    if ($PSCmdlet.ShouldProcess($hooksPath, 'Merge project-local Memory hooks while preserving unrelated hooks')) {
        [System.IO.File]::WriteAllText($hooksPath, $updatedJson)
    }
}

function Save-InstallManifest {
    param(
        [Parameter(Mandatory)][string]$SelectedPlatform,
        [Parameter(Mandatory)][string]$ConfigurationHome,
        [Parameter(Mandatory)][object[]]$ManagedFiles,
        [Parameter(Mandatory)]$BackupContext
    )

    $fileRecords = foreach ($managedFile in $ManagedFiles) {
        [ordered]@{
            source = $managedFile.Source
            target = $managedFile.Target
            installedHash = if (Test-Path -LiteralPath $managedFile.Target -PathType Leaf) {
                Get-FileSha256 -Path $managedFile.Target
            } else {
                ''
            }
        }
    }
    $toolDirectory = Join-Path $ConfigurationHome '.ai-agent-memory-rules'
    $manifestPath = Join-Path $toolDirectory 'install-manifest.json'
    $existingManifest = Get-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
    if ($existingManifest) {
        $sameDefinition = $false
        try {
            $existingDocument = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $sameDefinition = (
                $existingDocument.tool -eq 'ai-agent-memory-rules' -and
                $existingDocument.platform -eq $SelectedPlatform -and
                $existingDocument.mode -eq $Mode -and
                $existingDocument.repositoryRoot -eq $repositoryRoot -and
                (ConvertTo-PortableJson -Value @($existingDocument.managedFiles)) -eq (ConvertTo-PortableJson -Value @($fileRecords))
            )
        } catch {
            if (-not $Force) {
                throw
            }
        }
        if ($sameDefinition) {
            return
        }
        Backup-ExistingFile -Path $manifestPath -BackupContext $BackupContext
    }

    New-DirectoryIfMissing -Path $toolDirectory -CommandContext $PSCmdlet
    if ($PSCmdlet.ShouldProcess($manifestPath, 'Write installation manifest')) {
        $manifest = [ordered]@{
            tool = 'ai-agent-memory-rules'
            platform = $SelectedPlatform
            mode = $Mode
            repositoryRoot = $repositoryRoot
            installedAt = (Get-Date).ToString('o')
            managedFiles = @($fileRecords)
            hookMarker = $managedHookMarker
        }
        [System.IO.File]::WriteAllText($manifestPath, (ConvertTo-PortableJson -Value $manifest))
    }
}

function Install-Platform {
    param(
        [Parameter(Mandatory)][string]$SelectedPlatform,
        [Parameter(Mandatory)][string]$ConfigurationHome
    )

    $managedFiles = @(Get-ManagedFiles -SelectedPlatform $SelectedPlatform -ConfigurationHome $ConfigurationHome)
    Assert-ManagedFileConflicts -ManagedFiles $managedFiles
    Assert-InstallManifestSafe -ConfigurationHome $ConfigurationHome
    if ($SelectedPlatform -eq 'Codex') {
        Assert-CodexHooksReadable -ConfigurationHome $ConfigurationHome
    }
    if ($Mode -eq 'Link') {
        Assert-LinkModeAvailable -ConfigurationHome $ConfigurationHome
    }

    $backupContext = New-BackupContext -ConfigurationHome $ConfigurationHome
    foreach ($managedFile in $managedFiles) {
        Install-ManagedFile -ManagedFile $managedFile -BackupContext $backupContext
    }

    if ($SelectedPlatform -eq 'Codex') {
        Install-CodexHooks -ConfigurationHome $ConfigurationHome -BackupContext $backupContext
    }

    Save-InstallManifest -SelectedPlatform $SelectedPlatform -ConfigurationHome $ConfigurationHome -ManagedFiles $managedFiles -BackupContext $backupContext
    Save-BackupManifest -BackupContext $backupContext
    if ($WhatIfPreference) {
        Write-Host "$SelectedPlatform integration preview completed for '$ConfigurationHome' using $Mode mode."
    } else {
        Write-Host "$SelectedPlatform integration installed in '$ConfigurationHome' using $Mode mode."
    }
}

$selectedPlatforms = if ($Platform -eq 'Both') { @('Codex', 'Claude') } else { @($Platform) }
foreach ($selectedPlatform in $selectedPlatforms) {
    $configurationHome = if ($selectedPlatform -eq 'Codex') {
        Get-CodexConfigurationHome -OverridePath $CodexHome
    } else {
        Get-ClaudeConfigurationHome -OverridePath $ClaudeHome
    }
    Install-Platform -SelectedPlatform $selectedPlatform -ConfigurationHome $configurationHome
}

if ($Platform -in @('Codex', 'Both') -and -not $WhatIfPreference) {
    Write-Host 'Open Codex /hooks once to review and trust the installed lifecycle hooks.'
}
Write-Host 'Installation manages shared rules, agent profiles, and Codex hooks only. Initialize .agent-memory separately inside each project.'
