[CmdletBinding()]
param(
    [Parameter(Mandatory, Position=0)][ValidateSet('init','new','show','list','plan','claim','handoff','release','review','qa','complete','validate','migrate','worktree','recover')][string]$Action,
    [string]$ProjectPath=(Get-Location).Path,
    [string]$Id='', [string]$Title='', [string]$Goal='', [string[]]$Acceptance=@(),
    [ValidateSet('low','medium','high')][string]$Risk='medium',
    [ValidateSet('feature','bugfix','refactor','analysis','performance','prototype')][string]$Kind='feature',
    [ValidateSet('generic','unity','web','app','tooling')][string]$Stack='generic',
    [ValidateSet('codex','claude')][string]$Runtime='codex',
    [string]$Owner='', [string]$NextOwner='', [string[]]$OwnedFile=@(),
    [string]$Summary='', [string[]]$ChangedFile=@(), [string[]]$Decision=@(), [string[]]$Evidence=@(), [string[]]$Limitation=@(),
    [string]$Reason='', [string]$QaSummary='', [string]$Reviewer='',
    [string]$HardProblem='',
    [ValidateSet('pass','fail')][string]$Verdict='pass',
    [string]$CheckFile='', [string]$ReadinessFile='', [string]$NoChecksReason='', [switch]$RequireRuntimeEvidence,
    [ValidateRange(1,7200)][int]$TimeoutSeconds=1200,
    [string]$Branch='', [switch]$Json
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lib/Coordination.Common.ps1')
. (Join-Path $PSScriptRoot 'lib/Invoke-AgentCli.ps1')
$context=Get-CoordinationContext $ProjectPath
$hardProblemProvided=$PSBoundParameters.ContainsKey('HardProblem')

function Assert-TaskSummary {
    if ([string]::IsNullOrWhiteSpace($Summary) -or $Evidence.Count -eq 0 -or @($Evidence | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { throw "$Action requires -Summary and at least one non-empty -Evidence item." }
}

if ($Action -eq 'init') {
    Assert-CoordinationPath $context.board
    Assert-CoordinationPath $context.tasks
    $null=New-Item -ItemType Directory -Path $context.tasks -Force
    Invoke-CoordinationLock $context {
        foreach ($directory in @('artifacts','worktrees')) { $path=Join-Path $context.board $directory; Assert-CoordinationPath $path; $null=New-Item -ItemType Directory -Path $path -Force }
        $readme=Join-Path $context.board 'README.md'
        Assert-CoordinationPath $readme
        if (-not (Test-Path -LiteralPath $readme)) { [IO.File]::WriteAllText($readme, "Shared execution board for every worktree of this repository. Load the installed agent-coordination skill. Task identities use runtime:session. Durable facts remain in each branch's .agent-memory. Artifacts are local and may contain private output; share selected evidence deliberately.`n", $script:CoordinationEncoding) }
        $ignore=Join-Path $context.board '.gitignore'
        Assert-CoordinationPath $readme; Assert-CoordinationPath $ignore
        $existing=if (Test-Path -LiteralPath $ignore) {[IO.File]::ReadAllText($ignore)} else {''}
        $missing=@('.lock','*.tmp','*.bak','artifacts/','worktrees/' | Where-Object { $_ -notin @($existing -split '\r?\n') })
        if ($missing.Count) { [IO.File]::WriteAllText($ignore,$existing.TrimEnd("`r","`n")+"`n"+($missing -join "`n")+"`n",$script:CoordinationEncoding) }
    }
    Write-Output "Initialized common board: $($context.board)"
    return
}

if ($Action -eq 'new') {
    if ([string]::IsNullOrWhiteSpace($Title) -or [string]::IsNullOrWhiteSpace($Goal) -or $Acceptance.Count -eq 0) { throw 'new requires -Title, -Goal and -Acceptance.' }
    Assert-CoordinationIdentity $Owner
    Invoke-CoordinationLock $context {
        $numbers=@(Get-ChildItem -LiteralPath $context.tasks -Filter 'T-*.json' -File | ForEach-Object { if ($_.BaseName -cmatch '^T-([0-9]{6,12})$') { [long]$Matches[1] } })
        $next=1L
        if ($numbers.Count) { $next=[long](($numbers | Measure-Object -Maximum).Maximum)+1L }
        $taskId='T-{0:D6}' -f $next
        $scopes=@($OwnedFile | ForEach-Object { ConvertTo-CoordinationScope $_ } | Sort-Object -Unique)
        if ($Kind -ne 'analysis' -and -not $scopes.Count) { $scopes=@('.') }
        if ($Kind -eq 'analysis' -and $scopes.Count) { throw 'Read-only analysis tasks cannot reserve write ownership.' }
        foreach ($scope in $scopes) { Assert-CoordinationPath (Join-Path $context.root $scope) }
        $now=[DateTime]::UtcNow.ToString('o')
        $task=[pscustomobject][ordered]@{ schemaVersion=2; id=$taskId; title=$Title; goal=$Goal; acceptance=@($Acceptance); risk=$Risk; kind=$Kind; playbook=$Kind; stack=$Stack; runtime=(Get-CoordinationActorRuntime $Owner $Runtime); status='claimed'; stage='plan'; owner=$Owner; pendingOwner=$null; worktree=$context.root; ownedFiles=@($scopes); implementationParticipants=@(); handoffs=@(); artifacts=@(); runs=@(); plan=$null; review=$null; qa=$null; execution=$null; createdAt=$now; updatedAt=$now }
        Set-CoordinationProperty $task 'hardProblem' $HardProblem.Trim()
        if ($context.isGit) {
            $base=Invoke-CoordinationGit $context.root @('rev-parse','--verify','HEAD') -AllowFailure
            Set-CoordinationProperty $task 'baseRevision' $(if ($base.exitCode -eq 0) {$base.output.Trim()} else {$null})
        }
        Assert-CoordinationOwnership $context $task
        Save-CoordinationTask $context $task
        if ($Json) { $task | ConvertTo-Json -Depth 40 } else { Write-Output "Created $taskId ($Kind/$Risk, owner $Owner)." }
    }
    return
}

if ($Action -eq 'list') {
    Invoke-CoordinationLock $context {
        $records=@(Get-ChildItem -LiteralPath $context.tasks -Filter 'T-*.json' -File | Sort-Object Name | ForEach-Object { Read-CoordinationTask $context $_.BaseName -AllowLegacy })
        if ($Json) { ConvertTo-Json -InputObject @($records) -Depth 40 }
        else { $records | Select-Object id,status,owner,title | Format-Table -AutoSize }
    }
    return
}

if ($Action -eq 'validate') {
    Invoke-CoordinationLock $context {
        $files=@(Get-ChildItem -LiteralPath $context.tasks -File -Filter '*.json')
        foreach ($file in $files) {
            $task=Read-CoordinationTask $context $file.BaseName -AllowLegacy
            if ($task.schemaVersion -eq 2) { Assert-CoordinationOwnership $context $task; $null=Get-CoordinationTaskContext $context $task }
        }
        Write-Output "Validated $($files.Count) task record(s). Legacy records require explicit migration before mutation."
    }
    return
}

if (-not $Id) { throw "$Action requires -Id." }
if ($Action -eq 'show') { Invoke-CoordinationLock $context { Read-CoordinationTask $context $Id -AllowLegacy | ConvertTo-Json -Depth 40 }; return }

if ($Action -eq 'qa') {
    $runId=[Guid]::NewGuid().ToString('N')
    $observed=Invoke-CoordinationLock $context {
        $task=Read-CoordinationTask $context $Id
        Assert-CoordinationOwner $task $Owner
        if (-not $task.plan) { throw 'Record a plan and its acceptance checks before QA.' }
        Assert-CoordinationImplementationReady $task
        $task
    }
    $target=Get-CoordinationTaskContext $context $observed
    $snapshot=Get-CoordinationSnapshot $target
    $prepared=Invoke-CoordinationLock $context {
        $task=Read-CoordinationTask $context $Id
        Assert-CoordinationOwner $task $Owner
        if ($task.updatedAt -ne $observed.updatedAt) { throw 'Task changed while preparing QA. Read its current plan and retry explicitly.' }
        Assert-CoordinationCurrentReview $task $snapshot
        Assert-CoordinationImplementationReady $task
        if (($Verdict -eq 'fail' -or $task.plan.checks.Count -eq 0 -or $task.plan.requireRuntimeEvidence) -and ([string]::IsNullOrWhiteSpace($Summary) -or $Evidence.Count -eq 0)) { throw 'Manual/runtime acceptance requires -Summary and -Evidence; executed command results alone do not prove it.' }
        $task.execution=New-CoordinationLease $Owner 'qa' $runId
        Save-CoordinationTask $context $task
        [pscustomobject]@{ task=$task; target=$target; snapshot=$snapshot }
    }
    $artifactDirectory=Join-Path $context.board "artifacts/$Id/$runId"
    $results=@(); $failure=''; $sourceChanged=$false
    $qaWatch=[Diagnostics.Stopwatch]::StartNew()
    try {
        Assert-CoordinationPath $artifactDirectory
        $null=New-Item -ItemType Directory -Path $artifactDirectory -Force
        foreach ($check in @($prepared.task.plan.checks)) {
            $working=Resolve-CoordinationDirectory $prepared.target $check.workingDirectory
            $prefix=Join-Path $artifactDirectory $check.name
            $remaining=$TimeoutSeconds-[int][Math]::Floor($qaWatch.Elapsed.TotalSeconds)
            if ($remaining -le 0) { $failure='QA exhausted its total time budget.'; break }
            $checkTimeout=[Math]::Min($check.timeoutSeconds,$remaining)
            $result=Invoke-CoordinationProcess -Executable $check.executable -Arguments @($check.arguments) -WorkingDirectory $working -TimeoutSeconds $checkTimeout -LogPrefix $prefix
            $results+=[pscustomobject]@{ name=$check.name; executable=$check.executable; arguments=@($check.arguments); exitCode=$result.exitCode; timedOut=$result.timedOut; durationMs=$result.durationMs; workingDirectory=$working; stdout="$prefix.stdout.log"; stderr="$prefix.stderr.log" }
            if ($result.timedOut -or $result.exitCode -ne 0) { $failure="QA check '$($check.name)' failed (exit $($result.exitCode), timeout $($result.timedOut))."; break }
        }
        if ((Get-CoordinationSnapshot $prepared.target) -ne $prepared.snapshot) { $sourceChanged=$true; $failure='Source changed during QA. Re-review the new snapshot and rerun acceptance checks.' }
        elseif (-not $failure -and $Verdict -eq 'fail') { $failure='Manual/runtime acceptance failed; inspect QA summary and evidence.' }
    } catch { $failure=$_.Exception.Message }
    Invoke-CoordinationLock $context {
        $task=Read-CoordinationTask $context $Id
        if (-not $task.execution -or $task.execution.id -ne $runId) { throw 'QA execution lease changed unexpectedly; results were not applied.' }
        $receipt=[pscustomobject]@{ snapshot=$prepared.snapshot; passed=($failure -eq ''); checks=@($results); manualSummary=$Summary; manualEvidence=@($Evidence); failure=$failure; recordedAt=[DateTime]::UtcNow.ToString('o') }
        if (Test-Path -LiteralPath $artifactDirectory) { Write-CoordinationJson (Join-Path $artifactDirectory 'qa.json') $receipt }
        $task.qa=$receipt; $task.execution=$null; $task.stage='qa'; $task.status='claimed'
        if (-not $failure -and $task.PSObject.Properties['validationFailures']) { Set-CoordinationProperty $task 'validationFailures' @() }
        if ((Test-CoordinationReadinessRequired $task) -and -not $sourceChanged -and (@($results | Where-Object { $_.timedOut -or $_.exitCode -ne 0 }).Count -gt 0 -or ($Verdict -eq 'fail' -and $failure -eq 'Manual/runtime acceptance failed; inspect QA summary and evidence.'))) {
            $prior=@()
            if ($task.PSObject.Properties['validationFailures']) { $prior=@($task.validationFailures) }
            $failedCheck=if (@($results).Count) {$results[-1].name} else {'manual'}
            Set-CoordinationProperty $task 'validationFailures' @(@($prior) + @([pscustomobject]@{ check=$failedCheck; failure=$failure; recordedAt=$receipt.recordedAt }))
            if ($task.validationFailures.Count -ge 2) { $task.status='blocked' }
        }
        $task.artifacts=@($task.artifacts)+@("$artifactDirectory/qa.json")
        Save-CoordinationTask $context $task
    }
    if ($failure) { throw $failure }
    Write-Output "QA passed for $Id. Receipt: $artifactDirectory/qa.json"
    return
}

if ($Action -eq 'review') {
    Assert-TaskSummary; Assert-CoordinationIdentity $Reviewer
    $observed=Invoke-CoordinationLock $context { Read-CoordinationTask $context $Id }
    $target=Get-CoordinationTaskContext $context $observed
    $snapshot=Get-CoordinationSnapshot $target
    Invoke-CoordinationLock $context {
        $task=Read-CoordinationTask $context $Id
        if ($task.updatedAt -ne $observed.updatedAt) { throw 'Task changed during review preparation. Read its current state and retry explicitly.' }
        if (-not $task.plan -or $task.status -eq 'complete' -or $task.execution) { throw 'Review requires a planned, active task without a running execution.' }
        Assert-CoordinationImplementationReady $task
        if ($Reviewer -ieq $task.owner -or $Reviewer -in @($task.implementationParticipants)) { throw 'Reviewer must be a different actor who did not implement this task.' }
        $task.review=[pscustomobject]@{ actor=$Reviewer; runtime=(Get-CoordinationActorRuntime $Reviewer); verdict=$Verdict; summary=$Summary; evidence=@($Evidence); snapshot=$snapshot; verification='manual-attestation'; recordedAt=[DateTime]::UtcNow.ToString('o') }
        $task.qa=$null; $task.stage='review'; $task.status='review'
        Save-CoordinationTask $context $task
        Write-Output "Recorded $Verdict review from $Reviewer for $Id."
    }
    return
}

if ($Action -eq 'complete') {
    $completionTask=Invoke-CoordinationLock $context { $item=Read-CoordinationTask $context $Id; Assert-CoordinationOwner $item $Owner; $item }
    $completionContext=Get-CoordinationTaskContext $context $completionTask
    $completionSnapshot=Get-CoordinationSnapshot $completionContext
}

Invoke-CoordinationLock $context {
    if ($Action -eq 'migrate') {
        $legacy=Read-CoordinationTask $context $Id -AllowLegacy
        if ($legacy.schemaVersion -eq 2) { Write-Output "$Id already uses schema v2."; return }
        $legacyPath=Get-CoordinationTaskPath $context $Id
        $backupPath="$legacyPath.v1.json.backup"
        if (Test-Path -LiteralPath $backupPath) { throw "Migration backup already exists: $backupPath. Inspect it before proceeding." }
        [IO.File]::Copy($legacyPath,$backupPath)
        $pending=if ($legacy.PSObject.Properties['pendingOwner']) {$legacy.pendingOwner} else {$null}
        $scopes=@($legacy.ownedFiles | ForEach-Object { ConvertTo-CoordinationScope $_ })
        if (-not $scopes.Count) { $scopes=@('.') }
        $task=[pscustomobject][ordered]@{ schemaVersion=2; id=$Id; title=$legacy.title; goal=$legacy.goal; acceptance=@($legacy.acceptance); risk=$legacy.risk; kind='feature'; playbook='feature'; stack='generic'; runtime=(Get-CoordinationActorRuntime $legacy.owner); status=$(if ($legacy.owner) {'claimed'} else {'open'}); stage='plan'; owner=$legacy.owner; pendingOwner=$pending; worktree=$context.root; ownedFiles=@($scopes); implementationParticipants=@(); handoffs=@($legacy.handoffs); artifacts=@($backupPath); runs=@(); plan=$null; review=$null; qa=$null; execution=$null; legacy=$legacy; createdAt=$legacy.createdAt; updatedAt=[DateTime]::UtcNow.ToString('o') }
        Assert-CoordinationOwnership $context $task
        Save-CoordinationTask $context $task
        Write-Output "Migrated $Id to v2. Legacy evidence is retained, and fresh plan/review/QA is required."
        return
    }
    $task=Read-CoordinationTask $context $Id
    if ($Action -eq 'recover') {
        Assert-CoordinationIdentity $Owner
        if ($task.owner -cne $Owner -or -not $Reason -or -not $task.execution) { throw 'recover requires the current owner, an execution lease and -Reason.' }
        $process=Get-Process -Id $task.execution.pid -ErrorAction SilentlyContinue
        if ($process -and $process.StartTime.ToUniversalTime().ToString('o') -eq $task.execution.processStartedAt) { throw 'Coordinator process is still alive. Wait for it or stop only your task-started process before recovery.' }
        $task.execution=$null; Clear-CoordinationGates $task; $task.status='blocked'
        Set-CoordinationProperty $task 'recovery' ([pscustomobject]@{ owner=$Owner; reason=$Reason; recordedAt=[DateTime]::UtcNow.ToString('o') })
        Save-CoordinationTask $context $task
        Write-Output "Recovered stale execution lease for $Id; fresh verification is required."
        return
    }
    if ($Action -eq 'claim') {
        Assert-CoordinationIdentity $Owner
        if ($task.status -eq 'complete' -or $task.execution) { throw 'Task is completed or executing; it cannot be claimed.' }
        if (($task.owner -and $task.owner -cne $Owner) -or ($task.pendingOwner -and $task.pendingOwner -cne $Owner)) { throw "Task belongs to '$($task.owner)$($task.pendingOwner)'; only that actor can claim it." }
        $task.owner=$Owner; $task.pendingOwner=$null; $task.runtime=Get-CoordinationActorRuntime $Owner $Runtime; $task.status='claimed'
        if ($task.plan -and $task.kind -ne 'analysis') { $task.implementationParticipants=@(@($task.implementationParticipants)+@($Owner) | Sort-Object -Unique) }
        Assert-CoordinationOwnership $context $task
        Save-CoordinationTask $context $task
        Write-Output "$Id claimed by $Owner."
        return
    }
    Assert-CoordinationOwner $task $Owner
    switch ($Action) {
        'plan' {
            Assert-TaskSummary
            $target=Get-CoordinationTaskContext $context $task
            $checks=@(Read-CoordinationChecks $target $CheckFile)
            if (-not $checks.Count -and [string]::IsNullOrWhiteSpace($NoChecksReason)) { throw 'Provide -CheckFile with acceptance commands or an explicit -NoChecksReason.' }
            $readiness=$null
            if (Test-CoordinationReadinessRequired $task) { $readiness=Read-CoordinationReadiness $target $ReadinessFile $task }
            elseif ($ReadinessFile) { throw '-ReadinessFile applies to bugfix or medium/high feature tasks.' }
            $priorFailureCount=if ($task.PSObject.Properties['validationFailures']) {@($task.validationFailures).Count} else {0}
            $hasNewEvidence=$readiness -and $readiness.PSObject.Properties['newEvidence']
            if ($priorFailureCount -ge 2 -and -not $hasNewEvidence) { throw 'After two failed validation rounds, replan with fresh newEvidence.' }
            $resetValidationFailures=$false
            if ($priorFailureCount -gt 0 -and $hasNewEvidence) {
                $known=@()
                if ($task.PSObject.Properties['investigationEvidence']) { $known+=@($task.investigationEvidence) }
                if ($task.plan) { $known+=@($task.plan.evidence) }
                if ($task.plan -and $task.plan.PSObject.Properties['readiness']) {
                    foreach ($name in @('newEvidence','reproductionEvidence','causeEvidence')) {
                        if ($task.plan.readiness.PSObject.Properties[$name]) { $known+=@($task.plan.readiness.$name) }
                    }
                }
                $knownNormalized=@($known | Where-Object { $_ -is [string] } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Sort-Object -Unique)
                if (@($readiness.newEvidence | Where-Object { $_.Trim().ToLowerInvariant() -notin $knownNormalized }).Count -eq 0) { throw 'Replan evidence must contain a new diagnostic fact absent from the prior plan.' }
                $resetValidationFailures=$true
            }
            if ($readiness) {
                $history=if ($task.PSObject.Properties['investigationEvidence']) {@($task.investigationEvidence)} else {@()}
                $history=@($history)+@($Evidence)
                foreach ($name in @('newEvidence','reproductionEvidence','causeEvidence')) {
                    if ($readiness.PSObject.Properties[$name]) { $history+=@($readiness.$name) }
                }
                $history=@($history | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Sort-Object -Unique)
                if ($history.Count -gt 256) { throw 'Investigation evidence history exceeds 256 facts; split the tracked task.' }
                Set-CoordinationProperty $task 'investigationEvidence' $history
            }
            $runtimeProof=$RequireRuntimeEvidence.IsPresent -or ($task.stack -eq 'unity' -and $task.kind -ne 'analysis')
            $task.plan=[pscustomobject]@{ summary=$Summary; evidence=@($Evidence); checks=@($checks); noChecksReason=$NoChecksReason; requireRuntimeEvidence=$runtimeProof; recordedAt=[DateTime]::UtcNow.ToString('o') }
            if ($readiness) { Set-CoordinationProperty $task.plan 'readiness' $readiness }
            if ($resetValidationFailures) { Set-CoordinationProperty $task 'validationFailures' @() }
            if ($hardProblemProvided) { Set-CoordinationProperty $task 'hardProblem' $HardProblem.Trim() }
            if ($task.kind -ne 'analysis') { $task.implementationParticipants=@(@($task.implementationParticipants)+@($Owner) | Sort-Object -Unique) }
            Clear-CoordinationGates $task
            $task.stage=if ($task.kind -eq 'analysis') {'analysis'} else {'implement'}
            $task.status='claimed'; Save-CoordinationTask $context $task
            Write-Output "Plan recorded for $Id; $($checks.Count) executable acceptance check(s)."
        }
        'handoff' {
            Assert-TaskSummary; Assert-CoordinationIdentity $NextOwner
            if ($NextOwner -ceq $Owner) { throw 'Handoff recipient must differ from current owner.' }
            $task.handoffs=@($task.handoffs)+@([pscustomobject]@{ from=$Owner; to=$NextOwner; summary=$Summary; changedFiles=@($ChangedFile); decisions=@($Decision); evidence=@($Evidence); limitations=@($Limitation); createdAt=[DateTime]::UtcNow.ToString('o') })
            $task.owner=$null; $task.pendingOwner=$NextOwner; $task.status='open'; Clear-CoordinationGates $task
            Save-CoordinationTask $context $task
            Write-Output "$Id handed off to $NextOwner."
        }
        'release' {
            if (-not $Reason) { throw 'release requires -Reason.' }
            $task.handoffs=@($task.handoffs)+@([pscustomobject]@{ from=$Owner; to=''; summary="Released: $Reason"; changedFiles=@(); decisions=@(); evidence=@(); limitations=@(); createdAt=[DateTime]::UtcNow.ToString('o') })
            $task.owner=$null; $task.pendingOwner=$null; $task.status='open'; Clear-CoordinationGates $task; Save-CoordinationTask $context $task
            Write-Output "$Id released."
        }
        'complete' {
            if ([string]::IsNullOrWhiteSpace($QaSummary) -or -not $Evidence.Count) { throw 'complete requires -QaSummary and -Evidence.' }
            if (-not $task.plan -or -not $task.qa -or -not $task.qa.passed) { throw 'Successful executable or explicit manual acceptance QA is required before completion.' }
            Assert-CoordinationImplementationReady $task
            if ($task.updatedAt -ne $completionTask.updatedAt) { throw 'Task changed while preparing completion. Inspect its new state before completing.' }
            $snapshot=$completionSnapshot
            Assert-CoordinationCurrentReview $task $snapshot
            if ($task.qa.snapshot -ne $snapshot) { throw 'QA is stale: source changed after verification. Re-review and rerun QA.' }
            Set-CoordinationProperty $task 'completion' ([pscustomobject]@{ summary=$QaSummary; evidence=@($Evidence); actor=$Owner; recordedAt=[DateTime]::UtcNow.ToString('o') })
            $task.status='complete'; $task.stage='complete'; Save-CoordinationTask $context $task
            Write-Output "$Id complete at verified snapshot $snapshot."
        }
        'worktree' {
            if (-not $context.isGit) { throw 'worktree requires a Git repository with an initial commit.' }
            if ($task.worktree -ine $context.root) { throw 'Invoke worktree from the task source checkout.' }
            $dirty=Invoke-CoordinationGit $context.root @('status','--porcelain','--untracked-files=normal','--','.',':(exclude).agent-coordination')
            if ($dirty) { throw 'Source checkout has uncommitted changes. Preserve or commit them before creating a task worktree; they will not be silently copied.' }
            $taskBranch=if ($Branch) {$Branch} else {"agents/$Id"}
            if ($taskBranch -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]{0,100}$') { throw 'Invalid worktree branch name.' }
            $null=Invoke-CoordinationGit $context.root @('check-ref-format','--branch',$taskBranch)
            $destination=Join-Path $context.board "worktrees/$Id"
            Assert-CoordinationPath $destination
            if (Test-Path -LiteralPath $destination) { throw "Worktree destination already exists: $destination" }
            $null=Invoke-CoordinationGit $context.root @('worktree','add','-b',$taskBranch,'--',$destination,'HEAD')
            $task.worktree=[IO.Path]::GetFullPath($destination); $task.plan=$null; Clear-CoordinationGates $task
            $task.stage='plan'; Save-CoordinationTask $context $task
            Write-Output "Task worktree: $destination (branch $taskBranch)."
        }
    }
}
