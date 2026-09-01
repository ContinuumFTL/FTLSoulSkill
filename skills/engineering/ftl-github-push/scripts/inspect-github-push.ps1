[CmdletBinding()]
param(
    [Parameter()]
    [string] $RepositoryRoot = (Get-Location).Path,

    [Parameter()]
    [string] $RemoteName,

    [Parameter()]
    [string] $TargetBranch,

    [Parameter()]
    [switch] $InitialPublication,

    [Parameter()]
    [long] $LargeBlobBytes = 10MB,

    [Parameter()]
    [switch] $AllowNonGitHubRemoteForTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Root,

        [Parameter(Mandatory = $true)]
        [string[]] $GitArguments,

        [Parameter()]
        [switch] $AllowFailure
    )

    $output = @(& git -c core.quotePath=false -C $Root @GitArguments 2>$null)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "Git command failed with exit code $exitCode."
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Lines    = @($output | ForEach-Object { [string] $_ })
    }
}

function Get-FirstLine {
    param(
        [Parameter()]
        $Result
    )

    if ($null -eq $Result -or $Result.Lines.Count -eq 0) {
        return $null
    }

    return [string] $Result.Lines[0]
}

function Get-SanitizedRemoteUrl {
    param(
        [Parameter()]
        [string] $Url
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $null
    }

    if ($Url -match '^(?<scheme>https?://)(?<userinfo>[^/@]+)@(?<rest>.+)$') {
        return "$($Matches.scheme)***@$($Matches.rest)"
    }

    return $Url
}

function Test-GitHubUrl {
    param(
        [Parameter()]
        [string] $Url
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }

    return $Url -match '(?i)^(?:https?://github\.com/|git@github\.com:|ssh://git@github\.com/)'
}

function Test-EmbeddedHttpCredential {
    param(
        [Parameter()]
        [string] $Url
    )

    return -not [string]::IsNullOrWhiteSpace($Url) -and $Url -match '^(?i:https?://)[^/@]+@'
}

function Protect-SensitiveText {
    param(
        [Parameter()]
        [string] $Text
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return $Text
    }

    $protected = $Text
    $protected = [regex]::Replace($protected, '(?i)github_pat_[A-Za-z0-9_]{20,}', '[REDACTED_GITHUB_TOKEN]')
    $protected = [regex]::Replace($protected, '(?i)gh[pousr]_[A-Za-z0-9]{20,}', '[REDACTED_GITHUB_TOKEN]')
    $protected = [regex]::Replace($protected, '(?<![A-Z0-9])(?:AKIA|ASIA)[A-Z0-9]{16}(?![A-Z0-9])', '[REDACTED_AWS_ACCESS_KEY]')
    $protected = [regex]::Replace($protected, '(?i)xox[baprs]-[A-Za-z0-9-]{10,}', '[REDACTED_AUTH_TOKEN]')
    $protected = [regex]::Replace($protected, '(?i)((?:_authToken|access[_-]?token|refresh[_-]?token)\s*[:=]\s*["'']?)[A-Za-z0-9_./+=-]{16,}', '$1[REDACTED]')
    $protected = [regex]::Replace($protected, '-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----', '[REDACTED_PRIVATE_KEY_MARKER]')
    return $protected
}

$findings = [System.Collections.Generic.List[object]]::new()
$findingKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

function Add-Finding {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('blocker', 'warning')]
        [string] $Severity,

        [Parameter(Mandatory = $true)]
        [string] $Code,

        [Parameter(Mandatory = $true)]
        [string] $Message,

        [Parameter()]
        [string] $Path,

        [Parameter()]
        [string] $Detail
    )

    $safePath = Protect-SensitiveText -Text $Path
    $safeDetail = Protect-SensitiveText -Text $Detail
    $key = "$Severity|$Code|$safePath|$safeDetail"
    if (-not $findingKeys.Add($key)) {
        return
    }

    $findings.Add([ordered]@{
        severity = $Severity
        code     = $Code
        path     = if ([string]::IsNullOrWhiteSpace($safePath)) { $null } else { $safePath }
        detail   = if ([string]::IsNullOrWhiteSpace($safeDetail)) { $null } else { $safeDetail }
        message  = $Message
    })
}

$requestedRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$rootResult = Invoke-Git -Root $requestedRoot -GitArguments @('rev-parse', '--show-toplevel') -AllowFailure
if ($rootResult.ExitCode -ne 0 -or $rootResult.Lines.Count -eq 0) {
    throw "RepositoryRoot is not inside a Git working tree: $requestedRoot"
}

$repository = [System.IO.Path]::GetFullPath((Get-FirstLine -Result $rootResult))
$headResult = Invoke-Git -Root $repository -GitArguments @('rev-parse', '--verify', 'HEAD') -AllowFailure
if ($headResult.ExitCode -ne 0) {
    throw "The Git repository has no commit at HEAD: $repository"
}

$head = Get-FirstLine -Result $headResult
$branchResult = Invoke-Git -Root $repository -GitArguments @('symbolic-ref', '--quiet', '--short', 'HEAD') -AllowFailure
$branch = if ($branchResult.ExitCode -eq 0) { Get-FirstLine -Result $branchResult } else { $null }
if ([string]::IsNullOrWhiteSpace($branch)) {
    Add-Finding -Severity blocker -Code 'DETACHED_HEAD' -Message 'HEAD is detached; the source branch cannot be determined safely.'
}

$remoteNames = @((Invoke-Git -Root $repository -GitArguments @('remote')).Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$resolvedRemote = $RemoteName
if ([string]::IsNullOrWhiteSpace($resolvedRemote) -and -not [string]::IsNullOrWhiteSpace($branch)) {
    $configuredRemoteResult = Invoke-Git -Root $repository -GitArguments @('config', '--get', "branch.$branch.remote") -AllowFailure
    if ($configuredRemoteResult.ExitCode -eq 0) {
        $configuredRemote = Get-FirstLine -Result $configuredRemoteResult
        if (-not [string]::IsNullOrWhiteSpace($configuredRemote) -and $configuredRemote -ne '.') {
            $resolvedRemote = $configuredRemote
        }
    }
}

if ([string]::IsNullOrWhiteSpace($resolvedRemote)) {
    if ($remoteNames.Count -eq 1) {
        $resolvedRemote = $remoteNames[0]
    }
    elseif ($remoteNames.Count -eq 0) {
        Add-Finding -Severity blocker -Code 'NO_REMOTE' -Message 'No Git remote is configured.'
    }
    else {
        Add-Finding -Severity blocker -Code 'AMBIGUOUS_REMOTE' -Message 'More than one remote exists and no unique push target is configured.' -Detail ($remoteNames -join ', ')
    }
}
elseif ($resolvedRemote -notin $remoteNames) {
    Add-Finding -Severity blocker -Code 'UNKNOWN_REMOTE' -Message 'The requested remote does not exist.' -Detail $resolvedRemote
}

$resolvedTargetBranch = $TargetBranch
if ([string]::IsNullOrWhiteSpace($resolvedTargetBranch) -and -not [string]::IsNullOrWhiteSpace($branch)) {
    $mergeResult = Invoke-Git -Root $repository -GitArguments @('config', '--get', "branch.$branch.merge") -AllowFailure
    if ($mergeResult.ExitCode -eq 0) {
        $mergeRef = Get-FirstLine -Result $mergeResult
        if (-not [string]::IsNullOrWhiteSpace($mergeRef) -and $mergeRef.StartsWith('refs/heads/')) {
            $resolvedTargetBranch = $mergeRef.Substring('refs/heads/'.Length)
        }
    }
}

if ([string]::IsNullOrWhiteSpace($resolvedTargetBranch)) {
    $resolvedTargetBranch = $branch
}

if ([string]::IsNullOrWhiteSpace($resolvedTargetBranch)) {
    Add-Finding -Severity blocker -Code 'UNKNOWN_TARGET_BRANCH' -Message 'The target branch cannot be determined.'
}
else {
    $branchFormatResult = Invoke-Git -Root $repository -GitArguments @('check-ref-format', '--branch', $resolvedTargetBranch) -AllowFailure
    if ($branchFormatResult.ExitCode -ne 0) {
        Add-Finding -Severity blocker -Code 'INVALID_TARGET_BRANCH' -Message 'The target branch name is invalid.' -Detail $resolvedTargetBranch
    }
}

$remoteUrl = $null
$safeRemoteUrl = $null
if (-not [string]::IsNullOrWhiteSpace($resolvedRemote) -and $resolvedRemote -in $remoteNames) {
    $urlResult = Invoke-Git -Root $repository -GitArguments @('remote', 'get-url', '--push', $resolvedRemote) -AllowFailure
    if ($urlResult.ExitCode -ne 0) {
        Add-Finding -Severity blocker -Code 'MISSING_PUSH_URL' -Message 'The selected remote has no usable push URL.' -Detail $resolvedRemote
    }
    else {
        $remoteUrl = Get-FirstLine -Result $urlResult
        $safeRemoteUrl = Get-SanitizedRemoteUrl -Url $remoteUrl
        if (Test-EmbeddedHttpCredential -Url $remoteUrl) {
            Add-Finding -Severity blocker -Code 'CREDENTIAL_IN_REMOTE_URL' -Message 'The remote URL contains embedded HTTP credentials.' -Detail $safeRemoteUrl
        }
        elseif (-not $AllowNonGitHubRemoteForTest -and -not (Test-GitHubUrl -Url $remoteUrl)) {
            Add-Finding -Severity blocker -Code 'NON_GITHUB_REMOTE' -Message 'The selected push URL is not a supported github.com URL.' -Detail $safeRemoteUrl
        }
    }
}

$trackingRef = $null
$relationship = 'unknown'
$revisionArguments = @()
$revisionLabel = $null
$commitCount = 0

if ($InitialPublication) {
    $relationship = 'initial_publication'
    $revisionArguments = @('--root', 'HEAD')
    $revisionLabel = 'complete HEAD history'
}
elseif (-not [string]::IsNullOrWhiteSpace($resolvedRemote) -and -not [string]::IsNullOrWhiteSpace($resolvedTargetBranch)) {
    $trackingRef = "refs/remotes/$resolvedRemote/$resolvedTargetBranch"
    $trackingResult = Invoke-Git -Root $repository -GitArguments @('rev-parse', '--verify', $trackingRef) -AllowFailure
    if ($trackingResult.ExitCode -ne 0) {
        Add-Finding -Severity blocker -Code 'MISSING_REMOTE_REF' -Message 'The local remote-tracking ref is missing; query and fetch the exact remote branch before inspection, or use initial-publication mode.' -Detail $trackingRef
    }
    else {
        $remoteAncestor = Invoke-Git -Root $repository -GitArguments @('merge-base', '--is-ancestor', $trackingRef, 'HEAD') -AllowFailure
        $headAncestor = Invoke-Git -Root $repository -GitArguments @('merge-base', '--is-ancestor', 'HEAD', $trackingRef) -AllowFailure
        if ($remoteAncestor.ExitCode -eq 0) {
            $countResult = Invoke-Git -Root $repository -GitArguments @('rev-list', '--count', "$trackingRef..HEAD")
            $commitCount = [int] (Get-FirstLine -Result $countResult)
            $relationship = if ($commitCount -eq 0) { 'synchronized' } else { 'local_ahead' }
        }
        elseif ($headAncestor.ExitCode -eq 0) {
            $relationship = 'remote_ahead'
            Add-Finding -Severity blocker -Code 'REMOTE_AHEAD' -Message 'The remote branch contains commits that are not in local HEAD.' -Detail $trackingRef
        }
        else {
            $relationship = 'diverged'
            Add-Finding -Severity blocker -Code 'DIVERGED' -Message 'Local HEAD and the remote branch have diverged.' -Detail $trackingRef
        }

        $revisionLabel = "$trackingRef..HEAD"
        $revisionArguments = @($revisionLabel)
    }
}

if ($InitialPublication) {
    $countResult = Invoke-Git -Root $repository -GitArguments @('rev-list', '--count', 'HEAD')
    $commitCount = [int] (Get-FirstLine -Result $countResult)
}

$worktreeLines = @((Invoke-Git -Root $repository -GitArguments @('status', '--porcelain=v1', '--untracked-files=all')).Lines)
$worktreeEntries = @($worktreeLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

$commits = [System.Collections.Generic.List[object]]::new()
$files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$binaryFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$scannedTextLines = 0
$scanComplete = $true

if ($revisionArguments.Count -gt 0 -and $commitCount -gt 0) {
    $logArguments = @('log', '--format=%H%x09%an%x09%ae%x09%s') + $revisionArguments
    foreach ($line in (Invoke-Git -Root $repository -GitArguments $logArguments).Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = $line -split "`t", 4
        if ($parts.Count -lt 4) {
            $scanComplete = $false
            Add-Finding -Severity blocker -Code 'INCOMPLETE_COMMIT_METADATA' -Message 'A commit summary could not be parsed safely.'
            continue
        }

        $subject = $parts[3]
        $subjectSensitive = $false
        if ($subject -match '-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----' -or
            $subject -match '(?i)(?:github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,})' -or
            $subject -match '(?<![A-Z0-9])(?:AKIA|ASIA)[A-Z0-9]{16}(?![A-Z0-9])' -or
            $subject -match '(?i)(?:xox[baprs]-[A-Za-z0-9-]{10,}|(?:_authToken|access[_-]?token|refresh[_-]?token)\s*[:=]\s*["'']?[A-Za-z0-9_./+=-]{16,})') {
            $subjectSensitive = $true
            Add-Finding -Severity blocker -Code 'SECRET_IN_COMMIT_SUBJECT' -Message 'A commit subject contains a high-confidence secret-shaped value.'
        }
        elseif ($subject -match '(?i)(?:api[_-]?key|client[_-]?secret|password|passwd|secret)\s*[:=]\s*["'']?[^\s"''#]{8,}') {
            $subjectSensitive = $true
            Add-Finding -Severity warning -Code 'SECRET_LIKE_COMMIT_SUBJECT' -Message 'A commit subject contains a secret-like assignment that needs human review.'
        }
        elseif ($subject -match '(?i)(?:[A-Za-z]:\\(?:Users|Documents and Settings)\\[^\\\s]+|/(?:Users|home)/[^/\s]+|\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b)') {
            $subjectSensitive = $true
            Add-Finding -Severity warning -Code 'PRIVATE_COMMIT_SUBJECT' -Message 'A commit subject contains a user path or email address.'
        }

        $commits.Add([ordered]@{
            sha         = $parts[0]
            authorName  = $parts[1]
            authorEmail = $parts[2]
            subject     = if ($subjectSensitive) { '[redacted: privacy finding]' } else { Protect-SensitiveText -Text $subject }
        })

        if ($parts[2] -notmatch '(?i)@users\.noreply\.github\.com$') {
            Add-Finding -Severity warning -Code 'AUTHOR_EMAIL' -Message 'A commit exposes a non-GitHub-noreply author email.' -Detail $parts[2]
        }
    }

    $nameArguments = @('log', '--name-only', '--format=') + $revisionArguments
    foreach ($line in (Invoke-Git -Root $repository -GitArguments $nameArguments).Lines) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $null = $files.Add($line)
        }
    }

    $numstatArguments = @('log', '--numstat', '--format=') + $revisionArguments
    foreach ($line in (Invoke-Git -Root $repository -GitArguments $numstatArguments).Lines) {
        if ($line -match "^-`t-`t(.+)$") {
            $null = $binaryFiles.Add($Matches[1])
        }
    }

    foreach ($path in $files) {
        $leaf = [System.IO.Path]::GetFileName($path)
        $lowerLeaf = $leaf.ToLowerInvariant()
        $isEnvironmentFile = $lowerLeaf -eq '.env' -or (
            $lowerLeaf.StartsWith('.env.') -and
            $lowerLeaf -notmatch '^\.env\.(?:example|sample|template|dist)$'
        )
        if ($isEnvironmentFile -or $lowerLeaf -in @('.npmrc', '.pypirc', '.netrc', '_netrc', 'id_rsa', 'id_ed25519', 'credentials.json')) {
            Add-Finding -Severity blocker -Code 'CREDENTIAL_FILE' -Message 'A credential-shaped file is present in the outgoing history.' -Path $path
        }
        elseif ($path -match '(?i)(?:^|[/\\])(?:private|personal|internal|secrets?)(?:[/\\]|[._-])') {
            Add-Finding -Severity warning -Code 'PRIVATE_CONTEXT_PATH' -Message 'A path name suggests private or internal content.' -Path $path
        }

        if ($lowerLeaf -match '\.(?:exe|dll|msi|pfx|p12|key|7z|rar)$') {
            Add-Finding -Severity warning -Code 'SUSPICIOUS_BINARY_ARTIFACT' -Message 'An executable, archive, key container, or similar binary artifact is in the outgoing history.' -Path $path
        }
    }

    $objectArguments = @('rev-list', '--objects') + $revisionArguments
    $objectLines = @((Invoke-Git -Root $repository -GitArguments $objectArguments).Lines | Where-Object { $_ -match '^[0-9a-fA-F]{40,64}(?:\s|$)' })
    if ($objectLines.Count -gt 0) {
        $objectIds = @($objectLines | ForEach-Object { ($_ -split ' ', 2)[0] } | Select-Object -Unique)
        $batchOutput = @($objectIds | & git -C $repository cat-file '--batch-check=%(objectname) %(objecttype) %(objectsize)' 2>$null)
        if ($LASTEXITCODE -ne 0) {
            $scanComplete = $false
            Add-Finding -Severity blocker -Code 'INCOMPLETE_OBJECT_SCAN' -Message 'Git object metadata could not be inspected completely.'
        }
        else {
            $pathByObject = @{}
            foreach ($objectLine in $objectLines) {
                $objectParts = $objectLine -split ' ', 2
                if ($objectParts.Count -eq 2 -and -not $pathByObject.ContainsKey($objectParts[0])) {
                    $pathByObject[$objectParts[0]] = $objectParts[1]
                }
            }

            foreach ($metadataLine in $batchOutput) {
                if ($metadataLine -notmatch '^(?<oid>[0-9a-fA-F]{40,64})\s+(?<type>\w+)\s+(?<size>\d+)$') {
                    continue
                }

                if ($Matches.type -eq 'blob' -and [long] $Matches.size -ge $LargeBlobBytes) {
                    $blobPath = if ($pathByObject.ContainsKey($Matches.oid)) { [string] $pathByObject[$Matches.oid] } else { $null }
                    Add-Finding -Severity warning -Code 'LARGE_BLOB' -Message 'A large Git blob is included in the outgoing history.' -Path $blobPath -Detail "$($Matches.size) bytes"
                }
            }
        }
    }

    $patchArguments = @('log', '-p', '--no-ext-diff', '--no-textconv', '--format=', '--find-renames') + $revisionArguments
    $currentPath = $null
    foreach ($line in (Invoke-Git -Root $repository -GitArguments $patchArguments).Lines) {
        if ($line -match '^\+\+\+ b/(.*)$') {
            $currentPath = $Matches[1]
            continue
        }

        if (-not $line.StartsWith('+') -or $line.StartsWith('+++')) {
            continue
        }

        $scannedTextLines++
        $content = $line.Substring(1)
        if ($content -match '-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----') {
            Add-Finding -Severity blocker -Code 'PRIVATE_KEY_CONTENT' -Message 'Private-key material was introduced in outgoing history.' -Path $currentPath
        }
        if ($content -match '(?i)(?:github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,})') {
            Add-Finding -Severity blocker -Code 'GITHUB_TOKEN' -Message 'A GitHub token-shaped value was introduced in outgoing history.' -Path $currentPath
        }
        if ($content -match '(?<![A-Z0-9])(?:AKIA|ASIA)[A-Z0-9]{16}(?![A-Z0-9])') {
            Add-Finding -Severity blocker -Code 'AWS_ACCESS_KEY' -Message 'An AWS access-key-shaped value was introduced in outgoing history.' -Path $currentPath
        }
        if ($content -match '(?i)(?:xox[baprs]-[A-Za-z0-9-]{10,}|(?:_authToken|access[_-]?token|refresh[_-]?token)\s*[:=]\s*["'']?[A-Za-z0-9_./+=-]{16,})') {
            Add-Finding -Severity blocker -Code 'AUTH_TOKEN' -Message 'An authentication token-shaped value was introduced in outgoing history.' -Path $currentPath
        }
        if ($content -match '(?i)(?:api[_-]?key|client[_-]?secret|password|passwd|secret)\s*[:=]\s*["'']?[^\s"''#]{8,}') {
            Add-Finding -Severity warning -Code 'GENERIC_SECRET_ASSIGNMENT' -Message 'A secret-like assignment was introduced and needs human review.' -Path $currentPath
        }
        if ($content -match '(?i)(?:[A-Za-z]:\\(?:Users|Documents and Settings)\\[^\\\s]+|/(?:Users|home)/[^/\s]+)') {
            Add-Finding -Severity warning -Code 'LOCAL_ABSOLUTE_PATH' -Message 'A user-specific absolute path was introduced.' -Path $currentPath
        }
        if ($content -match '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b' -and $content -notmatch '(?i)@users\.noreply\.github\.com\b') {
            Add-Finding -Severity warning -Code 'CONTENT_EMAIL' -Message 'A non-GitHub-noreply email address was introduced in file content.' -Path $currentPath
        }
        if ($content -match '(?i)\b(?:https?://)?(?:localhost|127\.0\.0\.1|10(?:\.\d{1,3}){3}|192\.168(?:\.\d{1,3}){2}|172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2})(?::\d+)?\b') {
            Add-Finding -Severity warning -Code 'INTERNAL_ADDRESS' -Message 'A localhost or private-network address was introduced.' -Path $currentPath
        }
    }
}

