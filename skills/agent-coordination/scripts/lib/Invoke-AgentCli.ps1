$script:CoordinationScriptEntry=Join-Path $PSScriptRoot 'Invoke-ScriptEntry.ps1'
if (-not ('AgentCoordination.BoundedCapture' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;
namespace AgentCoordination {
    public static class BoundedCapture {
        public static async Task<string> ReadAsync(StreamReader reader, int maximumCharacters) {
            var text = new StringBuilder();
            var buffer = new char[4096];
            int count;
            while ((count = await reader.ReadAsync(buffer, 0, buffer.Length)) > 0) {
                if (text.Length + count > maximumCharacters)
                    throw new IOException("Child output exceeded the 4 Mi-character stream limit.");
                text.Append(buffer, 0, count);
            }
            return text.ToString();
        }
    }
}
'@
}

function ConvertTo-CoordinationArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value -and $Value -notmatch '[\s"]') { return $Value }
    $builder = [Text.StringBuilder]::new()
    $null = $builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq [char]92) { $slashes++; continue }
        if ($character -eq [char]34) {
            $null = $builder.Append(([string][char]92) * (2 * $slashes + 1))
            $null = $builder.Append('"')
        } else {
            $null = $builder.Append(([string][char]92) * $slashes)
            $null = $builder.Append($character)
        }
        $slashes = 0
    }
    $null = $builder.Append(([string][char]92) * (2 * $slashes))
    $null = $builder.Append('"')
    return $builder.ToString()
}

function Resolve-CoordinationExecutable {
    param([string]$Executable, [string[]]$Arguments)
    $command = Get-Command $Executable -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { throw "Executable not found: $Executable. Install it or configure an explicit path; no fallback model or runtime was selected." }
    $path = $command.Source
    if ([IO.Path]::GetExtension($path) -ieq '.ps1') {
        $json=ConvertTo-Json -InputObject @($Arguments) -Compress
        $encoded=[Convert]::ToBase64String($script:CoordinationEncoding.GetBytes($json))
        return [pscustomobject]@{ path = (Get-Process -Id $PID).Path; arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$script:CoordinationScriptEntry,'-ScriptPath',$path,'-ArgumentsBase64',$encoded) }
    }
    if ([IO.Path]::GetExtension($path) -in @('.cmd','.bat')) { throw "Command-shell wrappers are not supported: $path. Use a native executable or the PowerShell .ps1 wrapper." }
    return [pscustomobject]@{ path = $path; arguments = @($Arguments) }
}

function Stop-CoordinationChild {
    param([Diagnostics.Process]$Process)
    if ($Process.HasExited) { return }
    if ($PSVersionTable.PSVersion.Major -ge 7) { $Process.Kill($true) }
    elseif ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $killer = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32/taskkill.exe') -ArgumentList @('/PID',[string]$Process.Id,'/T','/F') -WindowStyle Hidden -Wait -PassThru
        if ($killer.ExitCode -ne 0 -and -not $Process.HasExited) { throw "Could not stop timed-out process $($Process.Id). Inspect this task-started process manually." }
    } else { $Process.Kill() }
    $null = $Process.WaitForExit(5000)
}

