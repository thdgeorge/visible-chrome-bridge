Set-StrictMode -Version Latest

function Assert-BridgeStableVersion {
    param([Parameter(Mandatory = $true)][string]$Version)
    if ($Version -cnotmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
        throw 'A stable upstream version in major.minor.patch form is required.'
    }
}

function Test-BridgeVersionNewer {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Candidate, [Parameter(Mandatory = $true)][string]$Current)
    Assert-BridgeStableVersion $Candidate
    Assert-BridgeStableVersion $Current
    $left = $Candidate.Split('.')
    $right = $Current.Split('.')
    for ($i = 0; $i -lt 3; $i++) {
        # Compare arbitrary-length semver components without integer overflow.
        if ($left[$i].Length -ne $right[$i].Length) { return $left[$i].Length -gt $right[$i].Length }
        $comparison = [string]::CompareOrdinal($left[$i], $right[$i])
        if ($comparison -ne 0) { return $comparison -gt 0 }
    }
    return $false
}

function Test-BridgeTrustedDownloadUri {
    param([Parameter(Mandatory = $true)][uri]$Uri)
    if (-not $Uri.IsAbsoluteUri -or $Uri.Scheme -cne 'https' -or -not $Uri.IsDefaultPort -or
        $Uri.UserInfo -or $Uri.Query -or $Uri.Fragment) { return $false }
    if ($Uri.Host -ceq 'github.com') {
        return $Uri.AbsolutePath -cmatch '^/openai/tunnel-client/releases/download/v(?<version>(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))/tunnel-client-v\k<version>-windows-amd64(?:\.zip|-licenses\.txt)$'
    }
    if ($Uri.Host -ceq 'registry.npmjs.org') {
        return $Uri.AbsolutePath -cmatch '^/(?:@[a-z0-9._-]+/)?[a-z0-9._-]+/-/[a-zA-Z0-9._-]+\.tgz$'
    }
    return $false
}

