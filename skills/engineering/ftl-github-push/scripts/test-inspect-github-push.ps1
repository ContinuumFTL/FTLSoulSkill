[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$inspectorPath = Join-Path $PSScriptRoot 'inspect-github-push.ps1'
$temporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryBase ("ftl-github-push-tests-" + [guid]::NewGuid().ToString('N'))

function Invoke-TestGit {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Root,

        [Parameter(Mandatory = $true)]
        [string[]] $GitArguments,

        [Parameter()]
        [switch] $ReturnOutput
    )

    $output = @(& git -c core.quotePath=false -C $Root @GitArguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Test git command failed in ${Root}: git $($GitArguments -join ' ')`n$($output -join "`n")"
    }

    if ($ReturnOutput) {
        return @($output | ForEach-Object { [string] $_ })
    }
}

function Set-TestIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Repository
    )

    Invoke-TestGit -Root $Repository -GitArguments @('config', 'user.name', 'FTL Push Test')
    Invoke-TestGit -Root $Repository -GitArguments @('config', 'user.email', '12345+ftl-push-test@users.noreply.github.com')
}

function New-LocalRepository {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $repository = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path $repository -Force | Out-Null
    Invoke-TestGit -Root $repository -GitArguments @('init', '-b', 'main')
    Set-TestIdentity -Repository $repository
    Set-Content -LiteralPath (Join-Path $repository 'README.md') -Value "# $Name" -Encoding UTF8
    Invoke-TestGit -Root $repository -GitArguments @('add', '--', 'README.md')
    Invoke-TestGit -Root $repository -GitArguments @('commit', '-m', 'test: initial commit')
    return $repository
}

function New-BareRemote {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $remote = Join-Path $testRoot "$Name.git"
    New-Item -ItemType Directory -Path $remote -Force | Out-Null
    Invoke-TestGit -Root $remote -GitArguments @('init', '--bare')
    return $remote
}

function New-PublishedFixture {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $repository = New-LocalRepository -Name $Name
    $remote = New-BareRemote -Name "$Name-remote"
    Invoke-TestGit -Root $repository -GitArguments @('remote', 'add', 'origin', $remote)
    Invoke-TestGit -Root $repository -GitArguments @('push', '-u', 'origin', 'main')
    Invoke-TestGit -Root $remote -GitArguments @('symbolic-ref', 'HEAD', 'refs/heads/main')
    return [pscustomobject]@{
        Repository = $repository
        Remote     = $remote
    }
}

function Add-TestCommit {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Repository,

        [Parameter(Mandatory = $true)]
        [string] $RelativePath,

        [Parameter(Mandatory = $true)]
        [string] $Content,

        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    $literalPath = Join-Path $Repository $RelativePath
    $parent = Split-Path -Parent $literalPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Set-Content -LiteralPath $literalPath -Value $Content -Encoding UTF8
    Invoke-TestGit -Root $Repository -GitArguments @('add', '--', $RelativePath)
    Invoke-TestGit -Root $Repository -GitArguments @('commit', '-m', $Message)
}

