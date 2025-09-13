<#
.SYNOPSIS
Applies a template commit to the current repository.

.DESCRIPTION
First, the template TODO file is setup if not present. Then, the first commit
without an indicator is cherry-picked into the repository, the provided tokens
are replaced into it, and any notes executions are run. Finally, the indicator
is added to the applied commit in the TODO file.

.PARAMETER TokenPath
The location of the specification to use for token replacement.

.PARAMETER Template
The target template to use for application.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Template,

    [Parameter(Mandatory)]
    [string] $TokenPath
)

$status = git status --short
if ($null -ne $status) {
    throw "Template commits must be applied with a clean working directory."
}

$todoFile = '.template.todo'

$inRepositoryRoot = Test-Path -Path '.git'
if (-not $inRepositoryRoot) {
    throw "Template commits must be applied from the repository root."
}

git rev-parse --verify --quiet "template/$Template" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "The $Template template was not found in the template remote."
}

if (-not (Test-Path -Path $TokenPath)) {
    throw "The provided token source '$TokenPath' could not be found."
}

$script:ignoringTodo = $false
$localIgnoreFile = '.git/info/exclude'
Get-Content -Path $localIgnoreFile |
    ForEach-Object {
        if ($_ -eq $todoFile) {
            $script:ignoringTodo = $true
        }
    }

if (-not $script:ignoringTodo) {
    Add-Content -Path $localIgnoreFile -Value "$todoFile`n" -NoNewline
}

$todoInProgress = Test-Path -Path $todoFile
if (-not $todoInProgress) {
    git --no-pager log --oneline --reverse --format="  %H %s" "template/$Template-base..template/$Template" > $todoFile
}

$todoLines = Get-Content -Path $todoFile

$indication = '*'
$indicatorGroupName = 'indicator'
$idGroupName = 'id'
$messageGroupName = 'message'
$commitMatches = $todoLines |
    Select-String -Pattern "(?<$indicatorGroupName>[$indication ]{1}) (?<$idGroupName>[0-9a-f]{40}) (?<$messageGroupName>.+)" |
    Select-Object -ExpandProperty Matches

$nextCommitMatch = $commitMatches |
    ForEach-Object {
        $indicatedGroup = $_ |
            Select-Object -ExpandProperty Groups |
            Where-Object -Property Name -EQ $indicatorGroupName |
            Where-Object -Property Value -NE $indication
        if ($indicatedGroup) {
            return $_
        }
    } |
    Select-Object -First 1
if (-not $nextCommitMatch) {
    Write-Output 'All template commits have been applied.'
    exit 0
}

function Get-CommitGroupValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Text.RegularExpressions.Match] $Commit,

        [Parameter(Mandatory)]
        [string] $Group
    )
    process {
        $Commit |
            Select-Object -ExpandProperty Groups |
            Where-Object -Property Name -EQ $Group |
            Select-Object -ExpandProperty Value
    }
}

$id = Get-CommitGroupValue -Commit $nextCommitMatch -Group $idGroupName
$message = Get-CommitGroupValue -Commit $nextCommitMatch -Group $messageGroupName

Write-Output "Applying '$message'."
git cherry-pick $id
& "$PSScriptRoot/replace-tokens.ps1" -Source $TokenPath

Write-Output ''
Write-Output "Amending '$message' with token replacements."
git add .
git commit --amend --no-edit

function Set-NoteVariable {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Text
    )
    process {
        $Text -replace '\$repository', "$PSScriptRoot/../.." `
            -replace '\$message', $message
    }
}

$noteId = git notes list $id 2> $null
if ($null -ne $noteId) {
    git show $noteId |
        ConvertFrom-Json |
        Select-Object -ExpandProperty 'executions' |
        ForEach-Object {
            $display = Set-NoteVariable -Text $_.display
            Write-Output ''
            Write-Output $display

            $_ |
                Select-Object -ExpandProperty 'commands' |
                ForEach-Object {
                    Set-NoteVariable $_ |
                        Invoke-Expression
                }
        }
}

$newCommitMatchLine = "*$($nextCommitMatch.Value.Substring(1))"
$todoLines -replace $nextCommitMatch.Value, $newCommitMatchLine |
    Set-Content -Path $todoFile