function Invoke-CoordinationProcess {
    param([string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory, [AllowEmptyString()][string]$InputText = '', [int]$TimeoutSeconds = 600, [string]$LogPrefix)
    $invocation = Resolve-CoordinationExecutable $Executable $Arguments
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $invocation.path
    if ($PSVersionTable.PSVersion.Major -ge 7) { foreach ($argument in $invocation.arguments) { $start.ArgumentList.Add($argument) } }
    else { $start.Arguments = (@($invocation.arguments | ForEach-Object { ConvertTo-CoordinationArgument $_ }) -join ' ') }
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = $script:CoordinationEncoding
    $start.StandardErrorEncoding = $script:CoordinationEncoding
    if ($start.PSObject.Properties['StandardInputEncoding']) { $start.StandardInputEncoding = $script:CoordinationEncoding }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $timedOut = $false
    $started = $false
    try {
        if (-not $process.Start()) { throw "Could not start $Executable." }
        $started = $true
        $stdoutTask = [AgentCoordination.BoundedCapture]::ReadAsync($process.StandardOutput, 4194304)
        $stderrTask = [AgentCoordination.BoundedCapture]::ReadAsync($process.StandardError, 4194304)
        if ($InputText) {
            $writeTask = $process.StandardInput.WriteAsync($InputText)
            if (-not $writeTask.Wait($TimeoutSeconds * 1000)) { $timedOut = $true; Stop-CoordinationChild $process }
        }
        $process.StandardInput.Close()
        while (-not $timedOut -and -not $process.WaitForExit(100)) {
            if ($stdoutTask.IsFaulted -or $stderrTask.IsFaulted) { Stop-CoordinationChild $process; throw 'Agent/check output exceeded the bounded capture limit. Narrow its output and rerun.' }
            if ($watch.ElapsedMilliseconds -ge $TimeoutSeconds * 1000) { $timedOut = $true; Stop-CoordinationChild $process }
        }
        if (-not $stdoutTask.Wait(5000) -or -not $stderrTask.Wait(5000)) { throw 'Child output streams did not close after exit. Inspect task-started child processes.' }
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        if ($LogPrefix) {
            [IO.File]::WriteAllText("$LogPrefix.stdout.log", $stdout, $script:CoordinationEncoding)
            [IO.File]::WriteAllText("$LogPrefix.stderr.log", $stderr, $script:CoordinationEncoding)
        }
        [pscustomobject]@{ exitCode = $process.ExitCode; timedOut = $timedOut; durationMs = $watch.ElapsedMilliseconds; stdout = $stdout; stderr = $stderr; executable = $invocation.path; arguments = @($invocation.arguments); workingDirectory = $WorkingDirectory }
    } finally {
        if ($started -and -not $process.HasExited) { Stop-CoordinationChild $process }
        $process.Dispose()
    }
}

function Get-CoordinationCliInvocation {
    param([ValidateSet('codex','claude')][string]$Runtime, [string]$Phase, $Model, [string]$Root, [string]$ResponsePath, [string]$SchemaPath, [string]$CliPath = '')
    $executable = if ($CliPath) { $CliPath } else { $Runtime }
    $writable = $Phase -eq 'implement'
    if ($Runtime -eq 'codex') {
        $mode = if ($writable) { 'workspace-write' } else { 'read-only' }
        $arguments = @('--ask-for-approval','never','exec','--cd',$Root,'--sandbox',$mode,'--model',[string]$Model.model,'--config',('model_reasoning_effort="' + $Model.effort + '"'),'--ephemeral','--output-schema',$SchemaPath,'--output-last-message',$ResponsePath,'-')
    } else {
        $mode = if ($writable) { 'acceptEdits' } else { 'dontAsk' }
        $tools = if ($writable) { 'Read,Edit,Write,Grep,Glob,Bash' } else { 'Read,Grep,Glob' }
        $schemaDocument = [IO.File]::ReadAllText($SchemaPath) | ConvertFrom-Json
        # Claude rejects the canonical draft URI; the result shape uses portable schema keywords.
        $schemaDocument.PSObject.Properties.Remove('$schema')
        $schema = $schemaDocument | ConvertTo-Json -Depth 20 -Compress
        $arguments = @('--print','--model',[string]$Model.model,'--permission-mode',$mode,'--permission-prompts','none','--tools',$tools,'--strict-mcp-config','--mcp-config','{"mcpServers":{}}','--output-format','json','--json-schema',$schema,'--no-session-persistence')
        if ($Model.effort) { $arguments += @('--effort',[string]$Model.effort) }
    }
    return [pscustomobject]@{ executable = $executable; arguments = @($arguments); workingDirectory = $Root }
}