function Get-Inspection {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Repository,

        [Parameter()]
        [string] $RemoteName,

        [Parameter()]
        [string] $TargetBranch,

        [Parameter()]
        [switch] $InitialPublication,

        [Parameter()]
        [long] $LargeBlobBytes = 10MB
    )

    $invokeParameters = @{
        RepositoryRoot                = $Repository
        LargeBlobBytes                = $LargeBlobBytes
        AllowNonGitHubRemoteForTest   = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($RemoteName)) {
        $invokeParameters.RemoteName = $RemoteName
    }
    if (-not [string]::IsNullOrWhiteSpace($TargetBranch)) {
        $invokeParameters.TargetBranch = $TargetBranch
    }
    if ($InitialPublication) {
        $invokeParameters.InitialPublication = $true
    }

    $json = @(& $inspectorPath @invokeParameters)
    if ($LASTEXITCODE -ne 0) {
        throw "Inspector failed for $Repository"
    }

    return ($json -join "`n") | ConvertFrom-Json
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool] $Condition,

        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Assert-Finding {
    param(
        [Parameter(Mandatory = $true)]
        $Report,

        [Parameter(Mandatory = $true)]
        [string] $Code
    )

    $matches = @($Report.findings | Where-Object { $_.code -eq $Code })
    Assert-True -Condition ($matches.Count -gt 0) -Message "Expected finding $Code"
}

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

    $noRemoteRepository = New-LocalRepository -Name 'no-remote'
    $noRemoteReport = Get-Inspection -Repository $noRemoteRepository
    Assert-True -Condition ($noRemoteReport.decision.status -eq 'blocked') -Message 'A repository with no remote must be blocked.'
    Assert-Finding -Report $noRemoteReport -Code 'NO_REMOTE'

    $ambiguousRepository = New-LocalRepository -Name 'ambiguous-remote'
    $ambiguousRemoteOne = New-BareRemote -Name 'ambiguous-one'
    $ambiguousRemoteTwo = New-BareRemote -Name 'ambiguous-two'
    Invoke-TestGit -Root $ambiguousRepository -GitArguments @('remote', 'add', 'one', $ambiguousRemoteOne)
    Invoke-TestGit -Root $ambiguousRepository -GitArguments @('remote', 'add', 'two', $ambiguousRemoteTwo)
    $ambiguousReport = Get-Inspection -Repository $ambiguousRepository
    Assert-Finding -Report $ambiguousReport -Code 'AMBIGUOUS_REMOTE'

    $initialRepository = New-LocalRepository -Name 'initial-publication'
    $initialRemote = New-BareRemote -Name 'initial-publication-remote'
    Invoke-TestGit -Root $initialRepository -GitArguments @('remote', 'add', 'origin', $initialRemote)
    $initialReport = Get-Inspection -Repository $initialRepository -RemoteName origin -TargetBranch main -InitialPublication
    Assert-True -Condition ($initialReport.decision.status -eq 'ready') -Message 'A clean, explicitly targeted initial publication should be ready.'
    Assert-True -Condition ($initialReport.scope.commitCount -eq 1) -Message 'Initial publication must inspect complete history.'

    $pushFixture = New-PublishedFixture -Name 'ordinary-push'
    Add-TestCommit -Repository $pushFixture.Repository -RelativePath 'src/change.txt' -Content 'safe change' -Message 'test: add safe change'
    Set-Content -LiteralPath (Join-Path $pushFixture.Repository 'local-only.txt') -Value 'not committed' -Encoding UTF8
    $pushReport = Get-Inspection -Repository $pushFixture.Repository -RemoteName origin -TargetBranch main
    Assert-True -Condition ($pushReport.decision.status -eq 'ready') -Message 'A safe fast-forward update should be ready.'
    Assert-True -Condition (-not $pushReport.repository.worktreeClean) -Message 'Uncommitted work must be reported without entering the push scope.'
    Assert-True -Condition ($pushReport.scope.commitCount -eq 1) -Message 'Exactly one outgoing commit should be reported.'
    Invoke-TestGit -Root $pushFixture.Repository -GitArguments @('push', '--dry-run', 'origin', 'HEAD:refs/heads/main')
    Invoke-TestGit -Root $pushFixture.Repository -GitArguments @('push', 'origin', 'HEAD:refs/heads/main')
    $localHead = (Invoke-TestGit -Root $pushFixture.Repository -GitArguments @('rev-parse', 'HEAD') -ReturnOutput)[0]
    $remoteHeadLine = (Invoke-TestGit -Root $pushFixture.Repository -GitArguments @('ls-remote', '--heads', 'origin', 'refs/heads/main') -ReturnOutput)[0]
    $remoteHead = ($remoteHeadLine -split "`t", 2)[0]
    Assert-True -Condition ($localHead -eq $remoteHead) -Message 'The isolated remote SHA must match local HEAD after the exact push.'
    $synchronizedReport = Get-Inspection -Repository $pushFixture.Repository -RemoteName origin -TargetBranch main
    Assert-True -Condition ($synchronizedReport.decision.status -eq 'no_changes') -Message 'A synchronized branch should not request another push.'

    $remoteAheadFixture = New-PublishedFixture -Name 'remote-ahead'
    $remoteAheadPeer = Join-Path $testRoot 'remote-ahead-peer'
    Invoke-TestGit -Root $testRoot -GitArguments @('clone', $remoteAheadFixture.Remote, $remoteAheadPeer)
    Set-TestIdentity -Repository $remoteAheadPeer
    Add-TestCommit -Repository $remoteAheadPeer -RelativePath 'remote.txt' -Content 'remote change' -Message 'test: remote change'
    Invoke-TestGit -Root $remoteAheadPeer -GitArguments @('push', 'origin', 'main')
    Invoke-TestGit -Root $remoteAheadFixture.Repository -GitArguments @('fetch', '--no-tags', 'origin', 'refs/heads/main:refs/remotes/origin/main')
    $remoteAheadReport = Get-Inspection -Repository $remoteAheadFixture.Repository -RemoteName origin -TargetBranch main
    Assert-Finding -Report $remoteAheadReport -Code 'REMOTE_AHEAD'

    $divergedFixture = New-PublishedFixture -Name 'diverged'
    Add-TestCommit -Repository $divergedFixture.Repository -RelativePath 'local.txt' -Content 'local change' -Message 'test: local change'
    $divergedPeer = Join-Path $testRoot 'diverged-peer'
    Invoke-TestGit -Root $testRoot -GitArguments @('clone', $divergedFixture.Remote, $divergedPeer)
    Set-TestIdentity -Repository $divergedPeer
    Add-TestCommit -Repository $divergedPeer -RelativePath 'remote.txt' -Content 'remote change' -Message 'test: independent remote change'
    Invoke-TestGit -Root $divergedPeer -GitArguments @('push', 'origin', 'main')
    Invoke-TestGit -Root $divergedFixture.Repository -GitArguments @('fetch', '--no-tags', 'origin', 'refs/heads/main:refs/remotes/origin/main')
    $divergedReport = Get-Inspection -Repository $divergedFixture.Repository -RemoteName origin -TargetBranch main
    Assert-Finding -Report $divergedReport -Code 'DIVERGED'

    $secretFixture = New-PublishedFixture -Name 'secret-history'
    $privateKeyHeader = '-----BEGIN ' + 'PRIVATE KEY-----'
    Add-TestCommit -Repository $secretFixture.Repository -RelativePath 'temporary.txt' -Content "$privateKeyHeader`nfixture-only-data" -Message 'test: introduce secret fixture'
    Remove-Item -LiteralPath (Join-Path $secretFixture.Repository 'temporary.txt') -Force
    Invoke-TestGit -Root $secretFixture.Repository -GitArguments @('add', '--', 'temporary.txt')
    Invoke-TestGit -Root $secretFixture.Repository -GitArguments @('commit', '-m', 'test: remove secret fixture')
    $secretReport = Get-Inspection -Repository $secretFixture.Repository -RemoteName origin -TargetBranch main
    Assert-Finding -Report $secretReport -Code 'PRIVATE_KEY_CONTENT'
    Assert-True -Condition ($secretReport.decision.status -eq 'blocked') -Message 'A secret introduced and then deleted must still block because it remains in outgoing history.'

    $subjectSecretFixture = New-PublishedFixture -Name 'secret-subject'
    $fakeSubjectToken = 'ghp_' + ('A' * 24)
    Invoke-TestGit -Root $subjectSecretFixture.Repository -GitArguments @('commit', '--allow-empty', '-m', "test: accidental $fakeSubjectToken")
    $subjectSecretReport = Get-Inspection -Repository $subjectSecretFixture.Repository -RemoteName origin -TargetBranch main
    Assert-Finding -Report $subjectSecretReport -Code 'SECRET_IN_COMMIT_SUBJECT'
    Assert-True -Condition ($subjectSecretReport.scope.commits[0].subject -eq '[redacted: privacy finding]') -Message 'A secret-shaped commit subject must be redacted in the report.'

    $pathFixture = New-PublishedFixture -Name 'path-warning'
    $localPath = 'C:' + '\Users\ExampleUser\source'
    Add-TestCommit -Repository $pathFixture.Repository -RelativePath 'config.txt' -Content "workspace=$localPath" -Message 'test: add local path fixture'
    $pathReport = Get-Inspection -Repository $pathFixture.Repository -RemoteName origin -TargetBranch main
    Assert-Finding -Report $pathReport -Code 'LOCAL_ABSOLUTE_PATH'
    Assert-True -Condition ($pathReport.decision.status -eq 'warning') -Message 'A local path should warn rather than block.'

    $internalAddressFixture = New-PublishedFixture -Name 'internal-address-warning'
    $internalEndpoint = 'http://' + 'localhost:8080'
    Add-TestCommit -Repository $internalAddressFixture.Repository -RelativePath 'service.txt' -Content "endpoint=$internalEndpoint" -Message 'test: add internal address fixture'
    $internalAddressReport = Get-Inspection -Repository $internalAddressFixture.Repository -RemoteName origin -TargetBranch main
    Assert-Finding -Report $internalAddressReport -Code 'INTERNAL_ADDRESS'

    $largeFixture = New-PublishedFixture -Name 'large-blob'
    Add-TestCommit -Repository $largeFixture.Repository -RelativePath 'asset.bin' -Content ('x' * 512) -Message 'test: add large fixture'
    $largeReport = Get-Inspection -Repository $largeFixture.Repository -RemoteName origin -TargetBranch main -LargeBlobBytes 128
    Assert-Finding -Report $largeReport -Code 'LARGE_BLOB'

    Write-Output 'All GitHub push inspection tests passed.'
}
finally {
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    $expectedPrefix = $temporaryBase.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (
        $resolvedTestRoot.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedTestRoot).StartsWith('ftl-github-push-tests-', [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        if (Test-Path -LiteralPath $resolvedTestRoot) {
            Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
        }
    }
    else {
        throw "Refusing to clean an unexpected test path: $resolvedTestRoot"
    }
}
