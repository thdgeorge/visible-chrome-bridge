#requires -Version 5.1
[CmdletBinding()]
param([string]$DataRoot, [string]$TunnelVersion, [string]$McpVersion, [switch]$Rollback)
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'src\Bridge.psm1') -Force
    $root=Get-BridgeRoot $DataRoot
    if ($Rollback -and ($TunnelVersion -or $McpVersion)) { throw 'Rollback cannot be combined with version selection.' }
    Invoke-BridgeLocked $root { Update-Bridge -Root $root -TunnelVersion $TunnelVersion -McpVersion $McpVersion -Rollback:$Rollback }
} catch { Write-Error ('Update failed: ' + $_.Exception.Message); exit 1 }
