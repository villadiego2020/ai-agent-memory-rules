[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ai-agent-memory-rules-winps-whatif-$([Guid]::NewGuid().ToString('N'))"
$codexHome = Join-Path $temporaryRoot 'codex home'
$claudeHome = Join-Path $temporaryRoot 'claude home'

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

$windowsPowerShellVersion = (& $windowsPowerShell -NoProfile -Command '$PSVersionTable.PSVersion.ToString()').Trim()
Assert-True -Condition ($windowsPowerShellVersion -like '5.1.*') -Message "Expected Windows PowerShell 5.1, found $windowsPowerShellVersion."

function Get-FileSha256Independent {
    param([Parameter(Mandatory)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $algorithm = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([System.BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '')
        } finally {
            $algorithm.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Get-TreeSnapshot {
    param([Parameter(Mandatory)][string]$Root)

    $canonicalRoot = [System.IO.Path]::GetFullPath($Root)
    $records = foreach ($item in @(Get-ChildItem -LiteralPath $canonicalRoot -Force -Recurse | Sort-Object FullName)) {
        $relativePath = $item.FullName.Substring($canonicalRoot.Length).TrimStart('\', '/')
        [ordered]@{
            path = $relativePath
            type = if ($item.PSIsContainer) { 'directory' } else { 'file' }
            hash = if ($item.PSIsContainer) { '' } else { Get-FileSha256Independent -Path $item.FullName }
        }
    }
    return ($records | ConvertTo-Json -Depth 4 -Compress)
}

try {
    New-Item -ItemType Directory -Path (Join-Path $codexHome 'agents') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $claudeHome 'agents') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $codexHome 'AGENTS.md'), 'conflicting Codex rules')
    [System.IO.File]::WriteAllText((Join-Path $codexHome 'agents/web-expert.toml'), 'conflicting Codex agent')
    [System.IO.File]::WriteAllText((Join-Path $codexHome 'agents/custom-local.toml'), 'unrelated Codex agent')
    [System.IO.File]::WriteAllText((Join-Path $claudeHome 'CLAUDE.md'), 'conflicting Claude rules')
    [System.IO.File]::WriteAllText((Join-Path $claudeHome 'agents/web-expert.md'), 'conflicting Claude agent')
    [System.IO.File]::WriteAllText((Join-Path $claudeHome 'agents/custom-local.md'), 'unrelated Claude agent')
    $hooks = [ordered]@{
        hooks = [ordered]@{
            Stop = @([ordered]@{
                hooks = @([ordered]@{ type = 'command'; command = 'echo existing'; statusMessage = 'Existing hook' })
            })
        }
    }
    [System.IO.File]::WriteAllText((Join-Path $codexHome 'hooks.json'), (($hooks | ConvertTo-Json -Depth 8) + [Environment]::NewLine))

    $snapshotBefore = Get-TreeSnapshot -Root $temporaryRoot
    $stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) "ai-agent-memory-rules-winps-$([Guid]::NewGuid().ToString('N')).stdout.txt"
    $stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) "ai-agent-memory-rules-winps-$([Guid]::NewGuid().ToString('N')).stderr.txt"
    try {
        $installScript = Join-Path $repositoryRoot 'scripts/install.ps1'
        $argumentText = "-NoProfile -ExecutionPolicy Bypass -File `"$installScript`" -Platform Both -Mode Copy -Force -WhatIf -CodexHome `"$codexHome`" -ClaudeHome `"$claudeHome`" -CodexSkillsHome `"$codexHome/skills`""
        $process = Start-Process -FilePath $windowsPowerShell -ArgumentList $argumentText `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -Wait -PassThru
        $stdout = [System.IO.File]::ReadAllText($stdoutPath)
        $stderr = [System.IO.File]::ReadAllText($stderrPath)

        Assert-True -Condition ($process.ExitCode -eq 0) -Message "Windows PowerShell WhatIf exited with code $($process.ExitCode). Error: $stderr"
        Assert-True -Condition ($stdout -like '*Codex integration preview completed*') -Message 'Codex WhatIf preview completed.'
        Assert-True -Condition ($stdout -like '*Claude integration preview completed*') -Message 'Claude WhatIf preview completed.'
        Assert-True -Condition ([string]::IsNullOrWhiteSpace($stderr)) -Message "Windows PowerShell WhatIf wrote an unexpected error: $stderr"
    } finally {
        if (Test-Path -LiteralPath $stdoutPath) { [System.IO.File]::Delete($stdoutPath) }
        if (Test-Path -LiteralPath $stderrPath) { [System.IO.File]::Delete($stderrPath) }
    }

    $snapshotAfter = Get-TreeSnapshot -Root $temporaryRoot
    Assert-True -Condition ($snapshotAfter -ceq $snapshotBefore) -Message 'Windows PowerShell WhatIf changed the temporary home trees or file hashes.'

    Write-Host 'Windows PowerShell install WhatIf regression passed.'
} finally {
    $resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
    if ($resolvedTemporaryRoot.StartsWith($resolvedTemporaryBase, [System.StringComparison]::OrdinalIgnoreCase) -and
        $resolvedTemporaryRoot -ne $resolvedTemporaryBase -and (Test-Path -LiteralPath $resolvedTemporaryRoot)) {
        [System.IO.Directory]::Delete($resolvedTemporaryRoot, $true)
    }
}
