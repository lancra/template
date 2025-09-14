<#
.SYNOPSIS
Sets up the current repository for template application.

.DESCRIPTION
Retrieves the target branches from template repository, sets up the template
repository as a remote on the current repository, and extracts the token
specification to a location.

.PARAMETER RepositoryPath
The path of the template repository.

.PARAMETER TokenPath
The location of the token specification to create.

.PARAMETER Template
The target template to apply.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $RepositoryPath,

    [Parameter(Mandatory)]
    [string] $TokenPath,

    [Parameter(Mandatory)]
    [string] $Template
)

$inRepositoryRoot = Test-Path -Path '.git'
if (-not $inRepositoryRoot) {
    throw "Repository setup must be executed from the repository root."
}

$isTemplateRepositoryRoot = Test-Path -Path "$RepositoryPath/.git"
if (-not $isTemplateRepositoryRoot) {
    throw "The provided repository path must be the root of the template repository."
}

if (-not (Test-Path -Path $TokenPath)) {
    throw "The provided token source '$TokenPath' could not be found."
}

git -C $RepositoryPath rev-parse --verify --quiet "origin/$Template" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "The $Template template was not found in the template repository."
}

Write-Output "Fetching notes for template repository."
git -C $RepositoryPath fetch origin refs/notes/*:refs/notes/*
Write-Output ''

Write-Output "Creating local template branches for '$Template'."
git -C $RepositoryPath branch --track "base-$Template" "origin/base-$Template"
git -C $RepositoryPath branch --track "$Template" "origin/$Template"
Write-Output ''

Write-Output "Switching to target template branch."
git -C $RepositoryPath switch "$Template"
Write-Output ''

Write-Output "Adding template remote to current repository."
git remote add template $RepositoryPath
git remote update template
Write-Output ''

Write-Output "Fetching notes for template remote."
git fetch template refs/notes/*:refs/notes/*
Write-Output ''

Write-Output "Extracting template tokens to '$TokenPath'."
git show "template/${Template}:.template/tokens.json" > $TokenPath

$todoFile = '.template.todo'

Write-Output "Adding template TODO to local ignore file."
Add-Content -Path '.git/info/exclude' -Value "$todoFile`n" -NoNewline

Write-Output "Creating template TODO."
git --no-pager log --oneline --reverse --format="  %H %s" "template/base-$Template..template/$Template" > $todoFile
