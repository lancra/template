<#
.SYNOPSIS
Cleans up traces of the template process from the current repository.

.DESCRIPTION
Removes the template remote, the TODO file with its ignore entry, and the cloned
template repository.

.PARAMETER Repository
The path of the template repository.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Repository
)

Write-Output "Removing template remote from current repository."
git remote remove template

$templateInfrastructure = @(
    '.template.specification',
    '.template.todo'
)

Write-Output "Removing template infrastructure."
Remove-Item -Path '*' -Include $templateInfrastructure

Write-Output "Removing template infrastructure from local ignore file."
$localIgnoreFile = '.git/info/exclude'
$newIgnoreLines = Get-Content -Path $localIgnoreFile |
    ForEach-Object {
        if ($templateInfrastructure -contains $_) {
            return
        }

        return $_
    }

Set-Content -Path $localIgnoreFile -Value $newIgnoreLines

Write-Output "Removing template repository."
Remove-Item -Path $Repository -Recurse -Force

Write-Output "Removing reuse of recorded resolutions configuration in repository."
git config unset --local rerere.enabled

Write-Output "Performing Git garbage collection."
git gc --prune=now
Write-Output ''

Write-Output "Pruning template notes."
git notes prune -v
