#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Destination=(Join-Path $env:TEMP ('VCB verified test payload '+[guid]::NewGuid().ToString('N'))),
    [string]$TunnelVersion='0.0.17',
    [string]$McpVersion='1.11.0'
)
# Explicit online test: downloads official packages, executes version/help only.
# Does not install credentials, startup entries, or a real bridge instance.
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $repo 'src\Bridge.psm1') -Force
$pre=Get-BridgePrerequisites
$destinationPath=[IO.Path]::GetFullPath($Destination).TrimEnd('\')
$result=Install-BridgePayload -Destination $destinationPath -TunnelInfo (Get-BridgeReleaseInfo -Version $TunnelVersion) -McpInfo (Get-BridgeMcpInfo -Version $McpVersion) -NpmPath $pre.NpmPath -NodePath $pre.NodePath
$probe=[pscustomobject]@{Directory=(Split-Path $destinationPath -Leaf);TunnelVersion=$result.TunnelVersion;McpVersion=$result.McpVersion;TunnelRelativePath=$result.TunnelRelativePath;McpRelativePath=$result.McpRelativePath}
Assert-BridgePayloadCompatible (Split-Path $destinationPath -Parent) $probe $pre.NodePath
$result | Add-Member -NotePropertyName PayloadRoot -NotePropertyValue $destinationPath -PassThru
