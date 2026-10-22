#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Packages.psm1') -Force
$script:AppSource = Split-Path $PSScriptRoot -Parent
$script:Marker = 'visible-chrome-bridge-v1'

function Get-BridgeRoot {
    param([string]$DataRoot)
    if ([string]::IsNullOrWhiteSpace($DataRoot)) { $DataRoot = Join-Path $env:LOCALAPPDATA 'VisibleChromeBridge' }
    $root = [IO.Path]::GetFullPath($DataRoot).TrimEnd('\', '/')
    if ($root.Length -lt 8 -or $root -eq [IO.Path]::GetPathRoot($root).TrimEnd('\')) { throw 'Choose a dedicated per-user data directory.' }
    if ($root.StartsWith('\\') -or $root -match '[,\r\n]') { throw 'Use a local path without commas or line breaks (upstream command parser restriction).' }
    $source = [IO.Path]::GetFullPath($script:AppSource).TrimEnd('\')
    # An installed app is a child of the data root; a checkout must never contain data.
    if ($root.Equals($source, [StringComparison]::OrdinalIgnoreCase) -or $root.StartsWith($source + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The private data directory must be outside the repository/application directory.'
    }
    Assert-BridgePath $root
    return $root
}

function Assert-BridgePath {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse points are not supported in bridge storage paths.' }
        }
        $parent = Split-Path $cursor -Parent
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Get-BridgeChildPath {
    param([string]$Root, [string]$Relative)
    if ([IO.Path]::IsPathRooted($Relative)) { throw 'Invalid relative state path.' }
    $path = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not $path.StartsWith($Root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'State path escaped the private root.' }
    Assert-BridgePath $path
    return $path
}

function Get-BridgeIdentity {
    param([string]$Root)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Root.ToLowerInvariant())) }
    finally { $sha.Dispose() }
    $id = ([BitConverter]::ToString($hash)).Replace('-', '').Substring(0, 24)
    return 'VisibleChromeBridge-' + $id
}

function Initialize-BridgeNative {
    if (-not ('VisibleChromeBridge.NativeJob' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'NativeJob.cs') }
}

function New-BridgeMutex {
    param([string]$Name)
    # Global mutexes need no administrator privilege (unlike global file maps).
    # Include the SID to avoid collisions with another user's installation.
    $security = New-Object Security.AccessControl.MutexSecurity
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = New-Object Security.AccessControl.MutexAccessRule($sid, 'FullControl', 'Allow')
    $security.AddAccessRule($rule)
    $created = $false
    $fullName = 'Global\' + $sid.Value + '-' + $Name
    if ($PSVersionTable.PSEdition -eq 'Core') { return [Threading.MutexAcl]::Create($false, $fullName, [ref]$created, $security) }
    return [Threading.Mutex]::new($false, $fullName, [ref]$created, $security)
}

function Invoke-BridgeLocked {
    param([string]$Root, [scriptblock]$Action, [switch]$RemoveDataAfterAction)
    $mutex = New-BridgeMutex ((Get-BridgeIdentity $Root) + '-operation')
    $held = $false
    $fileLock = $null
    try {
        try { $held = $mutex.WaitOne(1000) } catch [Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { throw 'Another bridge operation is in progress. Retry after it finishes.' }
        if (Test-Path -LiteralPath $Root) {
            Assert-BridgeOwnedRoot $Root
            try { $fileLock = [IO.File]::Open((Join-Path $Root 'operation.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
            catch { throw 'Another bridge operation holds the storage lock.' }
        }
        & $Action
        if ($RemoveDataAfterAction) {
            if ($fileLock) { $fileLock.Dispose(); $fileLock = $null }
            Remove-BridgeOwnedData $Root
        }
    }
    finally {
        if ($fileLock) { $fileLock.Dispose() }
        if ($held) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

function Set-BridgePrivateAcl {
    param([string]$Root)
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl.SetOwner($sid)
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($principal in @($sid, [Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new($principal, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Root -AclObject $acl
}

function Assert-BridgeOwnedRoot {
    param([string]$Root)
    Assert-BridgePath $Root
    $marker = Join-Path $Root 'owner.json'
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { throw 'This directory is not an owned Visible Chrome Bridge installation. It will not be modified.' }
    $owner = Read-BridgeJson $marker
    if ($owner.Product -ne $script:Marker -or $owner.UserSid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) { throw 'This installation belongs to another user or product.' }
}

function Write-BridgeJson {
    param([string]$Path, [object]$Value)
    Assert-BridgePath $Path
    $temp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temp, ($Value | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temp, $Path, [Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temp, $Path) }
    }
    finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}

function Read-BridgeJson {
    param([string]$Path)
    Assert-BridgePath $Path
    try { return [IO.File]::ReadAllText($Path) | ConvertFrom-Json }
    catch { throw 'Bridge state is missing or unreadable. Reinstall into the same owned root to repair it.' }
}

function Get-BridgePrerequisites {
    if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem -or -not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
        throw 'Windows 10/11 x64 and a 64-bit PowerShell process are required.'
    }
    $osVersion = [Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) { throw 'Windows 10 or newer is required.' }
    $nodeCommand = Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $npmCommand = Get-Command npm.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $nodeCommand -or -not $npmCommand) { throw 'Install a supported Node.js LTS release with npm, then open a new PowerShell window.' }
    Initialize-BridgeNative
    # Resolve version-manager junctions: fnm multishell directories expire at logoff.
    $nodePath = (& $nodeCommand.Source -p 'process.execPath' 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $nodePath -PathType Leaf)) { throw 'Cannot resolve a durable node.exe path. Repair Node.js first.' }
    $nodePath = [VisibleChromeBridge.NativeJob]::ResolveFilePath($nodePath)
    [void](ConvertTo-BridgeCommand @($nodePath))
    $versionText = (& $nodePath --version 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $versionText -notmatch '^v(\d+)\.(\d+)\.(\d+)$') { throw 'Cannot determine Node.js version.' }
    $nodeVersion = [version]$versionText.TrimStart('v')
    if (-not (($nodeVersion.Major -eq 22 -and $nodeVersion -ge [version]'22.12.0') -or $nodeVersion.Major -eq 24)) { throw 'Use Node.js 22.12+ LTS or Node.js 24 LTS. Other major versions are not validated.' }
    $chromePaths = @(
        (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
    )
    $chrome = @($chromePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1)
    if ($chrome.Count -eq 0) { throw 'Install Google Chrome 144+ in a standard per-user or system location.' }
    $chromeVersion = (Get-Item -LiteralPath $chrome[0]).VersionInfo.ProductVersion
    if ([version]$chromeVersion -lt [version]'144.0.0.0') { throw 'Chrome 144+ is required for --autoConnect. Update Chrome manually.' }
    return [pscustomobject]@{ NodePath=$nodePath; NpmPath=$npmCommand.Source; NodeVersion=$nodeVersion.ToString(); ChromeVersion=$chromeVersion }
}

function Save-BridgeCredentials {
    param([string]$Root, [Security.SecureString]$TunnelId, [Security.SecureString]$ApiKey)
    $plain = [IntPtr]::Zero
    try {
        $plain = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($TunnelId)
        $id = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($plain)
        if ($id -cnotmatch '^tunnel_([a-z0-9]{4}_)?[a-z0-9]{32}$') { throw 'Enter the complete tunnel identifier returned by OpenAI (starting tunnel_).' }
    }
    finally { if ($plain -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($plain) }; $id = $null }
    if ($ApiKey.Length -lt 16) { throw 'Runtime API key is empty or too short. Use a runtime key with Tunnels Read + Use.' }
    $credentials = @{ TunnelId=ConvertFrom-SecureString $TunnelId; ApiKey=ConvertFrom-SecureString $ApiKey }
    Write-BridgeJson (Join-Path $Root 'credentials.dpapi') $credentials
}

function Get-BridgeState {
    param([string]$Root)
    Assert-BridgeOwnedRoot $Root
    $state = Read-BridgeJson (Join-Path $Root 'state.json')
    if ($state.Schema -ne 1) { throw 'Unsupported bridge state schema.' }
    return $state
}

function Get-BridgeWorkerState {
    param([string]$Root)
    $path = Join-Path $Root 'worker.json'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $worker = Read-BridgeJson $path
    $process = Get-Process -Id $worker.ProcessId -ErrorAction SilentlyContinue
    if (-not $process) { return $null }
    try {
        if ($process.StartTime.ToUniversalTime().Ticks.ToString() -ne $worker.StartTicks) { return $null }
    } catch { return $null }
    return $worker
}

function Test-BridgeLifetime {
    param([string]$Root)
    $path = Join-Path $Root 'worker.lock'
    try { $handle = [IO.File]::Open($path, 'OpenOrCreate', 'ReadWrite', 'None'); $handle.Dispose(); return $false }
    catch { return $true }
}

function Get-BridgeHealth {
    param([string]$Root)
    $healthy = $false; $ready = $false
    $path = Join-Path $Root 'health.url'
    if (Test-Path -LiteralPath $path) {
        $url = [IO.File]::ReadAllText($path).Trim().TrimEnd('/')
        if ($url -notmatch '^http://127\.0\.0\.1:[1-9][0-9]{0,4}$' -or ([uri]$url).Port -gt 65535) { throw 'Invalid local health URL. Stop and restart the bridge.' }
        foreach ($endpoint in @('healthz','readyz')) {
            try {
                $request = [Net.HttpWebRequest]::Create($url + '/' + $endpoint)
                $request.Proxy = $null; $request.Timeout = 1500; $request.AllowAutoRedirect = $false
                $response = $request.GetResponse()
                try { $ok = [int]$response.StatusCode -eq 200 } finally { $response.Close() }
                if ($endpoint -eq 'healthz') { $healthy = $ok } else { $ready = $ok }
            } catch { } # Do not persist bodies or URLs from upstream errors.
        }
    }
    return [pscustomobject]@{ Healthy=$healthy; RuntimeReady=$ready }
}

function Get-BridgeStatus {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath (Join-Path $Root 'owner.json'))) { return [pscustomobject]@{ Installed=$false; Running=$false; Healthy=$false; RuntimeReady=$false; BrowserVerified=$false } }
    $state = Get-BridgeState $Root
    $running = Test-BridgeLifetime $Root
    $health = [pscustomobject]@{Healthy=$false;RuntimeReady=$false}
    if ($running -and (Get-BridgeWorkerState $Root)) { $health = Get-BridgeHealth $Root }
    $outcome='NotStarted'; $updatesAvailable=$false; $lastUpdateCheck=$null
    if (Test-Path -LiteralPath (Join-Path $Root 'outcome.json')) {
        $last=Read-BridgeJson (Join-Path $Root 'outcome.json')
        if ($last.Outcome -in @('Started','Stopped','UpstreamExited','StartupFailed')) { $outcome=$last.Outcome }
    }
    if (Test-Path -LiteralPath (Join-Path $Root 'updates.json')) {
        $updates=Read-BridgeJson (Join-Path $Root 'updates.json')
        $updatesAvailable=($updates.TunnelUpdate -and $updates.TunnelLatest -ne $state.Current.TunnelVersion) -or ($updates.McpUpdate -and $updates.McpLatest -ne $state.Current.McpVersion)
        $lastUpdateCheck=$updates.CheckedAt
    }
    return [pscustomobject]@{ Installed=$true; Running=$running; Healthy=$health.Healthy; RuntimeReady=$health.RuntimeReady; BrowserVerified=$false; TunnelVersion=$state.Current.TunnelVersion; McpVersion=$state.Current.McpVersion; UpdatePolicy=$state.UpdatePolicy;LastOutcome=$outcome;UpdatesAvailable=$updatesAvailable;LastUpdateCheck=$lastUpdateCheck }
}

function ConvertTo-BridgeCommand {
    param([string[]]$Arguments)
    $quoted = foreach ($argument in $Arguments) {
        if ([string]::IsNullOrEmpty($argument) -or $argument -match '[,\r\n\x00]') { throw 'Unsupported character in upstream stdio command path.' }
        '"' + $argument.Replace('\','/').Replace('"','\"') + '"'
    }
    return $quoted -join ' '
}

function New-BridgeEnvironment {
    $result = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @('SystemRoot','WINDIR','COMSPEC','PATH','PATHEXT','TEMP','TMP','USERPROFILE','LOCALAPPDATA','APPDATA','PROGRAMFILES','PROGRAMFILES(X86)','PROGRAMDATA','HOMEDRIVE','HOMEPATH','NUMBER_OF_PROCESSORS','PROCESSOR_ARCHITECTURE','OS')) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if ($null -ne $value) { $result[$name] = $value }
    }
    return ,$result
}

function Invoke-BridgeWorker {
    param([string]$Root)
    Assert-BridgeOwnedRoot $Root
    Initialize-BridgeNative
    $lifetime = $null; $job = $null; $stop = $null
    $secret = [IntPtr]::Zero
    try {
        try { $lifetime = [IO.File]::Open((Join-Path $Root 'worker.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
        catch { return } # Another worker owns this root, including another logon session.
        $state = Get-BridgeState $Root
        $payload = Get-BridgeChildPath $Root $state.Current.Directory
        $exe = Get-BridgeChildPath $payload $state.Current.TunnelRelativePath
        $entry = Get-BridgeChildPath $payload $state.Current.McpRelativePath
        $command = ConvertTo-BridgeCommand @($state.NodePath, (Join-Path $PSScriptRoot 'mcp-launcher.cjs'), $entry)
        $credentials = Read-BridgeJson (Join-Path $Root 'credentials.dpapi')
        $environment = New-BridgeEnvironment
        foreach ($name in @('TunnelId','ApiKey')) {
            $secure = ConvertTo-SecureString $credentials.$name
            try {
                $secret = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
                $value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secret)
                $key = if ($name -eq 'ApiKey') { 'CONTROL_PLANE_API_KEY' } else { 'CONTROL_PLANE_TUNNEL_ID' }
                $environment[$key] = $value
            }
            finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secret); $secret=[IntPtr]::Zero; $secure.Dispose(); $value=$null }
        }
        $eventName = 'Local\' + (Get-BridgeIdentity $Root) + '-' + [guid]::NewGuid().ToString('N')
        $security = New-Object Security.AccessControl.EventWaitHandleSecurity
        $security.AddAccessRule([Security.AccessControl.EventWaitHandleAccessRule]::new([Security.Principal.WindowsIdentity]::GetCurrent().User, 'FullControl', 'Allow'))
        $created=$false
        if ($PSVersionTable.PSEdition -eq 'Core') {
            $stop = [Threading.EventWaitHandleAcl]::Create($false, [Threading.EventResetMode]::ManualReset, $eventName, [ref]$created, $security)
        } else { $stop = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $eventName, [ref]$created, $security) }
        $healthFile = Join-Path $Root 'health.url'
        if (Test-Path -LiteralPath $healthFile) { Remove-Item -LiteralPath $healthFile -Force }
        $arguments = @('run','--control-plane.api-key','env:CONTROL_PLANE_API_KEY','--mcp.command',('command=' + $command + ',channel=main'), '--health.listen-addr','127.0.0.1:0','--health.url-file',$healthFile,'--log.level','warn','--admin-ui.log-buffer-events','1')
        $job = [VisibleChromeBridge.NativeJob]::new($exe, [string[]]$arguments, $payload, $environment)
        $environment.Clear()
        $current = Get-Process -Id $PID
        Write-BridgeJson (Join-Path $Root 'worker.json') @{ ProcessId=$PID; StartTicks=$current.StartTime.ToUniversalTime().Ticks.ToString(); StopEvent=$eventName }
        Write-BridgeJson (Join-Path $Root 'outcome.json') @{ Outcome='Started'; At=[DateTime]::UtcNow.ToString('o') }
        while ($job.IsRunning -and -not $stop.WaitOne(500)) { }
        Write-BridgeJson (Join-Path $Root 'outcome.json') @{ Outcome= $(if ($job.IsRunning) { 'Stopped' } else { 'UpstreamExited' }); At=[DateTime]::UtcNow.ToString('o') }
    }
    catch {
        Write-BridgeJson (Join-Path $Root 'outcome.json') @{ Outcome='StartupFailed'; At=[DateTime]::UtcNow.ToString('o') }
    }
    finally {
        if ($job) { $job.Dispose() }
        if ($stop) { $stop.Dispose() }
        if ($lifetime) {
            foreach ($name in @('worker.json','health.url')) { $path=Join-Path $Root $name; if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force } }
            $lifetime.Dispose()
        }
    }
}

function Start-Bridge {
    param([string]$Root)
    $state = Get-BridgeState $Root
    if (Test-BridgeLifetime $Root) { return Get-BridgeStatus $Root }
    if (-not (Test-Path -LiteralPath $state.NodePath -PathType Leaf)) { throw 'The pinned Node.js executable is missing. Reinstall with the intended Node.js version active.' }
    Initialize-BridgeNative
    $workerScript = Join-Path $Root 'app\src\Worker.ps1'
    Assert-BridgePath $workerScript
    $arguments = @('-NoLogo','-NoProfile','-NonInteractive','-WindowStyle','Hidden','-File',$workerScript,'-DataRoot',$Root)
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $info.Arguments = ($arguments | ForEach-Object { [VisibleChromeBridge.NativeJob]::QuoteArgument($_) }) -join ' '
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    # The worker does not need unrelated parent API keys in its environment either.
    $info.EnvironmentVariables.Clear()
    $environment = New-BridgeEnvironment
    foreach ($name in $environment.Keys) { $info.EnvironmentVariables[$name]=$environment[$name] }
    $process = [Diagnostics.Process]::Start($info)
    try {
        $deadline = [DateTime]::UtcNow.AddSeconds(35)
        do {
            Start-Sleep -Milliseconds 300
            $status = Get-BridgeStatus $Root
            if ($status.RuntimeReady) { return $status }
            if ($process.HasExited) { throw 'The worker could not start. Check execution policy, DPAPI user context, installed files, and outcome.json. No private logs were saved.' }
        } while ([DateTime]::UtcNow -lt $deadline)
        Write-Warning 'The worker is running but runtime readiness is pending. Check status again; readiness never proves Chrome consent or ChatGPT access.'
        return $status
    }
    finally { $process.Dispose() }
}

function Stop-Bridge {
    param([string]$Root)
    Assert-BridgeOwnedRoot $Root
    if (-not (Test-BridgeLifetime $Root)) { return }
    $worker = Get-BridgeWorkerState $Root
    if (-not $worker) { throw 'Worker ownership is not yet available. Retry after startup; no process will be killed by PID.' }
    $prefix = 'Local\' + (Get-BridgeIdentity $Root) + '-'
    if (-not $worker.StopEvent.StartsWith($prefix, [StringComparison]::Ordinal) -or $worker.StopEvent.Substring($prefix.Length) -notmatch '^[a-f0-9]{32}$') { throw 'Invalid stop signal identity. No processes were touched.' }
    try { $signal = [Threading.EventWaitHandle]::OpenExisting($worker.StopEvent) }
    catch { throw 'Stop signal is unavailable in this logon session. Stop the bridge from the session that started it.' }
    try { [void]$signal.Set() } finally { $signal.Dispose() }
    $deadline=[DateTime]::UtcNow.AddSeconds(15)
    while ((Test-BridgeLifetime $Root) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
    if (Test-BridgeLifetime $Root) { throw 'Worker has not exited. Update and uninstall remain blocked; Chrome was not touched.' }
}

function New-BridgePayload {
    param([string]$Root, [object]$Prerequisites, [object]$TunnelInfo, [object]$McpInfo)
    $directory = 'payloads\' + [guid]::NewGuid().ToString('N')
    $path = Get-BridgeChildPath $Root $directory
    $result = Install-BridgePayload -Destination $path -TunnelInfo $TunnelInfo -McpInfo $McpInfo -NpmPath $Prerequisites.NpmPath -NodePath $Prerequisites.NodePath
    $payload = [pscustomobject]@{ Directory=$directory; TunnelVersion=$result.TunnelVersion; McpVersion=$result.McpVersion; TunnelRelativePath=$result.TunnelRelativePath; McpRelativePath=$result.McpRelativePath }
    Assert-BridgePayloadCompatible $Root $payload $Prerequisites.NodePath
    return $payload
}

function Assert-BridgePayloadCompatible {
    param([string]$Root, [object]$Payload, [string]$NodePath)
    $directory = Get-BridgeChildPath $Root $Payload.Directory
    $exe = Get-BridgeChildPath $directory $Payload.TunnelRelativePath
    $entry = Get-BridgeChildPath $directory $Payload.McpRelativePath
    foreach ($file in @($exe,$entry,$NodePath)) { if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw 'A selected payload dependency is missing. Repair or choose a verified version.' } }
    # Help/version checks never start a tunnel or attach to Chrome. Clear ambient
    # NODE_OPTIONS and authentication/config overrides while invoking upstreams.
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    Initialize-BridgeNative
    foreach ($probe in @(
        @{Exe=$exe;Args=@('--version');Expected=[regex]::Escape($Payload.TunnelVersion)},
        @{Exe=$exe;Args=@('run','--help');Expected='--mcp.command'},
        @{Exe=$NodePath;Args=@($entry,'--version');Expected=[regex]::Escape($Payload.McpVersion)},
        @{Exe=$NodePath;Args=@($entry,'--help');Expected='--autoConnect'}
    )) {
        $info.FileName=$probe.Exe
        $info.Arguments=($probe.Args | ForEach-Object { [VisibleChromeBridge.NativeJob]::QuoteArgument($_) }) -join ' '
        $info.EnvironmentVariables.Clear()
        $envBlock=New-BridgeEnvironment
        foreach ($name in $envBlock.Keys) { $info.EnvironmentVariables[$name]=$envBlock[$name] }
        $info.EnvironmentVariables['CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS']='1'
        $info.EnvironmentVariables['CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS']='1'
        $process=[Diagnostics.Process]::Start($info)
        try {
            $stdout=$process.StandardOutput.ReadToEndAsync()
            $stderr=$process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(20000)) { $process.Kill(); throw 'Upstream compatibility check timed out.' }
            $text=$stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
            if ($process.ExitCode -ne 0 -or $text -notmatch $probe.Expected) { throw 'Upstream CLI compatibility check failed. The current version was retained.' }
            if ($probe.Exe -eq $exe -and $probe.Args[0] -eq 'run') {
                foreach ($flag in @('--health.listen-addr','--health.url-file','--control-plane.api-key','--admin-ui.log-buffer-events','--log.level')) {
                    if (-not $text.Contains($flag)) { throw 'The selected tunnel client is missing a required CLI option.' }
                }
            }
            if ($probe.Exe -eq $NodePath -and $probe.Args[-1] -eq '--help') {
                foreach ($flag in @('--no-usage-statistics','--no-performance-crux')) {
                    if (-not $text.Contains($flag)) { throw 'The selected MCP server is missing a required privacy option.' }
                }
            }
        } finally { $process.Dispose() }
    }
}

function Copy-BridgeApplication {
    param([string]$Root)
    $destination = Join-Path $Root 'app'
    if ([IO.Path]::GetFullPath($script:AppSource).TrimEnd('\').Equals($destination, [StringComparison]::OrdinalIgnoreCase)) { return }
    [void][IO.Directory]::CreateDirectory($destination)
    foreach ($name in @('Install-Windows.ps1','Start-Bridge.ps1','Stop-Bridge.ps1','Get-BridgeStatus.ps1','Check-Updates.ps1','Update-Bridge.ps1','Uninstall-Windows.ps1','LICENSE','THIRD-PARTY-NOTICES.md')) {
        Copy-Item -LiteralPath (Join-Path $script:AppSource $name) -Destination (Join-Path $destination $name) -Force
    }
    $src = Join-Path $destination 'src'
    [void][IO.Directory]::CreateDirectory($src)
    foreach ($name in @('Bridge.psm1','Packages.psm1','Worker.ps1','NativeJob.cs','mcp-launcher.cjs','validate-lock.cjs')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $src $name) -Force
    }
}

function Set-BridgeStartup {
    param([string]$Root, [bool]$Enabled, [string]$UpdatePolicy)
    Initialize-BridgeNative
    $identity = Get-BridgeIdentity $Root
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $command = [VisibleChromeBridge.NativeJob]::QuoteArgument($powershell) + ' ' + ((@('-NoLogo','-NoProfile','-NonInteractive','-WindowStyle','Hidden','-File',(Join-Path $Root 'app\Start-Bridge.ps1'),'-DataRoot',$Root) | ForEach-Object { [VisibleChromeBridge.NativeJob]::QuoteArgument($_) }) -join ' ')
    if ($Enabled) {
        if (-not (Test-Path $runKey)) { [void](New-Item -Path $runKey -Force) }
        Set-ItemProperty -LiteralPath $runKey -Name $identity -Value $command
    } else { Remove-ItemProperty -LiteralPath $runKey -Name $identity -ErrorAction SilentlyContinue }
    $taskName = $identity + '-Updates'
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($UpdatePolicy -eq 'Manual') {
        if ($existing) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
    } else {
        $arguments = (@('-NoLogo','-NoProfile','-NonInteractive','-WindowStyle','Hidden','-File',(Join-Path $Root 'app\Check-Updates.ps1'),'-DataRoot',$Root,'-Scheduled') | ForEach-Object { [VisibleChromeBridge.NativeJob]::QuoteArgument($_) }) -join ' '
        $action = New-ScheduledTaskAction -Execute $powershell -Argument $arguments
        $trigger = New-ScheduledTaskTrigger -Daily -At '12:00'
        $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
        [void](Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force)
    }
}

function Install-Bridge {
    param([string]$Root, [string]$TunnelVersion, [string]$McpVersion, [switch]$ReplaceCredentials, [switch]$StartAtLogon, [string]$UpdatePolicy='Manual', [switch]$PolicySpecified, [switch]$StartupSpecified)
    $prerequisites = Get-BridgePrerequisites
    Invoke-BridgeLocked $Root {
        if (Test-Path -LiteralPath $Root) {
            Assert-BridgeOwnedRoot $Root
            if (Test-BridgeLifetime $Root) { throw 'Stop this bridge before repairing its installation. Existing Chrome and other bridges are never stopped by installation.' }
        } else {
            [void][IO.Directory]::CreateDirectory($Root)
            Set-BridgePrivateAcl $Root
            Write-BridgeJson (Join-Path $Root 'owner.json') @{Product=$script:Marker;UserSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value}
        }
        $statePath = Join-Path $Root 'state.json'
        $state = if (Test-Path -LiteralPath $statePath) { Get-BridgeState $Root } else { $null }
        $needsPayload = -not $state
        if ($state -and (($TunnelVersion -and $TunnelVersion.TrimStart('v') -ne $state.Current.TunnelVersion) -or ($McpVersion -and $McpVersion -ne $state.Current.McpVersion))) { throw 'Use Update-Bridge.ps1 to change dependency versions.' }
        $credentialPath = Join-Path $Root 'credentials.dpapi'
        if (-not (Test-Path -LiteralPath $credentialPath) -or $ReplaceCredentials) {
            $tunnel = Read-Host 'Your personal OpenAI tunnel identifier (hidden)' -AsSecureString
            $apiKey = Read-Host 'Runtime API key with Tunnels Read + Use (hidden)' -AsSecureString
            try { Save-BridgeCredentials $Root $tunnel $apiKey } finally { $tunnel.Dispose(); $apiKey.Dispose() }
        }
        if ($needsPayload) {
            $tunnelInfo = Get-BridgeReleaseInfo -Version $TunnelVersion
            $mcpInfo = Get-BridgeMcpInfo -Version $McpVersion
            $payload = New-BridgePayload $Root $prerequisites $tunnelInfo $mcpInfo
            $state = [pscustomobject]@{Schema=1;NodePath=$prerequisites.NodePath;Current=$payload;Previous=$null;PreviousNodePath=$null;StartAtLogon=[bool]$StartAtLogon;UpdatePolicy=$UpdatePolicy}
        } else {
            Assert-BridgePayloadCompatible $Root $state.Current $prerequisites.NodePath
            $state.NodePath=$prerequisites.NodePath
            if ($PolicySpecified) { $state.UpdatePolicy=$UpdatePolicy }
            if ($StartupSpecified) { $state.StartAtLogon=[bool]$StartAtLogon }
        }
        Copy-BridgeApplication $Root
        Write-BridgeJson $statePath $state
        Set-BridgeStartup $Root $state.StartAtLogon $state.UpdatePolicy
        return [pscustomobject]@{Installed=$true;TunnelVersion=$state.Current.TunnelVersion;McpVersion=$state.Current.McpVersion;Started=$false;NextStep='Enable Chrome remote-debugging consent, then run Start-Bridge.ps1. See docs/CHATGPT-SETUP.md.'}
    }
}

function Get-BridgeUpdates {
    param([string]$Root)
    $state = Get-BridgeState $Root
    $tunnel = Get-BridgeReleaseInfo
    $mcp = Get-BridgeMcpInfo
    $result = [pscustomobject]@{CheckedAt=[DateTime]::UtcNow.ToString('o');TunnelInstalled=$state.Current.TunnelVersion;TunnelLatest=$tunnel.Version;TunnelUpdate=(Test-BridgeVersionNewer $tunnel.Version $state.Current.TunnelVersion);McpInstalled=$state.Current.McpVersion;McpLatest=$mcp.version;McpUpdate=(Test-BridgeVersionNewer $mcp.version $state.Current.McpVersion);Policy=$state.UpdatePolicy}
    Write-BridgeJson (Join-Path $Root 'updates.json') $result
    return $result
}

function Update-Bridge {
    param([string]$Root, [string]$TunnelVersion, [string]$McpVersion, [switch]$Rollback)
    $state = Get-BridgeState $Root
    if (Test-BridgeLifetime $Root) { throw 'Updates and rollback require a stopped bridge. Finish automation and explicitly stop it first.' }
    if ($Rollback) {
        if (-not $state.Previous) { throw 'No previous payload is available for rollback.' }
        Assert-BridgePayloadCompatible $Root $state.Previous $state.PreviousNodePath
        $previous = $state.Current; $state.Current=$state.Previous; $state.Previous=$previous
        $node=$state.NodePath; $state.NodePath=$state.PreviousNodePath; $state.PreviousNodePath=$node
    } else {
        $prerequisites = Get-BridgePrerequisites
        $tunnel = Get-BridgeReleaseInfo -Version $TunnelVersion
        $mcp = Get-BridgeMcpInfo -Version $McpVersion
        if ($tunnel.Version -eq $state.Current.TunnelVersion -and $mcp.version -eq $state.Current.McpVersion) { return [pscustomobject]@{Changed=$false;Reason='Already installed'} }
        $candidate = New-BridgePayload $Root $prerequisites $tunnel $mcp
        $state.Previous=$state.Current; $state.PreviousNodePath=$state.NodePath; $state.Current=$candidate; $state.NodePath=$prerequisites.NodePath
    }
    # Commit point: old payload remains intact until the complete candidate exists.
    Write-BridgeJson (Join-Path $Root 'state.json') $state
    return [pscustomobject]@{Changed=$true;TunnelVersion=$state.Current.TunnelVersion;McpVersion=$state.Current.McpVersion;Started=$false}
}

function Uninstall-Bridge {
    param([string]$Root, [switch]$RemoveData)
    Assert-BridgeOwnedRoot $Root
    Stop-Bridge $Root
    Set-BridgeStartup $Root $false 'Manual'
    # Deletion is done after the caller releases operation.lock.
    return [pscustomobject]@{StartupRemoved=$true;DataRetained=(-not $RemoveData);RemoveData=[bool]$RemoveData}
}

function Remove-BridgeOwnedData {
    param([string]$Root)
    Assert-BridgeOwnedRoot $Root
    if (Test-BridgeLifetime $Root) { throw 'Data cannot be removed while a worker is running.' }
    $children = @(Get-ChildItem -LiteralPath $Root -Recurse -Force)
    if (@($children | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Data deletion refused because a reparse point is present.' }
    $resolved = [IO.Path]::GetFullPath($Root)
    if ($resolved -ne $Root -or $resolved.Length -lt 8) { throw 'Data deletion target failed validation.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

Export-ModuleMember -Function *-Bridge*
