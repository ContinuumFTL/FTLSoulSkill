[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string] $SourceRoot,

    [Parameter()]
    [string] $TargetRoot = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.agents\skills')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manifestFileName = '.ftl-soul-skill-links.json'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Split-Path -Parent $PSScriptRoot
}

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
        $trimChars = [char[]]@(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )
        return $fullPath.TrimEnd($trimChars)
    }

    return $fullPath
}

function Get-PathItem {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LiteralPath
    )

    try {
        return Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        $parentPath = Split-Path -Parent $LiteralPath
        $leafName = Split-Path -Leaf $LiteralPath
        if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
            return $null
        }

        return Get-ChildItem -LiteralPath $parentPath -Force |
            Where-Object { $_.Name -eq $leafName } |
            Select-Object -First 1
    }
}

function Test-IsDirectoryLink {
    param(
        [Parameter()]
        $Item
    )

    return (
        $null -ne $Item -and
        $null -ne $Item.PSObject.Properties['LinkType'] -and
        $Item.LinkType -in @('SymbolicLink', 'Junction')
    )
}

function Get-NormalizedLinkTarget {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    if (-not (Test-IsDirectoryLink -Item $Item)) {
        return $null
    }

    $targets = @($Item.Target)
    if ($targets.Count -eq 0 -or [string]::IsNullOrWhiteSpace([string] $targets[0])) {
        return $null
    }

    return ConvertTo-NormalizedPath -Path ([string] $targets[0]) -BasePath (Split-Path -Parent $Item.FullName)
}

function Remove-DirectoryLink {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LiteralPath
    )

    $item = Get-PathItem -LiteralPath $LiteralPath
    if ($null -eq $item) {
        return $false
    }

    if (-not (Test-IsDirectoryLink -Item $item)) {
        throw "Refusing to remove a non-link directory: $LiteralPath"
    }

    [System.IO.Directory]::Delete($item.FullName, $false)

    if ($null -ne (Get-PathItem -LiteralPath $LiteralPath)) {
        throw "Directory link still exists after deletion: $LiteralPath"
    }

    return $true
}

function Get-SkillName {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $SkillFile
    )

    $lines = @(Get-Content -LiteralPath $SkillFile.FullName -Encoding UTF8)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') {
        throw "Missing YAML frontmatter in $($SkillFile.FullName)"
    }

    $name = $null
    $closedFrontmatter = $false
    for ($index = 1; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line.Trim() -eq '---') {
            $closedFrontmatter = $true
            break
        }

        if ($line -match '^\s*name\s*:\s*["'']?([a-z0-9-]+)["'']?\s*$') {
            $name = $Matches[1]
        }
    }

    if (-not $closedFrontmatter) {
        throw "Unclosed YAML frontmatter in $($SkillFile.FullName)"
    }

    if ([string]::IsNullOrWhiteSpace($name)) {
        throw "Missing or invalid skill name in $($SkillFile.FullName). Use lowercase letters, digits, and hyphens."
    }

    return $name
}

$SourceRoot = ConvertTo-NormalizedPath -Path $SourceRoot
$TargetRoot = ConvertTo-NormalizedPath -Path $TargetRoot

if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "Source root does not exist: $SourceRoot"
}

$skillFiles = @()
$rootSkillFile = Join-Path $SourceRoot 'SKILL.md'
if (Test-Path -LiteralPath $rootSkillFile -PathType Leaf) {
    $skillFiles += Get-Item -LiteralPath $rootSkillFile
}

$skillsDirectory = Join-Path $SourceRoot 'skills'
if (Test-Path -LiteralPath $skillsDirectory -PathType Container) {
    $skillFiles += Get-ChildItem -LiteralPath $skillsDirectory -Filter 'SKILL.md' -File -Recurse
}

if ($skillFiles.Count -eq 0) {
    throw "No SKILL.md files found in $SourceRoot or $skillsDirectory"
}

$skills = @(
    $skillFiles |
        ForEach-Object {
            $skillName = Get-SkillName -SkillFile $_
            [pscustomobject]@{
                Name       = $skillName
                SourcePath = ConvertTo-NormalizedPath -Path $_.Directory.FullName
                LinkPath   = ConvertTo-NormalizedPath -Path (Join-Path $TargetRoot $skillName)
            }
        } |
        Sort-Object -Property Name
)

