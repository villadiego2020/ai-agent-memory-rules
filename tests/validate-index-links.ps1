[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$validatorPath = Join-Path $repositoryRoot 'scripts/validate.ps1'
$initializerPath = Join-Path $repositoryRoot 'scripts/initialize-memory.ps1'
$windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ai-agent-memory-rules-index-links-$([Guid]::NewGuid().ToString('N'))"
$projectRoot = Join-Path $temporaryRoot 'Project with spaces'
$memoryRoot = Join-Path $projectRoot '.agent-memory'
$archiveIndexPath = Join-Path $memoryRoot 'project_archive.md'
$annualArchiveIndexPath = Join-Path $memoryRoot 'project_archive_2025.md'
$archiveDetailPath = Join-Path $memoryRoot 'archive/PROJ-001.md'
$secondArchiveDetailPath = Join-Path $memoryRoot 'archive/PROJ-002.md'
$outsideAnnualIndexPath = Join-Path $temporaryRoot 'outside-annual-index.md'
$outsideAnnualDirectory = Join-Path $temporaryRoot 'outside-annual-directory'

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-Validator {
    $stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) "ai-agent-memory-rules-validator-$([Guid]::NewGuid().ToString('N')).stdout.txt"
    $stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) "ai-agent-memory-rules-validator-$([Guid]::NewGuid().ToString('N')).stderr.txt"
    try {
        $argumentText = "-NoProfile -ExecutionPolicy Bypass -File `"$validatorPath`" -RepositoryRoot `"$repositoryRoot`" -ProjectPath `"$projectRoot`""
        $process = Start-Process -FilePath $windowsPowerShell -ArgumentList $argumentText `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -Wait -PassThru
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = ([System.IO.File]::ReadAllText($stdoutPath) + [System.IO.File]::ReadAllText($stderrPath))
        }
    } finally {
        if (Test-Path -LiteralPath $stdoutPath) { [System.IO.File]::Delete($stdoutPath) }
        if (Test-Path -LiteralPath $stderrPath) { [System.IO.File]::Delete($stderrPath) }
    }
}

function Set-ArchiveIndex {
    param([Parameter(Mandatory)][string]$FeatureEntry)

    $content = @"
# BUGS

(None)

# IMPROVE / OPTIMIZE

(None)

# REFACTOR

(None)

# FEATURE

$FeatureEntry

# ANALYSIS

(None)
"@
    [System.IO.File]::WriteAllText($archiveIndexPath, $content, [System.Text.UTF8Encoding]::new($false))
}

function Set-AnnualArchiveIndex {
    param([Parameter(Mandatory)][string]$Entry)

    [System.IO.File]::WriteAllText($annualArchiveIndexPath, $Entry, [System.Text.UTF8Encoding]::new($false))
}

try {
    New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
    & git -C $projectRoot init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Failed to initialize the temporary Git repository.' }
    & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $initializerPath -ProjectPath $projectRoot | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to initialize project-local Memory.' }
    [System.IO.File]::WriteAllText($archiveDetailPath, '# PROJ-001 completed work', [System.Text.UTF8Encoding]::new($false))

    Set-ArchiveIndex -FeatureEntry "- PROJ-001 summary - fixed behavior -> [detail](archive/PROJ-001.md)`n- Related context: [PROJ-001](archive/PROJ-001.md)"
    $primaryAndContextual = Invoke-Validator
    Assert-True -Condition ($primaryAndContextual.ExitCode -eq 0) -Message "One primary detail link plus a contextual cross-link should pass. Output: $($primaryAndContextual.Output)"

    Set-ArchiveIndex -FeatureEntry "- PROJ-001 first -> [detail](archive/PROJ-001.md)`n- PROJ-001 duplicate -> [detail](archive/PROJ-001.md)"
    $duplicatePrimary = Invoke-Validator
    Assert-True -Condition ($duplicatePrimary.ExitCode -ne 0) -Message 'Duplicate primary detail links should fail.'
    Assert-True -Condition ($duplicatePrimary.Output.Contains('contains 2 primary [detail] links')) -Message "Duplicate-primary failure was not specific. Output: $($duplicatePrimary.Output)"

    Set-ArchiveIndex -FeatureEntry '(None)'
    $zeroReferences = Invoke-Validator
    Assert-True -Condition ($zeroReferences.ExitCode -ne 0) -Message 'An unlinked archive detail should fail.'
    Assert-True -Condition ($zeroReferences.Output.Contains('does not index archive/PROJ-001.md')) -Message "Zero-reference failure was not specific. Output: $($zeroReferences.Output)"

    Set-ArchiveIndex -FeatureEntry '- Legacy entry: [PROJ-001](archive/PROJ-001.md)'
    $legacySingleLabel = Invoke-Validator
    Assert-True -Condition ($legacySingleLabel.ExitCode -eq 0) -Message "A legacy single non-detail label should remain accepted. Output: $($legacySingleLabel.Output)"

    Set-ArchiveIndex -FeatureEntry "- PROJ-001 -> [detail](archive/PROJ-001.md)`n- Missing target -> [detail](archive/PROJ-999.md)"
    $missingTarget = Invoke-Validator
    Assert-True -Condition ($missingTarget.ExitCode -ne 0) -Message 'A link whose target file is absent should fail.'
    Assert-True -Condition ($missingTarget.Output.Contains('links to a missing file: archive/PROJ-999.md')) -Message "Missing-target failure was not specific. Output: $($missingTarget.Output)"

    Set-ArchiveIndex -FeatureEntry '(None)'
    Set-AnnualArchiveIndex -Entry '- PROJ-001 historical entry -> [detail](archive/PROJ-001.md)'
    $splitAnnualIndex = Invoke-Validator
    Assert-True -Condition ($splitAnnualIndex.ExitCode -eq 0) -Message "A detail indexed only in a top-level annual archive index should pass. Output: $($splitAnnualIndex.Output)"

    [System.IO.File]::WriteAllText($secondArchiveDetailPath, '# PROJ-002 completed work', [System.Text.UTF8Encoding]::new($false))
    Set-ArchiveIndex -FeatureEntry "- PROJ-002 current entry -> [detail](archive/PROJ-002.md)`n- Historical context: [PROJ-001](archive/PROJ-001.md)"
    $combinedIndexes = Invoke-Validator
    Assert-True -Condition ($combinedIndexes.ExitCode -eq 0) -Message "Current and annual archive indexes should jointly own distinct details while allowing contextual cross-links. Output: $($combinedIndexes.Output)"

    Set-ArchiveIndex -FeatureEntry "- PROJ-002 current entry -> [detail](archive/PROJ-002.md)`n- PROJ-001 current duplicate -> [detail](archive/PROJ-001.md)"
    $duplicateAcrossIndexes = Invoke-Validator
    Assert-True -Condition ($duplicateAcrossIndexes.ExitCode -ne 0) -Message 'Duplicate primary detail links across current and annual indexes should fail.'
    Assert-True -Condition ($duplicateAcrossIndexes.Output.Contains('contains 2 primary [detail] links')) -Message "Cross-index duplicate failure was not specific. Output: $($duplicateAcrossIndexes.Output)"

    Set-ArchiveIndex -FeatureEntry "- PROJ-001 current entry -> [detail](archive/PROJ-001.md)`n- PROJ-002 current entry -> [detail](archive/PROJ-002.md)"
    [System.IO.File]::Delete($annualArchiveIndexPath)
    [System.IO.File]::WriteAllText($outsideAnnualIndexPath, '- outside content', [System.Text.UTF8Encoding]::new($false))
    $annualReparseCreated = $false
    $annualReparseDiagnostic = 'Annual project archive index cannot be a symbolic link or reparse point'
    try {
        New-Item -ItemType SymbolicLink -Path $annualArchiveIndexPath -Target $outsideAnnualIndexPath -ErrorAction Stop | Out-Null
        $annualReparseCreated = $true
    } catch {
        New-Item -ItemType Directory -Path $outsideAnnualDirectory -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $outsideAnnualDirectory 'outside.md'), '- outside content', [System.Text.UTF8Encoding]::new($false))
        New-Item -ItemType Junction -Path $annualArchiveIndexPath -Target $outsideAnnualDirectory -ErrorAction Stop | Out-Null
        $annualReparseCreated = $true
        $annualReparseDiagnostic = 'Annual project archive index is not a file'
    }
    if ($annualReparseCreated) {
        try {
            $annualReparse = Invoke-Validator
            Assert-True -Condition ($annualReparse.ExitCode -ne 0) -Message 'A reparse-point annual archive index should fail.'
            Assert-True -Condition ($annualReparse.Output.Contains($annualReparseDiagnostic)) -Message "Annual reparse failure was not specific. Output: $($annualReparse.Output)"
        } finally {
            $annualReparseItem = Get-Item -LiteralPath $annualArchiveIndexPath -Force -ErrorAction SilentlyContinue
            if ($annualReparseItem) {
                if ($annualReparseItem.PSIsContainer) {
                    [System.IO.Directory]::Delete($annualArchiveIndexPath)
                } else {
                    [System.IO.File]::Delete($annualArchiveIndexPath)
                }
            }
        }
    }

    Write-Host 'Validator index-link regression tests passed.'
} finally {
    $resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
    if ($resolvedTemporaryRoot.StartsWith($resolvedTemporaryBase, [System.StringComparison]::OrdinalIgnoreCase) -and
        $resolvedTemporaryRoot -ne $resolvedTemporaryBase -and (Test-Path -LiteralPath $resolvedTemporaryRoot)) {
        [System.IO.Directory]::Delete($resolvedTemporaryRoot, $true)
    }
}
