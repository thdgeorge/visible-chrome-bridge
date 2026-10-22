#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$DataRoot,
    [string]$TunnelVersion,
    [string]$McpVersion,
    [switch]$ReplaceCredentials,
    [switch]$StartAtLogon,
    [ValidateSet('Manual','Notify','Unattended')][string]$UpdatePolicy='Manual'
)
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'src\Bridge.psm1') -Force
    $root=Get-BridgeRoot $DataRoot
    Install-Bridge -Root $root -TunnelVersion $TunnelVersion -McpVersion $McpVersion -ReplaceCredentials:$ReplaceCredentials -StartAtLogon:$StartAtLogon -UpdatePolicy $UpdatePolicy -PolicySpecified:($PSBoundParameters.ContainsKey('UpdatePolicy')) -StartupSpecified:($PSBoundParameters.ContainsKey('StartAtLogon'))
} catch { Write-Error ('Installation failed: ' + $_.Exception.Message); exit 1 }
