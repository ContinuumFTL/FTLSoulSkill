[CmdletBinding()]
param(
    [Parameter()]
    [string] $InvocationRoot = $PSScriptRoot,

    [Parameter()]
    [string] $ManifestPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manifestFileName = '.ftl-soul-skill-links.json'
$authoringRelativePath = 'skills\engineering\ftl-skill-authoring'

function ConvertTo-NormalizedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter()]
        [string] $BasePath
    )

    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        if ([string]::IsNullOrWhiteSpace($BasePath)) {
            throw "Cannot normalize relative path without a base path: $Path"
        }

        $Path = Join-Path $BasePath $Path
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $pathRoot = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath.Length -gt $pathRoot.Length) {
        return $fullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    }

    return $fullPath
}

function Test-PathEqual {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Left,

        [Parameter(Mandatory = $true)]
        [string] $Right
    )

    $comparison = if ([System.OperatingSystem]::IsWindows()) {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }

    return [string]::Equals(
        (ConvertTo-NormalizedPath -Path $Left),
        (ConvertTo-NormalizedPath -Path $Right),
        $comparison
    )
}

function Get-AncestorPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [int] $Levels
    )

    $current = ConvertTo-NormalizedPath -Path $Path
    for ($index = 0; $index -lt $Levels; $index++) {
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or (Test-PathEqual -Left $parent -Right $current)) {
            return $null
        }

        $current = $parent
    }

    return $current
}

function Get-VerifiedRepositoryRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $normalizedPath = ConvertTo-NormalizedPath -Path $Path
    if (-not (Test-Path -LiteralPath $normalizedPath -PathType Container)) {
        return $null
    }

    $requiredPaths = @(
        'AGENTS.md',
        'README.md',
        'scripts\link-skills.ps1',
        'skills',
        (Join-Path $authoringRelativePath 'SKILL.md'),
        (Join-Path $authoringRelativePath 'scripts\resolve-source-root.ps1')
    )

    foreach ($relativePath in $requiredPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $normalizedPath $relativePath))) {
            return $null
        }
    }

    try {
        $gitRootOutput = & git -C $normalizedPath rev-parse --show-toplevel 2>$null
        $gitPrefixOutput = & git -C $normalizedPath rev-parse --show-prefix 2>$null
    }
    catch {
        return $null
    }

    if ($LASTEXITCODE -ne 0 -or $null -eq $gitRootOutput) {
        return $null
    }

    $gitPrefix = if ($null -eq $gitPrefixOutput) { '' } else { [string] (@($gitPrefixOutput)[0]) }
    if (-not [string]::IsNullOrWhiteSpace($gitPrefix)) {
        return $null
    }

    return ConvertTo-NormalizedPath -Path ([string] (@($gitRootOutput)[0]))
}

function Get-ManifestSourceRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LiteralPath
    )

    $normalizedManifestPath = ConvertTo-NormalizedPath -Path $LiteralPath
    if (-not (Test-Path -LiteralPath $normalizedManifestPath -PathType Leaf)) {
        throw "Managed-link manifest does not exist: $normalizedManifestPath"
    }

    try {
        $manifest = Get-Content -LiteralPath $normalizedManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "Cannot read managed-link manifest at $normalizedManifestPath. $($_.Exception.Message)"
    }

    if (
        $null -eq $manifest.PSObject.Properties['schemaVersion'] -or
        [int] $manifest.schemaVersion -ne 1 -or
        $null -eq $manifest.PSObject.Properties['sourceRoot'] -or
        [string]::IsNullOrWhiteSpace([string] $manifest.sourceRoot)
    ) {
        throw "Managed-link manifest has no supported sourceRoot: $normalizedManifestPath"
    }

    if ($null -eq $manifest.PSObject.Properties['links'] -or $null -eq $manifest.links) {
        throw "Managed-link manifest has no links collection: $normalizedManifestPath"
    }

    $manifestDirectory = Split-Path -Parent $normalizedManifestPath
    $declaredSourceRoot = ConvertTo-NormalizedPath -Path ([string] $manifest.sourceRoot) -BasePath $manifestDirectory
    $sourceRoot = Get-VerifiedRepositoryRoot -Path $declaredSourceRoot
    if ($null -eq $sourceRoot) {
        throw "Managed sourceRoot is not a valid FTLSoul repository: $declaredSourceRoot"
    }

    $expectedTarget = ConvertTo-NormalizedPath -Path (Join-Path $declaredSourceRoot $authoringRelativePath)
    $matchingLinks = @(
        @($manifest.links) | Where-Object {
            $null -ne $_ -and
            $null -ne $_.PSObject.Properties['name'] -and
            [string] $_.name -eq 'ftl-skill-authoring' -and
            $null -ne $_.PSObject.Properties['target'] -and
            -not [string]::IsNullOrWhiteSpace([string] $_.target) -and
            (Test-PathEqual -Left (ConvertTo-NormalizedPath -Path ([string] $_.target) -BasePath $declaredSourceRoot) -Right $expectedTarget)
        }
    )

    if ($matchingLinks.Count -ne 1) {
        throw "Managed-link manifest does not contain exactly one valid ftl-skill-authoring target: $normalizedManifestPath"
    }

    return $sourceRoot
}

$normalizedInvocationRoot = ConvertTo-NormalizedPath -Path $InvocationRoot
$sourceCandidate = Get-AncestorPath -Path $normalizedInvocationRoot -Levels 4
$validRoots = [System.Collections.Generic.List[string]]::new()

if ($null -ne $sourceCandidate) {
    $verifiedSourceCandidate = Get-VerifiedRepositoryRoot -Path $sourceCandidate
    if ($null -ne $verifiedSourceCandidate) {
        $validRoots.Add($verifiedSourceCandidate)
    }
}

$effectiveManifestPath = $null
if (-not [string]::IsNullOrWhiteSpace($ManifestPath)) {
    $effectiveManifestPath = ConvertTo-NormalizedPath -Path $ManifestPath
}
else {
    $skillDirectory = Get-AncestorPath -Path $normalizedInvocationRoot -Levels 1
    if ($null -ne $skillDirectory) {
        $installRoot = Split-Path -Parent $skillDirectory
        if (-not [string]::IsNullOrWhiteSpace($installRoot)) {
            $adjacentManifestPath = Join-Path $installRoot $manifestFileName
            if (Test-Path -LiteralPath $adjacentManifestPath -PathType Leaf) {
                $effectiveManifestPath = ConvertTo-NormalizedPath -Path $adjacentManifestPath
            }
        }
    }
}

if ($null -ne $effectiveManifestPath) {
    $validRoots.Add((Get-ManifestSourceRoot -LiteralPath $effectiveManifestPath))
}

$distinctRoots = [System.Collections.Generic.List[string]]::new()
foreach ($candidate in $validRoots) {
    if (-not ($distinctRoots | Where-Object { Test-PathEqual -Left $_ -Right $candidate })) {
        $distinctRoots.Add($candidate)
    }
}

if ($distinctRoots.Count -eq 0) {
    throw 'Cannot determine the FTLSoul source root. Run scripts/link-skills.ps1 from the intended FTLSoul clone; disk scanning and cache fallbacks are disabled.'
}

if ($distinctRoots.Count -gt 1) {
    throw "Conflicting FTLSoul source roots were found: $($distinctRoots -join ', ')"
}

Write-Output $distinctRoots[0]
