[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Specification,

    [switch] $SkipWait
)

$todoFile = '.template.todo'
$nextCommit = & "$PSScriptRoot/next-todo-commit.ps1" -Path $todoFile
while ($null -ne $nextCommit) {
    & "$PSScriptRoot/execute-script.ps1" -Kind 'Group' -Message "Applying '$($nextCommit.Message)'" -Script {
        & "$PSScriptRoot/apply-commit.ps1" -Specification $Specification
    }

    $nextCommit = & "$PSScriptRoot/next-todo-commit.ps1" -Path $todoFile
    if ($null -ne $nextCommit -and -not $SkipWait) {
        Read-Host -Prompt 'Press enter to apply the next commit' |
            Out-Null
    }
}
