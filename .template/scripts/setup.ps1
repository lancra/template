<#
.SYNOPSIS
Sets up the current repository for template application.

.DESCRIPTION
Retrieves the target branches from template repository, sets up the template
repository as a remote on the current repository, and extracts the template
specification to a location.

.PARAMETER Repository
The path of the template repository.

.PARAMETER Template
The target template to apply.

.PARAMETER SkipTokens
Specifies that token population should be skipped.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Repository,

    [Parameter(Mandatory)]
    [string] $Template,

    [switch] $SkipTokens
)

$inRepositoryRoot = Test-Path -Path '.git'
if (-not $inRepositoryRoot) {
    throw "Repository setup must be executed from the repository root."
}

$isTemplateRepositoryRoot = Test-Path -Path "$Repository/.git"
if (-not $isTemplateRepositoryRoot) {
    throw "The provided repository path must be the root of the template repository."
}

git -C $Repository rev-parse --verify --quiet "origin/$Template" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "The $Template template was not found in the template repository."
}

if ($Template -eq 'main' -or $Template -eq 'base' -or $Template.StartsWith('base-')) {
    throw "The $Template infrastructure template cannot be used."
}

$templateParent = $Template.Contains('-') ? $Template.Split('-')[0] : $Template

& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Fetching notes for template repository" -Script {
    git -C $Repository fetch origin refs/notes/*:refs/notes/*
}

& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Creating local template branches for '$Template'" -Script {
    git -C $Repository branch --track "base-$templateParent" "origin/base-$templateParent" 2> $null
    git -C $Repository branch --track "$Template" "origin/$Template" 2> $null
}

& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Switching to target template branch" -Script {
    git -C $Repository switch "$Template"
}

& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Adding template remote to current repository" -Script {
    git remote add template $Repository
    git remote update template
}


& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Fetching notes for template remote" -Script {
    git fetch template refs/notes/*:refs/notes/*
}


& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Disabling reuse of recorded resolutions in repository" -Script {
    git config set --local rerere.enabled false
}

$specificationFile = '.template.specification'
$todoFile = '.template.todo'

& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Adding template infrastructure to local ignore file" -Script {
    Add-Content -Path '.git/info/exclude' -Value "$specificationFile`n" -NoNewline
    Add-Content -Path '.git/info/exclude' -Value "$todoFile`n" -NoNewline
}

& "$PSScriptRoot/execute-script.ps1" -Kind 'Task' -Message "Creating template infrastructure" -Script {
    git --no-pager log --oneline --reverse --format="  %H %s" "template/base-$templateParent..template/$Template" > $todoFile

    if (-not $SkipTokens) {
        & $PSScriptRoot/populate-token-values.ps1 -Repository $Repository
    }
}
