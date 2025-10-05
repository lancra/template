<#
.SYNOPSIS
Applies a template commit to the current repository.

.DESCRIPTION
First, the template TODO file is setup if not present. Then, the first commit
without an indicator is cherry-picked into the repository, the provided tokens
are replaced into it, and any notes executions are run. Finally, the indicator
is added to the applied commit in the TODO file.

.PARAMETER Specification
The location of the template specification to use.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Specification
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

if (-not (Test-Path -Path $Specification)) {
    throw "The template specification was not found at '$Specification'."
}

$nextCommit = & "$PSScriptRoot/next-todo-commit.ps1" -Path $todoFile
if ($null -eq $nextCommit) {
    Write-Output 'All template commits have been applied.'
    exit 0
}

$commitId = $nextCommit.Id
$commitMessage = $nextCommit.Message

enum ExecutionSource {
    Note
    Specification
}

enum ApplicationStage {
    Pick
    Replace
    Add
    Commit
}

class Execution {
    [ExecutionSource] $Source
    [ApplicationStage] $Stage
    [string] $Display
    [string[]] $Commands

    Execution([ExecutionSource] $source, [ApplicationStage] $stage, [string] $display, [string[]] $commands) {
        $this.Source = $source
        $this.Stage = $stage
        $this.Display = $display
        $this.Commands = $commands
    }

    static [Execution[]] FromSourceJson([ExecutionSource] $source, [string] $json) {
        return $json |
            ConvertFrom-Json |
            Select-Object -ExpandProperty 'executions' |
            ForEach-Object {
                $stage = [ApplicationStage]$_.stage
                $commands = $_.commands |
                    ForEach-Object {
                        $_ -replace '\$repository', "$PSScriptRoot/../.."
                    }

                [Execution]::new($source, $stage, $_.display, $commands)
            }
    }
}

$noteId = git notes list $commitId 2> $null
$executions = [Execution]::FromSourceJson([ExecutionSource]::Specification, (Get-Content -Path $Specification))
if ($null -ne $noteId) {
    $executions += [Execution]::FromSourceJson([ExecutionSource]::Note, (git show $noteId))
}

function Invoke-Execution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ApplicationStage] $Stage,

        [Parameter()]
        [Execution[]] $Execution
    )
    process {
        $stageExecutions = @($Execution |
            Where-Object -Property Stage -EQ $Stage)
        if ($stageExecutions.Length -eq 0) {
            return
        }

        [System.Enum]::GetNames([ExecutionSource]) |
            ForEach-Object {
                $sourceExecutions = @($stageExecutions |
                    Where-Object -Property Source -eq $_)
                if ($sourceExecutions.Length -eq 0) {
                    return
                }

                & "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Invoking $Stage executions from the $_ source" -Script {
                    $sourceExecutions |
                        ForEach-Object {
                            Write-Output $_.Display
                            $_.Commands |
                                ForEach-Object {
                                    $_ |
                                        Invoke-Expression
                                }
                        }
                }
            }
    }
}

& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Picking '$commitMessage'" -Script {
    git cherry-pick --no-commit $commitId
}

Invoke-Execution -Stage ([ApplicationStage]::Pick) -Execution $executions

& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Replacing tokens" -Script {
    & "$PSScriptRoot/replace-tokens.ps1" -Specification $Specification
}

Invoke-Execution -Stage ([ApplicationStage]::Replace) -Execution $executions

& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Adding changes" -Script {
    git add .
}

Invoke-Execution -Stage ([ApplicationStage]::Add) -Execution $executions

& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Committing '$commitMessage'" -Script {
    git commit --message "$commitMessage"
}

Invoke-Execution -Stage ([ApplicationStage]::Commit) -Execution $executions

$newNextCommitLine = "*$($nextCommit.Line.Substring(1))"
$todoLines = Get-Content -Path $todoFile
$todoLines -replace $nextCommit.Line, $newNextCommitLine |
    Set-Content -Path $todoFile
