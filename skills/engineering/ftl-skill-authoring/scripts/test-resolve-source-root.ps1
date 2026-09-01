[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolverPath = Join-Path $PSScriptRoot 'resolve-source-root.ps1'
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ftl-source-root-tests-{0}" -f [guid]::NewGuid().ToString('N'))

function ConvertTo-NormalizedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    return [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Assert-PathEqual {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Actual,

        [Parameter(Mandatory = $true)]
        [string] $Expected,

        [Parameter(Mandatory = $true)]
        [string] $Scenario
    )

    $comparison = if ([System.OperatingSystem]::IsWindows()) {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }

    $expectedGitRoot = & git -C $Expected rev-parse --show-toplevel 2>$null
    $normalizedExpected = if ($LASTEXITCODE -eq 0 -and $null -ne $expectedGitRoot) {
        ConvertTo-NormalizedPath -Path ([string] (@($expectedGitRoot)[0]))
    }
    else {
        ConvertTo-NormalizedPath -Path $Expected
    }

    if (-not [string]::Equals((ConvertTo-NormalizedPath -Path $Actual), $normalizedExpected, $comparison)) {
        throw "$Scenario returned '$Actual' instead of '$Expected'."
    }
}

function Assert-Fails {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock] $Action,

        [Parameter(Mandatory = $true)]
        [string] $Scenario
    )

    try {
        & $Action
    }
    catch {
        return
    }

    throw "$Scenario was expected to fail."
}

function New-RepositoryFixture {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Root
    )

    $authoringRoot = Join-Path $Root 'skills\engineering\ftl-skill-authoring'
    $scriptsRoot = Join-Path $authoringRoot 'scripts'
    $null = New-Item -ItemType Directory -Path $scriptsRoot -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $Root 'scripts') -Force
    Set-Content -LiteralPath (Join-Path $Root 'AGENTS.md') -Value '# Fixture' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $Root 'README.md') -Value '# Fixture' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $Root 'scripts\link-skills.ps1') -Value '# Fixture' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $authoringRoot 'SKILL.md') -Value "---`nname: ftl-skill-authoring`ndescription: Fixture.`n---" -Encoding UTF8
    Copy-Item -LiteralPath $resolverPath -Destination (Join-Path $scriptsRoot 'resolve-source-root.ps1')
    & git -C $Root init -q
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot initialize fixture repository: $Root"
    }

    return $scriptsRoot
}

try {
    $null = New-Item -ItemType Directory -Path $temporaryRoot -Force
    $repositoryA = Join-Path $temporaryRoot 'repository-a'
    $repositoryB = Join-Path $temporaryRoot 'repository-b'
    $sourceInvocationA = New-RepositoryFixture -Root $repositoryA
    $null = New-RepositoryFixture -Root $repositoryB

    $directResult = & $resolverPath -InvocationRoot $sourceInvocationA
    Assert-PathEqual -Actual $directResult -Expected $repositoryA -Scenario 'Direct source invocation'

    $installRoot = Join-Path $temporaryRoot 'installed-skills'
    $installedInvocation = Join-Path $installRoot 'ftl-skill-authoring\scripts'
    $null = New-Item -ItemType Directory -Path $installedInvocation -Force
    $manifestPath = Join-Path $installRoot '.ftl-soul-skill-links.json'
    $manifest = [ordered]@{
        schemaVersion = 1
        sourceRoot    = $repositoryA
        links         = @(
            [ordered]@{
                name   = 'ftl-skill-authoring'
                path   = (Join-Path $installRoot 'ftl-skill-authoring')
                target = (Join-Path $repositoryA 'skills\engineering\ftl-skill-authoring')
            }
        )
    }
    Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 5) -Encoding UTF8

    $manifestResult = & $resolverPath -InvocationRoot $installedInvocation
    Assert-PathEqual -Actual $manifestResult -Expected $repositoryA -Scenario 'Managed manifest invocation'

    $missingInvocation = Join-Path $temporaryRoot 'missing\ftl-skill-authoring\scripts'
    $null = New-Item -ItemType Directory -Path $missingInvocation -Force
    Assert-Fails -Scenario 'Missing source and manifest' -Action {
        & $resolverPath -InvocationRoot $missingInvocation
    }

    $invalidRoot = Join-Path $temporaryRoot 'invalid-root'
    $null = New-Item -ItemType Directory -Path $invalidRoot -Force
    $invalidManifestPath = Join-Path $temporaryRoot 'invalid-manifest.json'
    $invalidManifest = [ordered]@{
        schemaVersion = 1
        sourceRoot    = $invalidRoot
        links         = @()
    }
    Set-Content -LiteralPath $invalidManifestPath -Value ($invalidManifest | ConvertTo-Json -Depth 5) -Encoding UTF8
    Assert-Fails -Scenario 'Invalid repository signature' -Action {
        & $resolverPath -InvocationRoot $missingInvocation -ManifestPath $invalidManifestPath
    }

    $conflictManifestPath = Join-Path $temporaryRoot 'conflict-manifest.json'
    $conflictManifest = [ordered]@{
        schemaVersion = 1
        sourceRoot    = $repositoryB
        links         = @(
            [ordered]@{
                name   = 'ftl-skill-authoring'
                path   = (Join-Path $installRoot 'ftl-skill-authoring')
                target = (Join-Path $repositoryB 'skills\engineering\ftl-skill-authoring')
            }
        )
    }
    Set-Content -LiteralPath $conflictManifestPath -Value ($conflictManifest | ConvertTo-Json -Depth 5) -Encoding UTF8
    Assert-Fails -Scenario 'Conflicting valid roots' -Action {
        & $resolverPath -InvocationRoot $sourceInvocationA -ManifestPath $conflictManifestPath
    }

    Write-Output 'All source-root resolver tests passed.'
}
finally {
    $normalizedTemporaryRoot = ConvertTo-NormalizedPath -Path $temporaryRoot
    $normalizedSystemTemp = ConvertTo-NormalizedPath -Path ([System.IO.Path]::GetTempPath())
    if (-not $normalizedTemporaryRoot.StartsWith($normalizedSystemTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove test directory outside the system temp root: $normalizedTemporaryRoot"
    }

    if (Test-Path -LiteralPath $normalizedTemporaryRoot) {
        Remove-Item -LiteralPath $normalizedTemporaryRoot -Recurse -Force
    }
}
