#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $repo 'src\Bridge.psm1') -Force
Import-Module (Join-Path $repo 'src\Packages.psm1') -Force
Initialize-BridgeNative
$bridgeModule=Get-Module Bridge
$packagesModule=Get-Module Packages | Select-Object -First 1
$fixture=Join-Path $PSScriptRoot 'fixtures\process.cjs'
$node=(Get-Command node.exe -CommandType Application | Select-Object -First 1).Source
$tempBase=[IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$testRoot=Join-Path $tempBase ("VCB tests with spaces and apostrophe's " + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$script:passed=0
$script:failed=0

function Assert-True { param([bool]$Value,[string]$Message='Assertion failed'); if (-not $Value) { throw $Message } }
function Assert-Throws { param([scriptblock]$Action); $threw=$false; try { & $Action | Out-Null } catch { $threw=$true }; Assert-True $threw 'Expected failure was not raised' }
function Test-Case {
    param([string]$Name,[scriptblock]$Action)
    try { & $Action; $script:passed++; Write-Output ('PASS ' + $Name) }
    catch { $script:failed++; Write-Output ('FAIL ' + $Name + ': ' + $_.Exception.Message) }
}
function Wait-TestFile {
    param([string]$Path)
    $deadline=[DateTime]::UtcNow.AddSeconds(10)
    while (-not (Test-Path -LiteralPath $Path)) { if ([DateTime]::UtcNow -gt $deadline) { throw 'Fixture did not become ready' }; Start-Sleep -Milliseconds 100 }
    Start-Sleep -Milliseconds 100
}
function New-TestOwnedRoot {
    param([string]$Name)
    $root=Join-Path $testRoot $Name
    [void][IO.Directory]::CreateDirectory($root)
    Set-BridgePrivateAcl $root
    Write-BridgeJson (Join-Path $root 'owner.json') @{Product='visible-chrome-bridge-v1';UserSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value}
    return $root
}

try {
    Test-Case 'All PowerShell sources parse' {
        foreach ($file in Get-ChildItem -LiteralPath $repo -Recurse -File | Where-Object Extension -in @('.ps1','.psm1')) {
            $parseErrors=$null
            [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$null,[ref]$parseErrors)
            Assert-True ($parseErrors.Count -eq 0) ('Parse error in ' + $file.Name)
        }
    }
    Test-Case 'Stable semantic versions select numerically and reject prereleases/ranges' {
        Assert-True (Test-BridgeVersionNewer '0.0.17' '0.0.9')
        Assert-True (-not (Test-BridgeVersionNewer '1.2.3' '1.2.3'))
        Assert-True (-not (Test-BridgeVersionNewer '1.2.3' '2.0.0'))
        foreach ($value in @('latest','1.2.3-beta','^1.2.3','01.2.3','v1.2.3','1.2')) { Assert-Throws { Test-BridgeVersionNewer $value '1.0.0' } }
    }
    Test-Case 'Untrusted download URLs and malformed digests fail before network' {
        Assert-Throws { Save-BridgeVerifiedDownload 'http://github.com/openai/tunnel-client/x.zip' (Join-Path $testRoot 'bad.zip') ('0'*64) }
        Assert-Throws { Save-BridgeVerifiedDownload 'https://evil.example/download.zip' (Join-Path $testRoot 'bad.zip') ('0'*64) }
        Assert-Throws { Save-BridgeVerifiedDownload 'https://github.com/openai/tunnel-client/releases/download/v0.0.17/tunnel-client-v0.0.17-windows-amd64.zip' (Join-Path $testRoot 'bad.zip') 'bad' }
    }
    Test-Case 'Windows native argv survives spaces quotes empty strings and trailing slashes' {
        $output=Join-Path $testRoot 'argv.json'
        $expected=@('','hello world',"apostrophe's",'a"quote','C:\trailing path\','x\"y','& $() ; |')
        $job=[VisibleChromeBridge.NativeJob]::new($node,[string[]](@($fixture,'argv',$output)+$expected),$testRoot,(New-BridgeEnvironment))
        try {
            Wait-TestFile $output
            $actual=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
            Assert-True ($actual.Count -eq $expected.Count) 'Native argv count mismatch'
            for ($index=0; $index -lt $expected.Count; $index++) { Assert-True ($actual[$index] -ceq $expected[$index]) ('Native argv mismatch at '+$index) }
        } finally { $job.Dispose() }
    }
    Test-Case 'Inner upstream command quoting preserves Windows paths with spaces/apostrophes' {
        $command=ConvertTo-BridgeCommand @('C:\Program Files\node.exe',"C:\User's Files\file.js")
        Assert-True ($command -ceq '"C:/Program Files/node.exe" "C:/User''s Files/file.js"')
        Assert-Throws { ConvertTo-BridgeCommand @('C:\bad,path\file') }
    }
    Test-Case 'Storage ownership rejects checkout, traversal, unknown root and junction' {
        Assert-Throws { Get-BridgeRoot $repo }
        Assert-Throws { Get-BridgeRoot (Join-Path $repo 'private') }
        Assert-Throws { Get-BridgeChildPath $testRoot '..\escape' }
        Assert-Throws { Assert-BridgeOwnedRoot $testRoot }
        $target=Join-Path $testRoot 'junction target'; [void][IO.Directory]::CreateDirectory($target)
        $junction=Join-Path $testRoot 'junction'
        [void](New-Item -ItemType Junction -Path $junction -Target $target)
        try { Assert-Throws { Get-BridgeRoot (Join-Path $junction 'child') } }
        finally { [IO.Directory]::Delete($junction) }
    }
    Test-Case 'Current-user DPAPI roundtrip and private ACL contain no plaintext synthetic credentials' {
        $root=New-TestOwnedRoot 'credential fixture'
        $id=ConvertTo-SecureString ('tunnel_'+('0'*32)) -AsPlainText -Force
        $key=ConvertTo-SecureString 'synthetic-fixture-key-never-real' -AsPlainText -Force
        try { Save-BridgeCredentials $root $id $key } finally { $id.Dispose();$key.Dispose() }
        $raw=Get-Content -LiteralPath (Join-Path $root 'credentials.dpapi') -Raw
        Assert-True (-not $raw.Contains('synthetic'))
        $saved=Read-BridgeJson (Join-Path $root 'credentials.dpapi')
        $secure=ConvertTo-SecureString $saved.ApiKey
        $bstr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { Assert-True ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) -ceq 'synthetic-fixture-key-never-real') }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr);$secure.Dispose() }
        $acl=Get-Acl -LiteralPath $root
        Assert-True $acl.AreAccessRulesProtected
        Assert-True (@($acl.Access).Count -eq 2)
    }
    Test-Case 'MCP launcher strips inherited secrets and keeps privacy flags' {
        $output=Join-Path $testRoot 'environment.json'
        $fakeEntry=Join-Path $testRoot 'fake entry.cjs'
        # The launcher supplies flags only. This fixture records no environment values.
        $source="const fs=require('node:fs');fs.writeFileSync(" + ($output | ConvertTo-Json -Compress) + ",JSON.stringify({secretPresent:Object.keys(process.env).some(k=>/^(OPENAI_|CONTROL_PLANE_|TUNNEL_CLIENT_|NODE_OPTIONS)/i.test(k)),privacy:process.env.CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS==='1',updateCheckDisabled:process.env.CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS==='1',args:process.argv.slice(2)}));"
        [IO.File]::WriteAllText($fakeEntry,$source)
        $environment=New-BridgeEnvironment
        $environment['CONTROL_PLANE_API_KEY']='synthetic-never-real'
        $environment['OPENAI_UNRELATED_SECRET']='synthetic-never-real'
        $environment['TUNNEL_CLIENT_PROFILE']='synthetic'
        $job=[VisibleChromeBridge.NativeJob]::new($node,[string[]]@((Join-Path $repo 'src\mcp-launcher.cjs'),$fakeEntry),$testRoot,$environment)
        try {
            Wait-TestFile $output
            $actual=Read-BridgeJson $output
            Assert-True (-not $actual.secretPresent)
            Assert-True ($actual.privacy -and $actual.updateCheckDisabled)
            Assert-True ($actual.args -contains '--autoConnect')
            Assert-True ($actual.args -contains '--no-performance-crux')
        } finally { $job.Dispose() }
    }
    Test-Case 'Job close kills descendants and preserves an unrelated sentinel process' {
        $output=Join-Path $testRoot 'tree.json'
        $sentinelInfo=[Diagnostics.ProcessStartInfo]::new()
        $sentinelInfo.FileName=$node
        $sentinelInfo.Arguments=([VisibleChromeBridge.NativeJob]::QuoteArgument($fixture)) + ' idle'
        $sentinelInfo.UseShellExecute=$false;$sentinelInfo.CreateNoWindow=$true
        $sentinel=[Diagnostics.Process]::Start($sentinelInfo)
        $job=$null
        try {
            $job=[VisibleChromeBridge.NativeJob]::new($node,[string[]]@($fixture,'tree',$output),$testRoot,(New-BridgeEnvironment))
            Wait-TestFile $output
            $tree=Read-BridgeJson $output
            Assert-True ([bool](Get-Process -Id $tree.child -ErrorAction SilentlyContinue))
            $job.Dispose()
            $deadline=[DateTime]::UtcNow.AddSeconds(5)
            while ((Get-Process -Id $tree.child -ErrorAction SilentlyContinue) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
            Assert-True (-not (Get-Process -Id $tree.child -ErrorAction SilentlyContinue))
            Assert-True (-not $sentinel.HasExited)
        } finally { if ($job) {$job.Dispose()}; if (-not $sentinel.HasExited) { $sentinel.Kill() };$sentinel.Dispose() }
    }
    Test-Case 'Atomic state replacement produces valid JSON and leaves no temporary file' {
        $path=Join-Path $testRoot 'atomic.json'
        Write-BridgeJson $path @{Schema=1;Value='first'}
        Write-BridgeJson $path @{Schema=1;Value='second'}
        Assert-True ((Read-BridgeJson $path).Value -ceq 'second')
        Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Filter '*.tmp').Count -eq 0)
    }
    Test-Case 'Corrupt archives and ZIP traversal are rejected before extraction' {
        Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
        $zipPath=Join-Path $testRoot 'unsafe.zip'
        $zip=[IO.Compression.ZipFile]::Open($zipPath,[IO.Compression.ZipArchiveMode]::Create)
        try { [void]$zip.CreateEntry('../escaped.txt') } finally { $zip.Dispose() }
        Assert-Throws { & $packagesModule { param($a,$b) Expand-BridgeSafeArchive $a $b } $zipPath (Join-Path $testRoot 'unsafe output') }
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $testRoot 'escaped.txt')))
        $bad=Join-Path $testRoot 'corrupt.zip';[IO.File]::WriteAllText($bad,'not a zip')
        Assert-Throws { & $packagesModule { param($a,$b) Expand-BridgeSafeArchive $a $b } $bad (Join-Path $testRoot 'bad output') }
    }
    Test-Case 'Official npm lock accepts empty root key and rejects forged dependency origin' {
        $path=Join-Path $testRoot 'package-lock.json'
        $integrity='sha512-'+('A'*86)+'=='
        $metadata=[pscustomobject]@{Version='1.2.3';Uri='https://registry.npmjs.org/chrome-devtools-mcp/-/chrome-devtools-mcp-1.2.3.tgz';Integrity=$integrity}
        $lock=@{lockfileVersion=3;packages=@{''=@{name='fixture'};'node_modules/chrome-devtools-mcp'=@{version='1.2.3';resolved=$metadata.Uri;integrity=$integrity}}}
        Write-BridgeJson $path $lock
        & $packagesModule {param($p,$m,$n) Assert-BridgeOfficialLock $p $m $n} $path $metadata $node
        $lock.packages['node_modules/chrome-devtools-mcp'].resolved='https://evil.example/package.tgz'
        Write-BridgeJson $path $lock
        Assert-Throws { & $packagesModule {param($p,$m,$n) Assert-BridgeOfficialLock $p $m $n} $path $metadata $node }
    }
    Test-Case 'PID reuse cannot authorize stopping an unrelated process' {
        $root=New-TestOwnedRoot 'pid fixture'
        Write-BridgeJson (Join-Path $root 'worker.json') @{ProcessId=$PID;StartTicks='1';StopEvent='invalid'}
        Assert-True ($null -eq (Get-BridgeWorkerState $root))
    }
    Test-Case 'Offline worker start readiness duplicate-start stop and running-update guard' {
        $root=New-TestOwnedRoot 'worker lifecycle'
        Copy-BridgeApplication $root
        $payload=Join-Path $root 'payloads\fixture';[void][IO.Directory]::CreateDirectory($payload)
        $exe=Join-Path $payload 'fake-tunnel.exe'
        # Windows PowerShell provides the in-box C# compiler on both test shells.
        $compile=Join-Path $testRoot 'compile.ps1'
        $cs=(Join-Path $PSScriptRoot 'fixtures\FakeTunnel.cs').Replace("'","''")
        $dest=$exe.Replace("'","''")
        [IO.File]::WriteAllText($compile,"Add-Type -Path '$cs' -OutputAssembly '$dest' -OutputType ConsoleApplication")
        & (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -NoProfile -NonInteractive -File $compile
        Assert-True (Test-Path -LiteralPath $exe)
        $id=ConvertTo-SecureString ('tunnel_'+('0'*32)) -AsPlainText -Force
        $key=ConvertTo-SecureString 'synthetic-fixture-key-never-real' -AsPlainText -Force
        try { Save-BridgeCredentials $root $id $key } finally {$id.Dispose();$key.Dispose()}
        Write-BridgeJson (Join-Path $root 'state.json') @{Schema=1;NodePath=$node;Current=@{Directory='payloads\fixture';TunnelVersion='0.0.0';McpVersion='0.0.0';TunnelRelativePath='fake-tunnel.exe';McpRelativePath='unused.cjs'};Previous=$null;PreviousNodePath=$null;StartAtLogon=$false;UpdatePolicy='Manual'}
        try {
            $status=Invoke-BridgeLocked $root { Start-Bridge $root }
            Assert-True ($status.Running -and $status.RuntimeReady -and -not $status.BrowserVerified)
            $worker=Get-BridgeWorkerState $root
            [void](Invoke-BridgeLocked $root { Start-Bridge $root })
            Assert-True ((Get-BridgeWorkerState $root).ProcessId -eq $worker.ProcessId)
            $started=Read-BridgeJson (Join-Path $root 'fake-started.json')
            Assert-True $started.hasKey
            Assert-True (-not $started.ambientSecret)
            Assert-Throws { Invoke-BridgeLocked $root { Update-Bridge $root -Rollback } }
            Invoke-BridgeLocked $root { Stop-Bridge $root }
            Assert-True (-not (Test-BridgeLifetime $root))
            Assert-True (-not (Get-Process -Id $started.pid -ErrorAction SilentlyContinue))
        } finally { if (Test-BridgeLifetime $root) { Stop-Bridge $root } }
    }
    Test-Case 'Installer idempotency and failed update preserve credentials and active pointer (offline mocks)' {
        $root=New-TestOwnedRoot 'transaction fixture'
        & $bridgeModule {
            param($r,$n)
            # All external effects in this scenario are stubbed inside module scope.
            $originals=@{}
            foreach ($name in @('Get-BridgePrerequisites','Copy-BridgeApplication','Set-BridgeStartup','New-BridgePayload','Assert-BridgePayloadCompatible','Get-BridgeReleaseInfo','Get-BridgeMcpInfo')) { $originals[$name]=(Get-Item ('Function:\'+$name)).ScriptBlock }
            try {
                Set-Item Function:\Get-BridgePrerequisites { [pscustomobject]@{NodePath=$n;NpmPath='fixture'} }
                Set-Item Function:\Copy-BridgeApplication {param($Root)}
                Set-Item Function:\Set-BridgeStartup {param($Root,$Enabled,$UpdatePolicy)}
                Set-Item Function:\Get-BridgeReleaseInfo {param($Version) [pscustomobject]@{Version='0.0.2'} }
                Set-Item Function:\Get-BridgeMcpInfo {param($Version) [pscustomobject]@{Version='1.0.1'} }
                Set-Item Function:\Assert-BridgePayloadCompatible {param($Root,$Payload,$NodePath)}
                $state=@{Schema=1;NodePath=$n;Current=@{Directory='payloads\one';TunnelVersion='0.0.1';McpVersion='1.0.0'};Previous=$null;PreviousNodePath=$null;StartAtLogon=$true;UpdatePolicy='Notify'}
                Write-BridgeJson (Join-Path $r 'state.json') $state
                Write-BridgeJson (Join-Path $r 'credentials.dpapi') @{Fixture='preserve exactly'}
                $before=(Get-FileHash -LiteralPath (Join-Path $r 'credentials.dpapi')).Hash
                Set-Item Function:\Assert-BridgePayloadCompatible {param($Root,$Payload,$NodePath) throw 'synthetic incompatible Node repair'}
                $stateBefore=(Get-FileHash -LiteralPath (Join-Path $r 'state.json')).Hash
                $repairFailed=$false
                try { [void](Install-Bridge -Root $r) } catch { $repairFailed=$true }
                if (-not $repairFailed -or (Get-FileHash -LiteralPath (Join-Path $r 'state.json')).Hash -ne $stateBefore) { throw 'Incompatible repair changed active state' }
                Set-Item Function:\Assert-BridgePayloadCompatible {param($Root,$Payload,$NodePath)}
                [void](Install-Bridge -Root $r)
                [void](Install-Bridge -Root $r)
                $after=Get-BridgeState $r
                if (-not $after.StartAtLogon -or $after.UpdatePolicy -ne 'Notify') { throw 'Preferences changed on rerun' }
                if ((Get-FileHash -LiteralPath (Join-Path $r 'credentials.dpapi')).Hash -ne $before) { throw 'Credentials changed on rerun' }
                Set-Item Function:\New-BridgePayload {param($Root,$Prerequisites,$TunnelInfo,$McpInfo) throw 'synthetic staging failure'}
                $hash=(Get-FileHash -LiteralPath (Join-Path $r 'state.json')).Hash
                $failed=$false
                try { [void](Update-Bridge $r) } catch { $failed=$true }
                if (-not $failed -or (Get-FileHash -LiteralPath (Join-Path $r 'state.json')).Hash -ne $hash) { throw 'Failed update changed active state' }
                Set-Item Function:\New-BridgePayload {param($Root,$Prerequisites,$TunnelInfo,$McpInfo) [pscustomobject]@{Directory='payloads\two';TunnelVersion='0.0.2';McpVersion='1.0.1'} }
                [void](Update-Bridge $r)
                if ((Get-BridgeState $r).Current.TunnelVersion -ne '0.0.2') { throw 'Update was not activated' }
                [void](Update-Bridge $r -Rollback)
                if ((Get-BridgeState $r).Current.TunnelVersion -ne '0.0.1') { throw 'Rollback failed' }
            } finally { foreach ($name in $originals.Keys) { Set-Item ('Function:\'+$name) $originals[$name] } }
        } $root $node
    }
    Test-Case 'Missing dependencies give an actionable error before installation mutation' {
        & $bridgeModule {
            $saved=(Get-Item Function:\Get-Command -ErrorAction SilentlyContinue)
            try {
                function Get-Command {param($Name,$CommandType,$ErrorAction) return $null}
                $failed=$false
                try { [void](Get-BridgePrerequisites) } catch { $failed=$_.Exception.Message -match 'Node.js LTS' }
                if (-not $failed) { throw 'Missing Node/npm diagnostic was not actionable' }
            } finally { if ($saved) { Set-Item Function:\Get-Command $saved.ScriptBlock } else { Remove-Item Function:\Get-Command -ErrorAction SilentlyContinue } }
        }
    }
}
finally {
    # Exact fixture root only, after all owned workers/jobs have been stopped.
    $resolved=[IO.Path]::GetFullPath($testRoot)
    if ($resolved.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'VCB tests with spaces*') {
        $links=@(Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
        if ($links.Count -eq 0) { Remove-Item -LiteralPath $resolved -Recurse -Force }
        else { Write-Warning 'Fixture contains a link; guarded cleanup skipped.' }
    }
}
Write-Output ('Tests: '+$script:passed+' passed, '+$script:failed+' failed; shell '+$PSVersionTable.PSVersion)
if ($script:failed -gt 0) { exit 1 }
