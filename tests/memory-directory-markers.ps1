[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$powershellExecutable = (Get-Process -Id $PID).Path
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ai-agent-memory-rules-markers-$([Guid]::NewGuid().ToString('N'))"

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-Initializer {
    param(
        [Parameter(Mandatory)][string]$ProjectPath,
        [string[]]$ExtraArguments = @()
    )

    $initializerPath = Join-Path $repositoryRoot 'scripts/initialize-memory.ps1'
    & $powershellExecutable -NoProfile -ExecutionPolicy Bypass -File $initializerPath -ProjectPath $ProjectPath @ExtraArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Memory initializer exited with code $LASTEXITCODE."
    }
}

try {
    $initializedProjectRoot = Join-Path $temporaryRoot 'Initialized Project'
    New-Item -ItemType Directory -Path $initializedProjectRoot -Force | Out-Null
    & git init --quiet $initializedProjectRoot
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the temporary Git repository.' }

    Invoke-Initializer -ProjectPath $initializedProjectRoot
    foreach ($directoryName in @('work', 'archive', 'analysis')) {
        $markerPath = Join-Path $initializedProjectRoot ".agent-memory/$directoryName/.gitkeep"
        Assert-True -Condition (Test-Path -LiteralPath $markerPath -PathType Leaf) -Message "Initializer created the $directoryName tracking marker."
    }

    & git -C $initializedProjectRoot add -- .agent-memory
    if ($LASTEXITCODE -ne 0) { throw 'Could not stage initialized Memory in the temporary Git repository.' }
    & git -C $initializedProjectRoot -c 'user.name=Memory Rules Test' -c 'user.email=memory-rules@example.invalid' commit --quiet -m 'Test initialized Memory visibility'
    if ($LASTEXITCODE -ne 0) { throw 'Could not commit initialized Memory in the temporary Git repository.' }
    $clonedProjectRoot = Join-Path $temporaryRoot 'Fresh Initializer Clone'
    & git clone --quiet $initializedProjectRoot $clonedProjectRoot
    if ($LASTEXITCODE -ne 0) { throw 'Could not clone the initialized temporary Git repository.' }
    foreach ($directoryName in @('work', 'archive', 'analysis')) {
        $clonedMarkerPath = Join-Path $clonedProjectRoot ".agent-memory/$directoryName/.gitkeep"
        Assert-True -Condition (Test-Path -LiteralPath $clonedMarkerPath -PathType Leaf) -Message "Fresh clone retained the $directoryName detail directory."
    }

    $projectWithExistingDetails = Join-Path $temporaryRoot 'Project With Existing Details'
    foreach ($directoryName in @('work', 'archive', 'analysis')) {
        $detailDirectory = Join-Path $projectWithExistingDetails ".agent-memory/$directoryName"
        New-Item -ItemType Directory -Path $detailDirectory -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $detailDirectory 'existing.md'), "preserve-existing-$directoryName")
    }
    Invoke-Initializer -ProjectPath $projectWithExistingDetails
    foreach ($directoryName in @('work', 'archive', 'analysis')) {
        $detailDirectory = Join-Path $projectWithExistingDetails ".agent-memory/$directoryName"
        Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $detailDirectory '.gitkeep'))) -Message "Initializer did not add a marker beside existing $directoryName content."
        Assert-True -Condition ((Get-Content -LiteralPath (Join-Path $detailDirectory 'existing.md') -Raw) -eq "preserve-existing-$directoryName") -Message "Initializer preserved existing $directoryName content."
    }

    $previewProjectRoot = Join-Path $temporaryRoot 'WhatIf Project'
    New-Item -ItemType Directory -Path $previewProjectRoot -Force | Out-Null
    Invoke-Initializer -ProjectPath $previewProjectRoot -ExtraArguments @('-WhatIf')
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $previewProjectRoot '.agent-memory'))) -Message 'Initializer WhatIf remained side-effect free.'

    Write-Host 'Memory directory marker tests passed.'
} finally {
    $resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
    if ($resolvedTemporaryRoot.StartsWith($resolvedTemporaryBase, [System.StringComparison]::OrdinalIgnoreCase) -and
        $resolvedTemporaryRoot -ne $resolvedTemporaryBase -and (Test-Path -LiteralPath $resolvedTemporaryRoot)) {
        Get-ChildItem -LiteralPath $resolvedTemporaryRoot -Recurse -Force | ForEach-Object {
            $_.Attributes = [System.IO.FileAttributes]::Normal
        }
        [System.IO.Directory]::Delete($resolvedTemporaryRoot, $true)
    }
}
