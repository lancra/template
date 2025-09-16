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
#>

[CmdletBinding()]
param(
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

if (-not (Test-Path -Path $TokenPath)) {
    throw "The provided token source '$TokenPath' could not be found."
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

enum ApplicationStage {
    Pick
    Replace
    Add
    Commit
}

class NoteExecution {
    [ApplicationStage] $Stage
    [string] $Display
    [string[]] $Commands

    NoteExecution([ApplicationStage] $stage, [string] $display, [string[]] $commands) {
        $this.Stage = $stage
        $this.Display = $display
        $this.Commands = $commands
    }

    static [NoteExecution[]] FromJson([string] $json) {
        return $json |
            ConvertFrom-Json |
            Select-Object -ExpandProperty 'executions' |
            ForEach-Object {
                $stage = [ApplicationStage]$_.stage
                $commands = $_.commands |
                    ForEach-Object {
                        $_ -replace '\$repository', "$PSScriptRoot/../.."
                    }

                [NoteExecution]::new($stage, $_.display, $commands)
            }
    }
}

$noteId = git notes list $id 2> $null
$noteExecutions = @()
if ($null -ne $noteId) {
    $noteExecutions = [NoteExecution]::FromJson((git show $noteId))
}

function Invoke-NoteExecution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ApplicationStage] $Stage,

        [Parameter()]
        [NoteExecution[]] $Execution
    )
    process {
        $stageExecutions = @($Execution |
            Where-Object -Property Stage -EQ $Stage)
        if ($stageExecutions.Length -eq 0) {
            return
        }

        Write-Output "Invoking $Stage notes executions."
        $stageExecutions |
            ForEach-Object {
                Write-Output $_.Display
                $_.Commands |
                    ForEach-Object {
                        $_ |
                            Invoke-Expression
                    }

                Write-Output ''
            }
    }
}

Write-Output "Picking '$message'."
git cherry-pick --no-commit $id
Write-Output ''
Invoke-NoteExecution -Stage ([ApplicationStage]::Pick) -Execution $noteExecutions

Write-Output "Replacing tokens."
& "$PSScriptRoot/replace-tokens.ps1" -TokenPath $TokenPath
Write-Output ''
Invoke-NoteExecution -Stage ([ApplicationStage]::Replace) -Execution $noteExecutions

Write-Output "Adding changes."
git add .
Write-Output ''
Invoke-NoteExecution -Stage ([ApplicationStage]::Add) -Execution $noteExecutions

Write-Output "Committing '$message'."
git commit --message "$message"
Invoke-NoteExecution -Stage ([ApplicationStage]::Commit) -Execution $noteExecutions

$newCommitMatchLine = "*$($nextCommitMatch.Value.Substring(1))"
$todoLines -replace $nextCommitMatch.Value, $newCommitMatchLine |
    Set-Content -Path $todoFile
