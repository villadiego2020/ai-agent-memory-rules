[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [string]$LegacyMemoryPath,

    [string]$ProjectPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/MemoryRules.Common.ps1')

$legacyRoot = Get-MemoryCanonicalPath -Path $LegacyMemoryPath
if (-not (Test-Path -LiteralPath $legacyRoot -PathType Container)) {
    throw "Legacy Memory path does not exist or is not a directory: $legacyRoot"
}
Assert-MemoryPathIsNotReparsePoint -Path $legacyRoot -Purpose 'Legacy Memory directory'

$requestedProjectPath = Get-MemoryCanonicalPath -Path $ProjectPath
if (-not (Test-Path -LiteralPath $requestedProjectPath -PathType Container)) {
    throw "Project path does not exist or is not a directory: $requestedProjectPath"
}
$projectRoot = Get-MemoryProjectRoot -WorkingDirectory $requestedProjectPath
$destinationRoot = Get-MemoryCanonicalPath -Path (Join-Path $projectRoot '.agent-memory')
if (-not (Test-MemoryPathInsideRoot -Path $destinationRoot -Root $projectRoot)) {
    throw "Migration destination must stay inside the selected project: $destinationRoot"
}

$pathComparison = if ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    [System.StringComparison]::OrdinalIgnoreCase
} else {
    [System.StringComparison]::Ordinal
}
if ([string]::Equals($legacyRoot, $destinationRoot, $pathComparison)) {
    throw 'Legacy Memory source and project-local destination must be different directories.'
}

$existingDestination = Get-Item -LiteralPath $destinationRoot -Force -ErrorAction SilentlyContinue
if ($existingDestination) {
    if (-not $existingDestination.PSIsContainer) {
        throw "Migration destination exists and is not a directory: $destinationRoot"
    }
    Assert-MemoryPathIsNotReparsePoint -Path $destinationRoot -Purpose 'Project Memory destination'
    if (@(Get-ChildItem -LiteralPath $destinationRoot -Force).Count -gt 0) {
        throw "Migration destination already exists and is not empty: $destinationRoot"
    }
}

$copyPlan = [System.Collections.Generic.List[object]]::new()
foreach ($indexName in @('MEMORY.md', 'user_and_feedback.md', 'project_open_work.md', 'project_archive.md')) {
    $sourcePath = Join-Path $legacyRoot $indexName
    $sourceItem = Get-Item -LiteralPath $sourcePath -Force -ErrorAction SilentlyContinue
    if (-not $sourceItem) {
        continue
    }
    if ($sourceItem.PSIsContainer) {
        throw "Legacy Memory index is not a file: $sourcePath"
    }
    Assert-MemoryPathIsNotReparsePoint -Path $sourcePath -Purpose 'Legacy Memory index'
    $copyPlan.Add([pscustomobject]@{
        Source = $sourceItem.FullName
        Target = Join-Path $destinationRoot $indexName
    })
}

foreach ($directoryName in @('work', 'archive', 'analysis')) {
    $sourceDirectory = Join-Path $legacyRoot $directoryName
    $sourceDirectoryItem = Get-Item -LiteralPath $sourceDirectory -Force -ErrorAction SilentlyContinue
    if (-not $sourceDirectoryItem) {
        continue
    }
    if (-not $sourceDirectoryItem.PSIsContainer) {
        throw "Legacy Memory detail path is not a directory: $sourceDirectory"
    }
    Assert-MemoryPathIsNotReparsePoint -Path $sourceDirectory -Purpose 'Legacy Memory detail directory'

    foreach ($sourceItem in @(Get-ChildItem -LiteralPath $sourceDirectory -Recurse -Force)) {
        if (($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Legacy Memory cannot contain symbolic links or reparse points: $($sourceItem.FullName)"
        }
        if ($sourceItem.PSIsContainer) {
            continue
        }
        if (-not (Test-MemoryPathInsideRoot -Path $sourceItem.FullName -Root $legacyRoot)) {
            throw "Legacy Memory entry escaped its source directory: $($sourceItem.FullName)"
        }

        $relativePath = $sourceItem.FullName.Substring($legacyRoot.Length).TrimStart('\', '/')
        $targetPath = Join-Path $destinationRoot $relativePath
        if (-not (Test-MemoryPathInsideRoot -Path $targetPath -Root $destinationRoot)) {
            throw "Migration target escaped the project Memory directory: $targetPath"
        }
        $copyPlan.Add([pscustomobject]@{
            Source = $sourceItem.FullName
            Target = $targetPath
        })
    }
}

if ($copyPlan.Count -eq 0) {
    throw "Legacy Memory does not contain any supported index or detail files: $legacyRoot"
}

New-DirectoryIfMissing -Path $destinationRoot -CommandContext $PSCmdlet
foreach ($directoryName in @('work', 'archive', 'analysis')) {
    New-DirectoryIfMissing -Path (Join-Path $destinationRoot $directoryName) -CommandContext $PSCmdlet
}
foreach ($copyEntry in $copyPlan) {
    New-DirectoryIfMissing -Path (Split-Path -Parent $copyEntry.Target) -CommandContext $PSCmdlet
    if ($PSCmdlet.ShouldProcess($copyEntry.Target, "Copy project Memory from $($copyEntry.Source)")) {
        Copy-Item -LiteralPath $copyEntry.Source -Destination $copyEntry.Target
    }
}

Write-Host "Legacy source preserved: $legacyRoot"
Write-Host "Project Memory destination: $destinationRoot"
Write-Host "Copied: $($copyPlan.Count) file(s)"
if ($WhatIfPreference) {
    Write-Host 'Migration preview completed; no files were copied.'
} else {
    Write-Host 'Migration completed. Review and commit .agent-memory in the project repository when ready.'
}

if (Test-Path -LiteralPath (Join-Path $projectRoot '.git')) {
    & git -C $projectRoot check-ignore -q -- .agent-memory 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "'.agent-memory' is ignored by Git. Remove the matching ignore rule before committing the migrated Memory."
    }
}
