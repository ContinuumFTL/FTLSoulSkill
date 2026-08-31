[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]] $Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SkillFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $InputPaths
    )

    $files = @()
    foreach ($inputPath in $InputPaths) {
        $resolvedPath = Resolve-Path -LiteralPath $inputPath -ErrorAction Stop
        $item = Get-Item -LiteralPath $resolvedPath.Path -Force

        if ($item.PSIsContainer) {
            $files += Get-ChildItem -LiteralPath $item.FullName -Filter 'SKILL.md' -File -Recurse
            continue
        }

        if ($item.Name -ine 'SKILL.md') {
            throw "Expected a SKILL.md file or a directory containing skills: $($item.FullName)"
        }

        $files += $item
    }

    return @($files | Sort-Object -Property FullName -Unique)
}

function Test-StartsMarkdownBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Line
    )

    $trimmed = $Line.TrimStart()
    return (
        $trimmed -match '^#{1,6}\s' -or
        $trimmed -match '^[-*+]\s' -or
        $trimmed -match '^\d+[.)]\s' -or
        $trimmed -match '^>' -or
        $trimmed -match '^(```|~~~)' -or
        $trimmed -match '^<' -or
        $trimmed -match '^(---+|___+|\*\*\*+)\s*$' -or
        $Line -match '\|'
    )
}

function Test-PreviousAcceptsContinuation {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Line
    )

    $trimmed = $Line.TrimStart()
    if ($trimmed -match '^[-*+]\s' -or $trimmed -match '^\d+[.)]\s') {
        return $true
    }

    return -not (
        $trimmed -match '^#{1,6}\s' -or
        $trimmed -match '^>' -or
        $trimmed -match '^(```|~~~)' -or
        $trimmed -match '^<' -or
        $trimmed -match '^(---+|___+|\*\*\*+)\s*$' -or
        $Line -match '\|'
    )
}

if ($null -eq $Path -or $Path.Count -eq 0) {
    $skillRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $Path = @($skillRoot)
}

$skillFiles = @(Get-SkillFiles -InputPaths $Path)
if ($skillFiles.Count -eq 0) {
    throw 'No SKILL.md files found in the requested paths.'
}

$violations = [System.Collections.Generic.List[object]]::new()

foreach ($skillFile in $skillFiles) {
    $lines = @(Get-Content -LiteralPath $skillFile.FullName -Encoding UTF8)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') {
        $violations.Add([pscustomobject]@{
            File = $skillFile.FullName
            Line = 1
            Message = 'Missing YAML frontmatter opening delimiter.'
        })
        continue
    }

    $frontmatterEnd = -1
    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -eq '---') {
            $frontmatterEnd = $index
            break
        }
    }

    if ($frontmatterEnd -lt 0) {
        $violations.Add([pscustomobject]@{
            File = $skillFile.FullName
            Line = 1
            Message = 'Missing YAML frontmatter closing delimiter.'
        })
        continue
    }

    for ($index = 1; $index -lt $frontmatterEnd; $index++) {
        if ($lines[$index] -notmatch '^\s*description\s*:\s*(.*)$') {
            continue
        }

        $descriptionValue = $Matches[1].Trim()
        if ([string]::IsNullOrWhiteSpace($descriptionValue) -or $descriptionValue -match '^[>|]') {
            $violations.Add([pscustomobject]@{
                File = $skillFile.FullName
                Line = $index + 1
                Message = 'Frontmatter description must be a non-empty single physical line.'
            })
        }

        if ($index + 1 -lt $frontmatterEnd -and $lines[$index + 1] -match '^\s+\S') {
            $violations.Add([pscustomobject]@{
                File = $skillFile.FullName
                Line = $index + 2
                Message = 'Frontmatter description has a physical continuation line.'
            })
        }
    }

    $fenceMarker = $null
    for ($index = $frontmatterEnd + 1; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -match '^\s{0,3}(```|~~~)') {
            $marker = $Matches[1]
            if ($null -eq $fenceMarker) {
                $fenceMarker = $marker
            }
            elseif ($fenceMarker -eq $marker) {
                $fenceMarker = $null
            }
            continue
        }

        if ($null -ne $fenceMarker -or $index -eq $frontmatterEnd + 1) {
            continue
        }

        $previousLine = $lines[$index - 1]
        if ([string]::IsNullOrWhiteSpace($line) -or [string]::IsNullOrWhiteSpace($previousLine)) {
            continue
        }

        if ($previousLine -match '( {2,}|\\)\s*$') {
            continue
        }

        if (Test-StartsMarkdownBlock -Line $line) {
            continue
        }

        if ($line -match '^\s{4,}\S') {
            continue
        }

        if (-not (Test-PreviousAcceptsContinuation -Line $previousLine)) {
            continue
        }

        $violations.Add([pscustomobject]@{
            File = $skillFile.FullName
            Line = $index + 1
            Message = 'Prose paragraph or list item continues on another physical line.'
        })
    }
}

if ($violations.Count -gt 0) {
    foreach ($violation in $violations) {
        Write-Output ("{0}:{1}: {2}" -f $violation.File, $violation.Line, $violation.Message)
    }

    throw "Found $($violations.Count) Skill Markdown formatting violation(s)."
}

Write-Output "Validated $($skillFiles.Count) SKILL.md file(s); no fixed-width prose continuations found."
