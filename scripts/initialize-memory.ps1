[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [string]$ProjectPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/MemoryRules.Common.ps1')

$repositoryRoot = Get-MemoryRulesRepositoryRoot -CallingScriptRoot $PSScriptRoot
$requestedProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)
if (-not (Test-Path -LiteralPath $requestedProjectPath -PathType Container)) {
    throw "Project path does not exist or is not a directory: $requestedProjectPath"
}
$resolvedProjectPath = Get-MemoryProjectRoot -WorkingDirectory $requestedProjectPath
$memoryDirectory = Join-Path $resolvedProjectPath '.agent-memory'
$templateDirectory = Join-Path $repositoryRoot 'templates/memory'

if (-not (Test-MemoryPathInsideRoot -Path $memoryDirectory -Root $resolvedProjectPath)) {
    throw "Memory destination must stay inside the selected project: $memoryDirectory"
}
Assert-MemoryPathIsNotReparsePoint -Path $memoryDirectory -Purpose 'Project Memory directory'

New-DirectoryIfMissing -Path $memoryDirectory -CommandContext $PSCmdlet
foreach ($directoryName in @('work', 'archive', 'analysis')) {
    New-DirectoryIfMissing -Path (Join-Path $memoryDirectory $directoryName) -CommandContext $PSCmdlet
}

$createdFiles = [System.Collections.Generic.List[string]]::new()
$preservedFiles = [System.Collections.Generic.List[string]]::new()
Get-ChildItem -LiteralPath $templateDirectory -Recurse -File |
    Where-Object Name -ne '.gitkeep' |
    ForEach-Object {
        $relativePath = $_.FullName.Substring($templateDirectory.Length).TrimStart('\', '/')
        $targetPath = Join-Path $memoryDirectory $relativePath
        if (-not (Test-MemoryPathInsideRoot -Path $targetPath -Root $memoryDirectory)) {
            throw "Template target escaped the project Memory directory: $targetPath"
        }
        if (Test-Path -LiteralPath $targetPath) {
            $existingItem = Get-Item -LiteralPath $targetPath -Force
            if ($existingItem.PSIsContainer) {
                throw "Cannot initialize Memory because a directory occupies a template file path: $targetPath"
            }
            Assert-MemoryPathIsNotReparsePoint -Path $targetPath -Purpose 'Project Memory file'
            $preservedFiles.Add($targetPath)
            return
        }

        New-DirectoryIfMissing -Path (Split-Path -Parent $targetPath) -CommandContext $PSCmdlet
        if ($PSCmdlet.ShouldProcess($targetPath, 'Create project Memory file from template')) {
            Copy-Item -LiteralPath $_.FullName -Destination $targetPath
            $createdFiles.Add($targetPath)
        }
    }

foreach ($directoryName in @('work', 'archive', 'analysis')) {
    $detailDirectory = Join-Path $memoryDirectory $directoryName
    $detailMarker = Join-Path $detailDirectory '.gitkeep'
    $existingMarker = Get-Item -LiteralPath $detailMarker -Force -ErrorAction SilentlyContinue
    if ($existingMarker) {
        if ($existingMarker.PSIsContainer) {
            throw "Cannot initialize Memory because a directory occupies the tracking marker path: $detailMarker"
        }
        Assert-MemoryPathIsNotReparsePoint -Path $detailMarker -Purpose 'Project Memory tracking marker'
        $preservedFiles.Add($detailMarker)
        continue
    }

    $detailDirectoryItem = Get-Item -LiteralPath $detailDirectory -Force -ErrorAction SilentlyContinue
    if ($detailDirectoryItem -and @(Get-ChildItem -LiteralPath $detailDirectory -Force).Count -gt 0) {
        continue
    }

    $templateMarker = Join-Path $templateDirectory "$directoryName/.gitkeep"
    if (-not (Test-Path -LiteralPath $templateMarker -PathType Leaf)) {
        throw "Memory template tracking marker is missing: $templateMarker"
    }
    if ($PSCmdlet.ShouldProcess($detailMarker, 'Create tracking marker for empty project Memory directory')) {
        Copy-Item -LiteralPath $templateMarker -Destination $detailMarker
        $createdFiles.Add($detailMarker)
    }
}

Write-Host "Project: $resolvedProjectPath"
Write-Host "Memory:  $memoryDirectory"
Write-Host "Created: $($createdFiles.Count) file(s)"
Write-Host "Preserved without overwrite: $($preservedFiles.Count) file(s)"

$gitMarker = Join-Path $resolvedProjectPath '.git'
if (Test-Path -LiteralPath $gitMarker) {
    & git -C $resolvedProjectPath check-ignore -q -- .agent-memory 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "'.agent-memory' is ignored by Git in '$resolvedProjectPath'. Remove the matching ignore rule if Memory should be versioned with this project."
    }
} else {
    Write-Warning "'$resolvedProjectPath' is not a Git repository. Memory was initialized locally but cannot be versioned until the directory is added to a repository."
}
