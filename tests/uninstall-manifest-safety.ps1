[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$powershellExecutable = (Get-Process -Id $PID).Path
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ai-agent-memory-rules-uninstall-$([Guid]::NewGuid().ToString('N'))"
$codexHome = Join-Path $temporaryRoot 'codex-home'
$toolDirectory = Join-Path $codexHome '.ai-agent-memory-rules'
$outsideVictim = Join-Path $temporaryRoot 'outside-manifest-victim.txt'

try {
    New-Item -ItemType Directory -Path $toolDirectory -Force | Out-Null
    [System.IO.File]::WriteAllText($outsideVictim, 'must survive a tampered manifest')
    $tamperedManifest = [ordered]@{
        tool = 'ai-agent-memory-rules'
        platform = 'Codex'
        mode = 'Copy'
        managedFiles = @(
            [ordered]@{
                source = (Join-Path $repositoryRoot 'codex/AGENTS.md')
                target = $outsideVictim
                installedHash = (Get-FileHash -LiteralPath $outsideVictim -Algorithm SHA256).Hash
            }
        )
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $toolDirectory 'install-manifest.json'),
        (($tamperedManifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
    )

    $stdoutPath = Join-Path $temporaryRoot 'uninstall.stdout.txt'
    $stderrPath = Join-Path $temporaryRoot 'uninstall.stderr.txt'
    $process = Start-Process -FilePath $powershellExecutable -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $repositoryRoot 'scripts/uninstall.ps1'),
        '-Platform', 'Codex',
        '-CodexHome', $codexHome
    ) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -Wait -PassThru

    $stderr = [System.IO.File]::ReadAllText($stderrPath)
    if ($process.ExitCode -eq 0) {
        throw 'Assertion failed: uninstaller accepted a manifest target outside the selected configuration home.'
    }
    if (-not (Test-Path -LiteralPath $outsideVictim -PathType Leaf)) {
        throw 'Assertion failed: uninstaller deleted a file outside the selected configuration home.'
    }
    if ($stderr -notlike '*manifest target is outside the selected configuration home*') {
        throw "Assertion failed: uninstaller failed for the wrong reason instead of rejecting the escaped target. Error: $stderr"
    }

    Write-Host 'Uninstall manifest safety test passed.'
} finally {
    $resolvedTemporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
    if (
        $resolvedTemporaryRoot.StartsWith($resolvedTemporaryBase, [System.StringComparison]::OrdinalIgnoreCase) -and
        $resolvedTemporaryRoot -ne $resolvedTemporaryBase -and
        (Test-Path -LiteralPath $resolvedTemporaryRoot)
    ) {
        [System.IO.Directory]::Delete($resolvedTemporaryRoot, $true)
    }
}
