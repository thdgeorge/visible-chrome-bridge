#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PayloadRoot)
# Run only after Install-BridgePayload has verified this payload. No real key,
# external control plane, Chrome instance, or existing installation is used.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $repo 'src\Bridge.psm1') -Force
Initialize-BridgeNative
$pre=Get-BridgePrerequisites
$exe=Join-Path $PayloadRoot 'tunnel\tunnel-client.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Pass a previously verified temporary payload root.' }
$tempBase=[IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$root=Join-Path $tempBase ("VCB upstream smoke's spaced root "+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
$control=$null; $tunnel=$null
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures\offline-mcp.cjs') -Destination (Join-Path $root 'offline-mcp.cjs')
    $environment=New-BridgeEnvironment
    $control=[VisibleChromeBridge.NativeJob]::new($pre.NodePath,[string[]]@((Join-Path $PSScriptRoot 'fixtures\offline-control.cjs'),$root),$root,$environment)
    $deadline=[DateTime]::UtcNow.AddSeconds(10)
    while (-not (Test-Path -LiteralPath (Join-Path $root 'control.url'))) { if ([DateTime]::UtcNow -gt $deadline) { throw 'Offline control did not start.' };Start-Sleep -Milliseconds 100 }
    $url=[IO.File]::ReadAllText((Join-Path $root 'control.url'))
    if ($url -notmatch '^http://127\.0\.0\.1:[0-9]+$') { throw 'Test control must be loopback only.' }
    $environment['CONTROL_PLANE_API_KEY']='synthetic-offline-test-key-never-real'
    $environment['CONTROL_PLANE_TUNNEL_ID']='tunnel_00000000000000000000000000000000'
    $command=ConvertTo-BridgeCommand @($pre.NodePath,(Join-Path $repo 'src\mcp-launcher.cjs'),(Join-Path $root 'offline-mcp.cjs'))
    $arguments=@('run','--control-plane.base-url',$url,'--control-plane.api-key','env:CONTROL_PLANE_API_KEY','--mcp.command',('command='+$command+',channel=main'),'--health.listen-addr','127.0.0.1:0','--health.url-file',(Join-Path $root 'health.url'),'--log.level','warn','--log.format','struct-text','--admin-ui.log-buffer-events','1')
    $tunnel=[VisibleChromeBridge.NativeJob]::new($exe,[string[]]$arguments,$root,$environment)
    $deadline=[DateTime]::UtcNow.AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 200
        $stdio=Test-Path -LiteralPath (Join-Path $root 'stdio-observed.json')
        $poll=Test-Path -LiteralPath (Join-Path $root 'response-observed')
    } while ((-not $stdio -or -not $poll) -and $tunnel.IsRunning -and [DateTime]::UtcNow -lt $deadline)
    if (-not $stdio -or -not $poll) {
        throw ('Official tunnel fixture incomplete: stdio='+$stdio+' poll='+$poll+' running='+$tunnel.IsRunning+' healthFile='+(Test-Path -LiteralPath (Join-Path $root 'health.url')))
    }
    $evidence=Read-BridgeJson (Join-Path $root 'stdio-observed.json')
    if (-not $evidence.initialized -or $evidence.secretPresent -or -not $evidence.autoConnectFlag) { throw 'Offline stdio environment/argument checks failed.' }
    $responseEvidence=Read-BridgeJson (Join-Path $root 'response-observed')
    if (-not $responseEvidence.hasResponse) { throw 'The tunnel did not post a JSON-RPC result to the offline control.' }
    $health=Get-BridgeHealth $root
    if (-not $health.Healthy -or -not $health.RuntimeReady) { throw 'Official local runtime readiness failed against fixtures.' }
    Write-Output 'PASS official tunnel stdio initialization, actual command parser, loopback control, privacy environment, and health with offline fixtures.'
    Write-Output 'UNVERIFIED real OpenAI authentication, Chrome attachment/consent, ChatGPT discovery/tool use.'
}
finally {
    if ($tunnel) {$tunnel.Dispose()}; if ($control) {$control.Dispose()}
    if ([IO.Path]::GetFullPath($root).StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $root -Leaf) -like 'VCB upstream smoke*') {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
