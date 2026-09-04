[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$powershellExecutable = (Get-Process -Id $PID).Path
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ai-agent-memory-rules-migrate-$([Guid]::NewGuid().ToString('N'))"
$projectRoot = Join-Path $temporaryRoot 'Target Project'
$legacyRoot = Join-Path $temporaryRoot 'Legacy Memory'

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-Migration {
    param([string[]]$ExtraArguments = @())
    $invocationId = [Guid]::NewGuid().ToString('N')
    $stdoutPath = Join-Path $temporaryRoot "migration-$invocationId.stdout.txt"
    $stderrPath = Join-Path $temporaryRoot "migration-$invocationId.stderr.txt"
    $migrationScript = Join-Path $repositoryRoot 'scripts/migrate-memory.ps1'
    $argumentText = "-NoProfile -ExecutionPolicy Bypass -File `"$migrationScript`" -LegacyMemoryPath `"$legacyRoot`" -ProjectPath `"$projectRoot`" $($ExtraArguments -join ' ')"
    $process = Start-Process -FilePath $powershellExecutable -ArgumentList $argumentText `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Migration exited with code $($process.ExitCode): $([System.IO.File]::ReadAllText($stderrPath))"
    }
    return $process.ExitCode
}

try {
    New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
    & git init --quiet $projectRoot
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the temporary Git repository.' }
    foreach ($directoryName in @('work', 'archive', 'analysis', 'unsupported')) {
        New-Item -ItemType Directory -Path (Join-Path $legacyRoot $directoryName) -Force | Out-Null
    }
    [System.IO.File]::WriteAllText((Join-Path $legacyRoot 'MEMORY.md'), 'legacy-index-marker')
    [System.IO.File]::WriteAllText((Join-Path $legacyRoot 'project_open_work.md'), 'legacy-open-marker')
    [System.IO.File]::WriteAllText((Join-Path $legacyRoot 'gotchas.md'), 'durable-gotchas-marker')
    [System.IO.File]::WriteAllText((Join-Path $legacyRoot 'workflow.md'), 'durable-workflow-marker')
    [System.IO.File]::WriteAllText((Join-Path $legacyRoot 'work/PROJ-001.md'), 'legacy-work-marker')
    New-Item -ItemType Directory -Path (Join-Path $legacyRoot 'work/nested') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $legacyRoot 'work/nested/PROJ-002.md'), 'nested-work-marker')
    [System.IO.File]::WriteAllText((Join-Path $legacyRoot 'analysis/ref-topic.md'), 'legacy-analysis-marker')
    [System.IO.File]::WriteAllText((Join-Path $legacyRoot 'unsupported-root.txt'), 'unsupported-root-marker')
    [System.IO.File]::WriteAllText((Join-Path $legacyRoot 'unsupported/private.txt'), 'unsupported-dir-marker')

    $previewExitCode = Invoke-Migration -ExtraArguments @('-WhatIf')
    Assert-True -Condition ($previewExitCode -eq 0) -Message 'Migration WhatIf exited successfully.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.agent-memory'))) -Message 'Migration WhatIf created no destination.'

    $migrationExitCode = Invoke-Migration
    Assert-True -Condition ($migrationExitCode -eq 0) -Message 'Migration exited successfully.'
    $destinationRoot = Join-Path $projectRoot '.agent-memory'
    Assert-True -Condition ((Get-Content -LiteralPath (Join-Path $destinationRoot 'MEMORY.md') -Raw) -eq 'legacy-index-marker') -Message 'Known index copied.'
    Assert-True -Condition ((Get-Content -LiteralPath (Join-Path $destinationRoot 'gotchas.md') -Raw) -eq 'durable-gotchas-marker') -Message 'Top-level gotchas Markdown copied.'
    Assert-True -Condition ((Get-Content -LiteralPath (Join-Path $destinationRoot 'workflow.md') -Raw) -eq 'durable-workflow-marker') -Message 'Top-level workflow Markdown copied.'
    Assert-True -Condition ((Get-Content -LiteralPath (Join-Path $destinationRoot 'work/PROJ-001.md') -Raw) -eq 'legacy-work-marker') -Message 'Work detail copied.'
    Assert-True -Condition ((Get-Content -LiteralPath (Join-Path $destinationRoot 'work/nested/PROJ-002.md') -Raw) -eq 'nested-work-marker') -Message 'Nested work detail copied.'
    Assert-True -Condition ((Get-Content -LiteralPath (Join-Path $destinationRoot 'analysis/ref-topic.md') -Raw) -eq 'legacy-analysis-marker') -Message 'Analysis detail copied.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $destinationRoot 'unsupported-root.txt'))) -Message 'Unsupported root file ignored.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $destinationRoot 'unsupported'))) -Message 'Unsupported directory ignored.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $legacyRoot 'MEMORY.md') -PathType Leaf) -Message 'Legacy source preserved.'

    $destinationHash = (Get-FileHash -LiteralPath (Join-Path $destinationRoot 'MEMORY.md') -Algorithm SHA256).Hash
    $secondStdout = Join-Path $temporaryRoot 'second-migration.stdout.txt'
    $secondStderr = Join-Path $temporaryRoot 'second-migration.stderr.txt'
    $migrationScript = Join-Path $repositoryRoot 'scripts/migrate-memory.ps1'
    $secondArgumentText = "-NoProfile -ExecutionPolicy Bypass -File `"$migrationScript`" -LegacyMemoryPath `"$legacyRoot`" -ProjectPath `"$projectRoot`""
    $secondProcess = Start-Process -FilePath $powershellExecutable -ArgumentList $secondArgumentText `
        -RedirectStandardOutput $secondStdout -RedirectStandardError $secondStderr -WindowStyle Hidden -Wait -PassThru
    Assert-True -Condition ($secondProcess.ExitCode -ne 0) -Message 'Second migration rejected non-empty destination.'
    Assert-True -Condition ([System.IO.File]::ReadAllText($secondStderr) -like '*destination already exists and is not empty*') -Message 'Second migration failed for the intended no-overwrite reason.'
    Assert-True -Condition ((Get-FileHash -LiteralPath (Join-Path $destinationRoot 'MEMORY.md') -Algorithm SHA256).Hash -eq $destinationHash) -Message 'Rejected migration did not overwrite Memory.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $legacyRoot 'MEMORY.md') -PathType Leaf) -Message 'Rejected migration did not delete source.'

    Write-Host 'Memory migration tests passed.'
} finally {
    $resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
    if ($resolvedTemporaryRoot.StartsWith($resolvedTemporaryBase, [System.StringComparison]::OrdinalIgnoreCase) -and
        $resolvedTemporaryRoot -ne $resolvedTemporaryBase -and (Test-Path -LiteralPath $resolvedTemporaryRoot)) {
        [System.IO.Directory]::Delete($resolvedTemporaryRoot, $true)
    }
}
