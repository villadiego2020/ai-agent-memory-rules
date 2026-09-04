[CmdletBinding()]
param(
    [ValidateRange(4096, 1048576)]
    [int]$MaximumContextBytes = 20000
)

$ErrorActionPreference = 'Stop'
$utf8WithoutByteOrderMark = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8WithoutByteOrderMark
[Console]::OutputEncoding = $utf8WithoutByteOrderMark
$OutputEncoding = $utf8WithoutByteOrderMark

function Get-HookInput {
    $rawInput = [Console]::In.ReadToEnd().TrimStart([char]0xFEFF)
    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        return [pscustomobject]@{
            cwd = (Get-Location).Path
            hook_event_name = 'SessionStart'
        }
    }

    return $rawInput | ConvertFrom-Json
}

function Get-ProjectRoot {
    param([Parameter(Mandatory)][string]$WorkingDirectory)

    $resolvedDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory)
    $currentDirectory = [System.IO.DirectoryInfo]::new($resolvedDirectory)

    while ($currentDirectory) {
        $gitMarker = Join-Path $currentDirectory.FullName '.git'
        if (Test-Path -LiteralPath $gitMarker) {
            return $currentDirectory.FullName
        }

        $currentDirectory = $currentDirectory.Parent
    }

    $pathRoot = [System.IO.Path]::GetPathRoot($resolvedDirectory)
    if ($resolvedDirectory -eq $pathRoot) {
        return $resolvedDirectory
    }

    return $resolvedDirectory.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Get-CanonicalPath {
    param([Parameter(Mandatory)][string]$Path)

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

function Test-PathInsideRoot {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root
    )

    $canonicalPath = Get-CanonicalPath -Path $Path
    $canonicalRoot = Get-CanonicalPath -Path $Root
    $comparison = if ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }
    $rootPrefix = $canonicalRoot.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    return $canonicalPath.StartsWith($rootPrefix, $comparison)
}

function Get-SafeIndexPath {
    param(
        [Parameter(Mandatory)][string]$MemoryDirectory,
        [Parameter(Mandatory)][string]$IndexName
    )

    $indexPath = Join-Path $MemoryDirectory $IndexName
    if (-not (Test-PathInsideRoot -Path $indexPath -Root $MemoryDirectory)) {
        throw "Memory index escaped the project Memory directory: $indexPath"
    }

    $item = Get-Item -LiteralPath $indexPath -Force -ErrorAction SilentlyContinue
    if (-not $item) {
        return $indexPath
    }
    if ($item.PSIsContainer) {
        throw "Memory index is not a file: $indexPath"
    }
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Memory index cannot be a symbolic link or reparse point: $indexPath"
    }

    return $item.FullName
}

function Get-TruncatedText {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][int]$MaximumBytes
    )

    $encoding = [System.Text.Encoding]::UTF8
    if ($encoding.GetByteCount($Text) -le $MaximumBytes) {
        return $Text
    }

    $marker = "`n`n[Project Memory truncated at $MaximumBytes UTF-8 bytes. Open the referenced Memory files when more detail is needed.]"
    $contentBudget = $MaximumBytes - $encoding.GetByteCount($marker)
    $candidateLength = [Math]::Min($Text.Length, $contentBudget)

    while ($candidateLength -gt 0) {
        $candidate = $Text.Substring(0, $candidateLength)
        if ($encoding.GetByteCount($candidate) -le $contentBudget) {
            return $candidate + $marker
        }

        $candidateLength--
    }

    return $marker.TrimStart()
}

function New-HookOutput {
    param(
        [Parameter(Mandatory)][string]$HookEventName,
        [Parameter(Mandatory)][string]$AdditionalContext
    )

    return [ordered]@{
        continue = $true
        hookSpecificOutput = [ordered]@{
            hookEventName = $HookEventName
            additionalContext = $AdditionalContext
        }
    }
}

function Write-HookOutput {
    param([Parameter(Mandatory)]$HookOutput)

    $json = $HookOutput | ConvertTo-Json -Depth 6 -Compress
    [Console]::Out.WriteLine($json)
}

function Get-HookEventName {
    param([Parameter(Mandatory)]$HookInput)

    if ($HookInput.hook_event_name -eq 'SubagentStart') {
        return 'SubagentStart'
    }

    return 'SessionStart'
}

try {
    $hookInput = Get-HookInput
    $workingDirectory = if ([string]::IsNullOrWhiteSpace([string]$hookInput.cwd)) {
        (Get-Location).Path
    } else {
        [string]$hookInput.cwd
    }

    $projectRoot = Get-ProjectRoot -WorkingDirectory $workingDirectory
    $memoryDirectory = Join-Path $projectRoot '.agent-memory'
    $hookEventName = Get-HookEventName -HookInput $hookInput

    if (-not (Test-Path -LiteralPath $memoryDirectory -PathType Container)) {
        $guidance = @"
Shared rules loaded. Project Memory has not been initialized for:
$projectRoot

Expected Memory directory:
$memoryDirectory

Initialize it from the ai-agent-memory-rules repository with:
pwsh -NoProfile -File scripts/initialize-memory.ps1 -ProjectPath "$projectRoot"

Continue without project Memory and do not load Memory from another project.
"@
        $output = New-HookOutput -HookEventName $hookEventName -AdditionalContext $guidance
        Write-HookOutput -HookOutput $output
        exit 0
    }

    $indexNames = @(
        'MEMORY.md',
        'user_and_feedback.md',
        'project_open_work.md',
        'project_archive.md'
    )
    $memoryItem = Get-Item -LiteralPath $memoryDirectory -Force
    if (($memoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Project Memory directory cannot be a symbolic link or reparse point: $memoryDirectory"
    }
    $sections = [System.Collections.Generic.List[string]]::new()
    $sections.Add("Project Memory for: $projectRoot")
    $sections.Add("Memory directory: $memoryDirectory")

    foreach ($indexName in $indexNames) {
        $indexPath = Get-SafeIndexPath -MemoryDirectory $memoryDirectory -IndexName $indexName
        if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
            $content = [System.IO.File]::ReadAllText($indexPath)
            $sections.Add("## $indexName`n$content")
        } else {
            $sections.Add("## $indexName`n[Missing index: $indexPath]")
        }
    }

    $additionalContext = Get-TruncatedText -Text ($sections -join "`n`n") -MaximumBytes $MaximumContextBytes
    $output = New-HookOutput -HookEventName $hookEventName -AdditionalContext $additionalContext
    Write-HookOutput -HookOutput $output
} catch {
    $eventName = 'SessionStart'
    $errorContext = "Project Memory loader could not read this project's indexes. Continue without Memory and report this error: $($_.Exception.Message)"
    $output = New-HookOutput -HookEventName $eventName -AdditionalContext $errorContext
    Write-HookOutput -HookOutput $output
    exit 0
}