$blockerCount = @($findings | Where-Object { $_.severity -eq 'blocker' }).Count
$warningCount = @($findings | Where-Object { $_.severity -eq 'warning' }).Count
$decision = if ($blockerCount -gt 0) {
    'blocked'
}
elseif ($relationship -eq 'synchronized' -and $commitCount -eq 0) {
    'no_changes'
}
elseif ($warningCount -gt 0) {
    'warning'
}
else {
    'ready'
}

$report = [ordered]@{
    schemaVersion = 1
    repository    = [ordered]@{
        root        = $repository
        branch      = $branch
        head        = $head
        worktreeClean = $worktreeEntries.Count -eq 0
        worktreeEntries = @($worktreeEntries | ForEach-Object { Protect-SensitiveText -Text $_ })
    }
    target        = [ordered]@{
        remoteName   = $resolvedRemote
        remoteUrl    = $safeRemoteUrl
        targetBranch = $resolvedTargetBranch
        trackingRef  = $trackingRef
        mode         = if ($InitialPublication) { 'initial_publication' } else { 'update' }
        relationship = $relationship
    }
    scope         = [ordered]@{
        revision       = $revisionLabel
        commitCount    = $commitCount
        commits        = @($commits)
        files          = @($files | Sort-Object | ForEach-Object { Protect-SensitiveText -Text $_ })
        binaryFiles    = @($binaryFiles | Sort-Object | ForEach-Object { Protect-SensitiveText -Text $_ })
        scannedTextLines = $scannedTextLines
        scanComplete   = $scanComplete
    }
    findings      = @($findings)
    decision      = [ordered]@{
        status       = $decision
        blockerCount = $blockerCount
        warningCount = $warningCount
    }
}

$report | ConvertTo-Json -Depth 8