function Get-BridgeReleaseInfo {
    [CmdletBinding()]
    param([string]$Version)
    if ($Version) { Assert-BridgeStableVersion $Version; $suffix = 'tags/v' + $Version }
    else { $suffix = 'latest' }
    try {
        $release = Invoke-RestMethod -Uri ('https://api.github.com/repos/openai/tunnel-client/releases/' + $suffix) `
            -Headers @{ 'User-Agent' = 'VisibleChromeBridge'; 'Accept' = 'application/vnd.github+json' } -ErrorAction Stop
        if ($release.draft -or $release.prerelease -or $release.tag_name -cnotmatch '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
            throw 'Invalid release.'
        }
        $resolved = $release.tag_name.Substring(1)
        if ($Version -and $resolved -cne $Version) { throw 'Unexpected version.' }
        $assetName = 'tunnel-client-v' + $resolved + '-windows-amd64.zip'
        $assets = @($release.assets | Where-Object { $_.name -ceq $assetName })
        if ($assets.Count -ne 1 -or $assets[0].digest -cnotmatch '^sha256:[a-fA-F0-9]{64}$') { throw 'Missing digest.' }
        $uri = [uri]$assets[0].browser_download_url
        $expected = 'https://github.com/openai/tunnel-client/releases/download/v' + $resolved + '/' + $assetName
        if ($uri.AbsoluteUri -cne $expected -or -not (Test-BridgeTrustedDownloadUri $uri)) { throw 'Untrusted asset.' }
        $licenseName = 'tunnel-client-v' + $resolved + '-windows-amd64-licenses.txt'
        $licenses = @($release.assets | Where-Object { $_.name -ceq $licenseName })
        $licenseUri = 'https://github.com/openai/tunnel-client/releases/download/v' + $resolved + '/' + $licenseName
        if ($licenses.Count -ne 1 -or $licenses[0].digest -cnotmatch '^sha256:[a-fA-F0-9]{64}$' -or
            $licenses[0].browser_download_url -cne $licenseUri) { throw 'Missing verified license notice.' }
        return [pscustomobject]@{ Version = $resolved; Uri = $uri.AbsoluteUri; Sha256 = $assets[0].digest.Substring(7).ToLowerInvariant(); AssetName = $assetName; LicenseUri = $licenseUri; LicenseSha256 = $licenses[0].digest.Substring(7).ToLowerInvariant() }
    }
    catch { throw 'Could not verify the official stable tunnel-client release and its SHA-256 metadata. Check network access or choose an available stable version.' }
}

function Get-BridgeMcpInfo {
    [CmdletBinding()]
    param([string]$Version)
    if ($Version) { Assert-BridgeStableVersion $Version; $suffix = $Version }
    else { $suffix = 'latest' }
    try {
        $package = Invoke-RestMethod -Uri ('https://registry.npmjs.org/chrome-devtools-mcp/' + $suffix) -ErrorAction Stop
        Assert-BridgeStableVersion $package.version
        if ($package.name -cne 'chrome-devtools-mcp' -or ($Version -and $package.version -cne $Version)) { throw 'Unexpected package.' }
        $expected = 'https://registry.npmjs.org/chrome-devtools-mcp/-/chrome-devtools-mcp-' + $package.version + '.tgz'
        if ($package.dist.tarball -cne $expected -or $package.dist.integrity -cnotmatch '^sha512-[A-Za-z0-9+/]{86}==$') { throw 'Missing integrity.' }
        return [pscustomobject]@{ Version = $package.version; Uri = $package.dist.tarball; Integrity = $package.dist.integrity }
    }
    catch { throw 'Could not verify the official stable chrome-devtools-mcp package and its integrity metadata. Check network access or choose an available stable version.' }
}

function Save-BridgeVerifiedDownload {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][uri]$Uri, [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Sha256)
    if (-not (Test-BridgeTrustedDownloadUri $Uri)) { throw 'The download URL is not an approved official upstream asset.' }
    if ($Sha256 -cnotmatch '^[a-fA-F0-9]{64}$') { throw 'The upstream SHA-256 digest is missing or invalid.' }
    if ($Path -notmatch '^[a-zA-Z]:[\\/]' -or (Test-Path -LiteralPath $Path)) { throw 'The download requires a new absolute local file path.' }
    $created = $false
    try {
        # Explicit redirects prevent HTTPS downgrade or an unexpected download host.
        $next = $Uri
        for ($redirect = 0; $redirect -le 5; $redirect++) {
            $request = [Net.HttpWebRequest]::Create($next)
            $request.AllowAutoRedirect = $false
            $request.UserAgent = 'VisibleChromeBridge'
            $request.Timeout = 120000
            $request.ReadWriteTimeout = 120000
            $response = $null
            try {
                $response = $request.GetResponse()
                $status = [int]$response.StatusCode
                if ($status -in @(301, 302, 303, 307, 308)) {
                    if ($redirect -eq 5) { throw 'Too many redirects.' }
                    $next = [uri]::new($next, [string]$response.Headers['Location'])
                    if ($next.Scheme -cne 'https' -or -not $next.IsDefaultPort -or $next.UserInfo -or
                        $next.Host -cnotin @('github.com', 'release-assets.githubusercontent.com', 'objects.githubusercontent.com', 'registry.npmjs.org')) {
                        throw 'Untrusted redirect.'
                    }
                    continue
                }
                if ($status -ne 200) { throw 'Download failed.' }
                $file = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                $created = $true
                try { $response.GetResponseStream().CopyTo($file) } finally { $file.Dispose() }
                break
            }
            finally { if ($null -ne $response) { $response.Dispose() } }
        }
        if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash -ine $Sha256) { throw 'Digest mismatch.' }
    }
    catch {
        if ($created -and (Test-Path -LiteralPath $Path)) { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue }
        throw 'The upstream download failed verification. No unverified file was retained.'
    }
}

function Expand-BridgeSafeArchive {
    param([string]$Archive, [string]$Destination)
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem -ErrorAction Stop
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    $root = [IO.Path]::GetFullPath($Destination).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    try {
        if ($zip.Entries.Count -gt 10000) { throw 'Archive contains too many entries.' }
        [long]$expandedSize = 0
        # Validate every entry before writing anything. Reject links, Windows devices,
        # alternate data streams, ambiguous names, and duplicate destinations.
        foreach ($entry in $zip.Entries) {
            $expandedSize += $entry.Length
            if ($expandedSize -gt 1073741824) { throw 'Archive exceeds the supported expanded size.' }
            $name = $entry.FullName.Replace('\', '/')
            if (-not $name -or $name.StartsWith('/') -or $name.Contains(':') -or $name -match '[\x00-\x1f]') { throw 'Unsafe archive path.' }
            $parts = $name.TrimEnd('/').Split('/')
            foreach ($part in $parts) {
                if (-not $part -or $part -in @('.', '..') -or $part -match '[. ]$|[<>"|?*]' -or
                    $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { throw 'Unsafe archive name.' }
            }
            $target = [IO.Path]::GetFullPath((Join-Path $Destination $name))
            if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not $seen.Add($target)) { throw 'Unsafe archive destination.' }
            $unixType = (($entry.ExternalAttributes -shr 16) -band 0xF000)
            if ($unixType -notin @(0, 0x8000, 0x4000) -or ($entry.ExternalAttributes -band 0x400) -ne 0) { throw 'Archive links are not supported.' }
        }
        [IO.Directory]::CreateDirectory($Destination) | Out-Null
        foreach ($entry in $zip.Entries) {
            $target = [IO.Path]::GetFullPath((Join-Path $Destination $entry.FullName))
            if ($entry.FullName.EndsWith('/') -or $entry.FullName.EndsWith('\')) { [IO.Directory]::CreateDirectory($target) | Out-Null; continue }
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
            $source = $entry.Open()
            $output = $null
            try {
                $output = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                $source.CopyTo($output)
            }
            finally { if ($null -ne $output) { $output.Dispose() }; $source.Dispose() }
        }
    }
    finally { $zip.Dispose() }
}

function Assert-BridgeOfficialLock {
    param([string]$LockPath, [object]$McpInfo, [string]$NodePath)
    Invoke-BridgeNpm -NodePath $NodePath -NpmCli (Join-Path $PSScriptRoot 'validate-lock.cjs') -Arguments @($LockPath, $McpInfo.Version, $McpInfo.Uri, $McpInfo.Integrity)
}

function Resolve-BridgeNpmCli {
    param([string]$NpmPath, [string]$NodePath)
    if (-not [IO.Path]::IsPathRooted($NodePath) -or -not (Test-Path -LiteralPath $NodePath -PathType Leaf) -or
        -not [IO.Path]::IsPathRooted($NpmPath) -or -not (Test-Path -LiteralPath $NpmPath -PathType Leaf)) { throw 'Node.js and npm require existing absolute paths.' }
    $candidates = @()
    if ([IO.Path]::GetFileName($NpmPath) -ceq 'npm-cli.js') { $candidates += $NpmPath }
    $candidates += Join-Path ([IO.Path]::GetDirectoryName($NpmPath)) 'node_modules\npm\bin\npm-cli.js'
    $candidates += Join-Path ([IO.Path]::GetDirectoryName($NodePath)) 'node_modules\npm\bin\npm-cli.js'
    foreach ($candidate in $candidates) { if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate } }
    throw 'Cannot locate npm-cli.js beside the detected Node.js/npm installation. Install a supported Node.js distribution with npm.'
}

function Invoke-BridgeNpm {
    param([string]$NodePath, [string]$NpmCli, [string[]]$Arguments)
    $oldPreference = $ErrorActionPreference
    $savedEnvironment = @{}
    try {
        # stderr is deliberately discarded; npm errors may contain local paths or
        # inherited credentials. Never use cmd.exe or build a shell command string.
        $ErrorActionPreference = 'Continue'
        foreach ($name in [Environment]::GetEnvironmentVariables('Process').Keys) {
            if ($name -match '^(?i:NPM_CONFIG_|NPM_TOKEN$|NODE_AUTH_TOKEN$|NODE_OPTIONS$|NODE_PATH$|OPENAI_|CONTROL_PLANE_|TUNNEL_CLIENT_)') {
                $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
                [Environment]::SetEnvironmentVariable($name, $null, 'Process')
            }
        }
        & $NodePath $NpmCli @Arguments *> $null
        if ($LASTEXITCODE -ne 0) { throw 'npm failed.' }
    }
    catch { throw 'The isolated npm installation failed. Check Node.js compatibility and access to the official npm registry.' }
    finally {
        foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
        $ErrorActionPreference = $oldPreference
    }
}

function Install-BridgePayload {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Destination, [Parameter(Mandatory = $true)][object]$TunnelInfo,
        [Parameter(Mandatory = $true)][object]$McpInfo, [Parameter(Mandatory = $true)][string]$NpmPath,
        [Parameter(Mandatory = $true)][string]$NodePath)
    if ($Destination -notmatch '^[a-zA-Z]:[\\/]' -or $Destination -match '(^|[\\/])\.\.([\\/]|$)') { throw 'Payload staging requires a new absolute local destination.' }
    # The caller owns the staging parent and its ACL. Never reuse an existing
    # directory: even an apparently empty path may contain links or hidden files.
    if (Test-Path -LiteralPath $Destination) { throw 'The payload staging destination already exists. Choose a new versioned staging path.' }
    $ancestor = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Destination))
    while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
            if (((Get-Item -LiteralPath $ancestor -Force -ErrorAction Stop).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Payload staging cannot use a directory link or junction.'
            }
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    Assert-BridgeStableVersion $TunnelInfo.Version
    Assert-BridgeStableVersion $McpInfo.Version
    $expectedTunnel = 'https://github.com/openai/tunnel-client/releases/download/v' + $TunnelInfo.Version + '/tunnel-client-v' + $TunnelInfo.Version + '-windows-amd64.zip'
    $expectedLicense = 'https://github.com/openai/tunnel-client/releases/download/v' + $TunnelInfo.Version + '/tunnel-client-v' + $TunnelInfo.Version + '-windows-amd64-licenses.txt'
    $expectedMcp = 'https://registry.npmjs.org/chrome-devtools-mcp/-/chrome-devtools-mcp-' + $McpInfo.Version + '.tgz'
    if ($TunnelInfo.Uri -cne $expectedTunnel -or $TunnelInfo.Sha256 -cnotmatch '^[a-fA-F0-9]{64}$' -or
        $null -eq $TunnelInfo.PSObject.Properties['LicenseUri'] -or $null -eq $TunnelInfo.PSObject.Properties['LicenseSha256'] -or
        $TunnelInfo.LicenseUri -cne $expectedLicense -or $TunnelInfo.LicenseSha256 -cnotmatch '^[a-fA-F0-9]{64}$' -or
        $McpInfo.Uri -cne $expectedMcp -or $McpInfo.Integrity -cnotmatch '^sha512-[A-Za-z0-9+/]{86}==$') { throw 'Payload metadata does not identify verified official upstream packages.' }
    $npmCli = Resolve-BridgeNpmCli $NpmPath $NodePath
    [IO.Directory]::CreateDirectory($Destination) | Out-Null
    $destinationRoot = [IO.Path]::GetFullPath($Destination)
    $created = $true
    try {
        $archive = Join-Path $destinationRoot 'tunnel.zip'
        Save-BridgeVerifiedDownload -Uri $TunnelInfo.Uri -Path $archive -Sha256 $TunnelInfo.Sha256
        $tunnelDir = Join-Path $destinationRoot 'tunnel'
        Expand-BridgeSafeArchive -Archive $archive -Destination $tunnelDir
        Save-BridgeVerifiedDownload -Uri $TunnelInfo.LicenseUri -Path (Join-Path $tunnelDir 'UPSTREAM-LICENSES.txt') -Sha256 $TunnelInfo.LicenseSha256
        Remove-Item -LiteralPath $archive -Force -ErrorAction Stop
        $executables = @(Get-ChildItem -LiteralPath $tunnelDir -Filter 'tunnel-client.exe' -Recurse -File -ErrorAction Stop)
        if ($executables.Count -ne 1) { throw 'The tunnel archive must contain exactly one tunnel-client.exe.' }
        $mcpDir = Join-Path $destinationRoot 'mcp'
        [IO.Directory]::CreateDirectory($mcpDir) | Out-Null
        $manifest = @{ name = 'visible-chrome-bridge-payload'; version = '1.0.0'; private = $true; dependencies = @{ 'chrome-devtools-mcp' = $McpInfo.Version } }
        $utf8 = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText((Join-Path $mcpDir 'package.json'), ($manifest | ConvertTo-Json -Depth 4), $utf8)
        $config = Join-Path $destinationRoot 'isolated.npmrc'
        $globalConfig = Join-Path $destinationRoot 'isolated-global.npmrc'
        [IO.File]::WriteAllText($config, '', $utf8)
        [IO.File]::WriteAllText($globalConfig, '', $utf8)
        $cache = Join-Path $destinationRoot 'npm-cache'
        $common = @('--prefix', $mcpDir, '--ignore-scripts', '--no-audit', '--no-fund', '--save-exact', '--registry', 'https://registry.npmjs.org', '--userconfig', $config, '--globalconfig', $globalConfig, '--cache', $cache, '--logs-max=0', '--loglevel=error')
        # npm reads the current directory's .npmrc independently of --prefix.
        Push-Location -LiteralPath $mcpDir
        try {
            Invoke-BridgeNpm -NodePath $NodePath -NpmCli $npmCli -Arguments (@('install', '--package-lock-only') + $common)
            $lockPath = Join-Path $mcpDir 'package-lock.json'
            Assert-BridgeOfficialLock -LockPath $lockPath -McpInfo $McpInfo -NodePath $NodePath
            Invoke-BridgeNpm -NodePath $NodePath -NpmCli $npmCli -Arguments (@('ci') + $common)
            Assert-BridgeOfficialLock -LockPath $lockPath -McpInfo $McpInfo -NodePath $NodePath
        }
        finally { Pop-Location }
        $entry = Join-Path $mcpDir 'node_modules\chrome-devtools-mcp\build\src\bin\chrome-devtools-mcp.js'
        if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { throw 'The installed MCP entry point is missing.' }
        $installed = Get-Content -LiteralPath (Join-Path $mcpDir 'node_modules\chrome-devtools-mcp\package.json') -Raw | ConvertFrom-Json
        if ($installed.name -cne 'chrome-devtools-mcp' -or $installed.version -cne $McpInfo.Version) { throw 'Unexpected installed MCP package.' }
        foreach ($item in @($cache, $config, $globalConfig)) { if (Test-Path -LiteralPath $item) { Remove-Item -LiteralPath $item -Recurse -Force -ErrorAction Stop } }
        $tunnelRelative = $executables[0].FullName.Substring($destinationRoot.TrimEnd('\', '/').Length + 1).Replace('\', '/')
        return [pscustomobject]@{ TunnelVersion = $TunnelInfo.Version; McpVersion = $McpInfo.Version; TunnelRelativePath = $tunnelRelative; McpRelativePath = 'mcp/node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js' }
    }
    catch {
        # Delete only the exact new directory this invocation created. The current
        # active payload belongs to the caller and is never passed here.
        if ($created -and [IO.Path]::GetFullPath($Destination) -ceq $destinationRoot) {
            Remove-Item -LiteralPath $destinationRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw 'Payload staging failed verification or installation. The active payload was not changed; retry with a fresh staging directory.'
    }
}

Export-ModuleMember -Function Get-BridgeReleaseInfo, Get-BridgeMcpInfo, Test-BridgeVersionNewer, Save-BridgeVerifiedDownload, Install-BridgePayload
