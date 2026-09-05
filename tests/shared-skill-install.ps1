[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "shared-skill-$([Guid]::NewGuid().ToString('N'))"
$runtime = (Get-Process -Id $PID).Path
$configurationRoot = Join-Path $temporaryRoot 'codex'
$skillsRoot = Join-Path $temporaryRoot 'discovered-skills'
$claudeRoot = Join-Path $temporaryRoot 'claude'
$arguments = @('-Platform', 'Both', '-CodexHome', $configurationRoot, '-CodexSkillsHome', $skillsRoot, '-ClaudeHome', $claudeRoot)
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Invoke-Script([string]$Name, [string[]]$Extra, [bool]$ShouldFail = $false) {
    $ErrorActionPreference = 'Continue'
    $scriptPath = Join-Path $repositoryRoot "scripts/$Name.ps1"
    $quotedArguments = @($arguments + $Extra | Where-Object { $_ -ne '-Confirm:$false' } | ForEach-Object {
        if ($_ -match '^-[A-Za-z]+$') { $_ } else { "'" + $_.Replace("'", "''") + "'" }
    }) -join ' '
    $commandText = '$ConfirmPreference = ''None''; & ''' + $scriptPath.Replace("'", "''") + "' " + $quotedArguments
    $output = & $runtime -NoProfile -ExecutionPolicy Bypass -Command $commandText 2>&1
    $ErrorActionPreference = 'Stop'
    if (($LASTEXITCODE -ne 0) -ne $ShouldFail) { throw "$Name unexpected exit: $LASTEXITCODE`n$output" }
}
try {
    Invoke-Script 'install' @('-Mode', 'Copy', '-WhatIf')
    Assert-True (-not (Test-Path -LiteralPath $temporaryRoot)) 'WhatIf created directories.'
    New-Item -ItemType Directory -Path (Join-Path $skillsRoot 'game-workflow') -Force | Out-Null
    $customFile = Join-Path $skillsRoot 'game-workflow/custom.md'
    [IO.File]::WriteAllText($customFile, 'custom preserved')
    Invoke-Script 'install' @('-Mode', 'Copy')
    $manifestPath = Join-Path $configurationRoot '.ai-agent-memory-rules/install-manifest.json'
    $before = [IO.File]::ReadAllText($manifestPath)
    Invoke-Script 'install' @('-Mode', 'Copy')
    Assert-True ($before -eq [IO.File]::ReadAllText($manifestPath)) 'Idempotent install changed manifest.'
    $manifest = $before | ConvertFrom-Json
    $skillRecords = @($manifest.managedFiles | Where-Object target -like "$skillsRoot*")
    Assert-True ($skillRecords.Count -ge 6) 'Recursive references are missing from manifest.'
    Assert-True ($customFile -notin @($manifest.managedFiles.target)) 'Custom file became owned.'
    $ownedFile = Join-Path $skillsRoot 'game-workflow/SKILL.md'
    [IO.File]::AppendAllText($ownedFile, "`ncustom modification")
    Invoke-Script 'install' @('-Mode', 'Copy') $true
    Invoke-Script 'uninstall' @('-Confirm:$false') $true
    Assert-True ([IO.File]::ReadAllText($ownedFile).Contains('custom modification')) 'Modified file was lost.'
    Invoke-Script 'install' @('-Mode', 'Copy', '-Force')
    $backupFiles = @(Get-ChildItem -LiteralPath (Join-Path $configurationRoot '.ai-agent-memory-rules/backups') -Recurse -File)
    Assert-True (@($backupFiles | Where-Object { [IO.File]::ReadAllText($_.FullName).Contains('custom modification') }).Count -gt 0) 'Force did not back up modified skill.'
    Invoke-Script 'uninstall' @('-WhatIf', '-Confirm:$false')
    Assert-True (Test-Path -LiteralPath $ownedFile) 'Uninstall WhatIf removed owned skill.'
    # A forged custom path inside the skill folder must still fail the exact allowlist.
    $validManifest = [IO.File]::ReadAllText($manifestPath)
    $tampered = $validManifest | ConvertFrom-Json
    $tampered.managedFiles[0].target = $customFile
    [IO.File]::WriteAllText($manifestPath, ($tampered | ConvertTo-Json -Depth 20))
    Invoke-Script 'uninstall' @('-Force', '-Confirm:$false') $true
    Assert-True (Test-Path -LiteralPath $customFile) 'Tampered manifest removed custom file.'
    [IO.File]::WriteAllText($manifestPath, $validManifest)
    Invoke-Script 'uninstall' @('-Confirm:$false')
    Assert-True (-not (Test-Path -LiteralPath $ownedFile)) 'Owned skill survived uninstall.'
    Assert-True ([IO.File]::ReadAllText($customFile) -eq 'custom preserved') 'Custom skill file changed.'
    # Legacy manifests do not claim skill files and must not remove them.
    Invoke-Script 'install' @('-Mode', 'Copy')
    foreach ($config in @($configurationRoot, $claudeRoot)) {
        $legacyPath = Join-Path $config '.ai-agent-memory-rules/install-manifest.json'
        $legacy = Get-Content -LiteralPath $legacyPath -Raw | ConvertFrom-Json
        $legacy.managedFiles = @($legacy.managedFiles | Where-Object { $_.target -notmatch '[\\/]game-workflow[\\/]' })
        [IO.File]::WriteAllText($legacyPath, ($legacy | ConvertTo-Json -Depth 20))
    }
    Invoke-Script 'uninstall' @('-Confirm:$false')
    Assert-True (Test-Path -LiteralPath $ownedFile) 'Legacy uninstall removed unowned skill.'
    # Probe symlink capability separately, then test actual Link install/uninstall.
    $probeTarget = Join-Path $temporaryRoot 'probe.txt'
    $probeLink = Join-Path $temporaryRoot 'probe.link'
    [IO.File]::WriteAllText($probeTarget, 'probe')
    $linkAvailable = $true
    try { New-Item -ItemType SymbolicLink -Path $probeLink -Target $probeTarget -ErrorAction Stop | Out-Null } catch { $linkAvailable = $false }
    if ($linkAvailable) {
        Remove-Item -LiteralPath $probeLink -Force
        Invoke-Script 'install' @('-Mode', 'Link', '-Force')
        Assert-True ((Get-Item -LiteralPath $ownedFile).LinkType -eq 'SymbolicLink') 'Link install copied skill.'
        $linkManifest = [IO.File]::ReadAllText($manifestPath)
        Invoke-Script 'install' @('-Mode', 'Link')
        Assert-True ($linkManifest -eq [IO.File]::ReadAllText($manifestPath)) 'Link reinstall changed manifest.'
        Invoke-Script 'uninstall' @('-Confirm:$false')
        Assert-True (Test-Path -LiteralPath (Join-Path $repositoryRoot 'skills/game-workflow/SKILL.md')) 'Link uninstall removed source.'
        Assert-True (Test-Path -LiteralPath $customFile) 'Link uninstall removed custom file.'
        Write-Host 'Shared skill Link lifecycle passed.'
    } else { Write-Host 'Shared skill Link lifecycle NOT RUN: symbolic link capability unavailable.' }
    Write-Host 'Shared skill Copy lifecycle, custom preservation, backups, WhatIf, allowlist and legacy tests passed.'
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        $resolvedTemporary = [IO.Path]::GetFullPath($temporaryRoot)
        if (-not $resolvedTemporary.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup path.' }
        Get-ChildItem -LiteralPath $resolvedTemporary -Recurse -Force | Sort-Object { $_.FullName.Length } -Descending | Remove-Item -Force
        Remove-Item -LiteralPath $resolvedTemporary -Force
    }
}