$duplicateNames = @($skills | Group-Object -Property Name | Where-Object { $_.Count -gt 1 })
if ($duplicateNames.Count -gt 0) {
    $details = $duplicateNames | ForEach-Object {
        $paths = ($_.Group.SourcePath -join ', ')
        "$($_.Name): $paths"
    }
    throw "Duplicate skill names found. Each skill name must be unique.`n$($details -join "`n")"
}

$manifestPath = Join-Path $TargetRoot $manifestFileName
$previousLinks = @()
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    try {
        $previousManifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $previousManifest.PSObject.Properties['links'] -and $null -ne $previousManifest.links) {
            $previousLinks = @($previousManifest.links)
        }
    }
    catch {
        throw "Cannot read managed-link manifest at $manifestPath. Fix or remove that file, then run this script again. $($_.Exception.Message)"
    }
}

$managedByPath = @{}
foreach ($entry in $previousLinks) {
    if (
        $null -eq $entry.PSObject.Properties['path'] -or
        $null -eq $entry.PSObject.Properties['target'] -or
        $null -eq $entry.path -or
        $null -eq $entry.target
    ) {
        throw "Invalid managed-link entry in $manifestPath"
    }

    $entryPath = ConvertTo-NormalizedPath -Path ([string] $entry.path) -BasePath $TargetRoot
    $managedByPath[$entryPath] = $entry
}

$desiredByPath = @{}
foreach ($skill in $skills) {
    $desiredByPath[$skill.LinkPath] = $skill

    $existingItem = Get-PathItem -LiteralPath $skill.LinkPath
    if ($null -eq $existingItem) {
        continue
    }

    $actualTarget = Get-NormalizedLinkTarget -Item $existingItem
    if ((Test-IsDirectoryLink -Item $existingItem) -and $actualTarget -eq $skill.SourcePath) {
        continue
    }

    if ($managedByPath.ContainsKey($skill.LinkPath)) {
        $recordedTarget = ConvertTo-NormalizedPath -Path ([string] $managedByPath[$skill.LinkPath].target) -BasePath $SourceRoot
        if ((Test-IsDirectoryLink -Item $existingItem) -and $actualTarget -eq $recordedTarget) {
            continue
        }
    }

    throw "Refusing to replace unmanaged item: $($skill.LinkPath). Move or remove it manually, then run this script again."
}

if (-not (Test-Path -LiteralPath $TargetRoot)) {
    if ($PSCmdlet.ShouldProcess($TargetRoot, 'Create user skill directory')) {
        New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null
    }
}
elseif (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) {
    throw "Target root exists but is not a directory: $TargetRoot"
}

foreach ($entry in $previousLinks) {
    $oldLinkPath = ConvertTo-NormalizedPath -Path ([string] $entry.path) -BasePath $TargetRoot
    if ($desiredByPath.ContainsKey($oldLinkPath)) {
        continue
    }

    $existingItem = Get-PathItem -LiteralPath $oldLinkPath
    if ($null -eq $existingItem) {
        continue
    }

    $recordedTarget = ConvertTo-NormalizedPath -Path ([string] $entry.target) -BasePath $SourceRoot
    $actualTarget = Get-NormalizedLinkTarget -Item $existingItem
    if (-not (Test-IsDirectoryLink -Item $existingItem) -or $actualTarget -ne $recordedTarget) {
        Write-Warning "Skipped stale path because it is no longer the directory link managed by this script: $oldLinkPath"
        continue
    }

    if ($PSCmdlet.ShouldProcess($oldLinkPath, 'Remove stale managed skill link')) {
        $removed = Remove-DirectoryLink -LiteralPath $oldLinkPath
        if ($removed) {
            Write-Host "Removed stale link: $oldLinkPath"
        }
    }
}

foreach ($skill in $skills) {
    $existingItem = Get-PathItem -LiteralPath $skill.LinkPath
    if ($null -ne $existingItem) {
        $actualTarget = Get-NormalizedLinkTarget -Item $existingItem
        if ((Test-IsDirectoryLink -Item $existingItem) -and $actualTarget -eq $skill.SourcePath) {
            Write-Host "Already linked: $($skill.Name) -> $($skill.SourcePath)"
            continue
        }

        if ($PSCmdlet.ShouldProcess($skill.LinkPath, 'Replace outdated managed skill link')) {
            $null = Remove-DirectoryLink -LiteralPath $skill.LinkPath
        }
    }

    if ($PSCmdlet.ShouldProcess($skill.LinkPath, "Link skill to $($skill.SourcePath)")) {
        try {
            New-Item -ItemType SymbolicLink -Path $skill.LinkPath -Target $skill.SourcePath | Out-Null
            Write-Host "Linked (symbolic link): $($skill.Name) -> $($skill.SourcePath)"
        }
        catch {
            $symbolicLinkError = $_.Exception.Message
            try {
                New-Item -ItemType Junction -Path $skill.LinkPath -Target $skill.SourcePath | Out-Null
                Write-Host "Linked (junction): $($skill.Name) -> $($skill.SourcePath)"
            }
            catch {
                throw "Failed to create a directory link at $($skill.LinkPath). Symbolic link error: $symbolicLinkError Junction error: $($_.Exception.Message)"
            }
        }
    }
}

if ($WhatIfPreference) {
    Write-Host 'Preview complete. No manifest was written because -WhatIf was used.'
    return
}

$manifest = [ordered]@{
    schemaVersion = 1
    sourceRoot    = $SourceRoot
    links         = @(
        $skills | ForEach-Object {
            [ordered]@{
                name   = $_.Name
                path   = $_.LinkPath
                target = $_.SourcePath
            }
        }
    )
}

$manifestJson = $manifest | ConvertTo-Json -Depth 5
$existingManifestJson = $null
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    $existingManifestJson = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
}

if ($null -eq $existingManifestJson -or $existingManifestJson.Trim() -ne $manifestJson.Trim()) {
    Set-Content -LiteralPath $manifestPath -Value $manifestJson -Encoding UTF8
}

Write-Host "Synchronized $($skills.Count) skills into $TargetRoot"
