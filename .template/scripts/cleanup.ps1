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

$todoFile = '.template.todo'

Write-Output "Removing template TODO."
Remove-Item -Path $todoFile

Write-Output "Removing template TODO from local ignore file."
$localIgnoreFile = '.git/info/exclude'
$newIgnoreLines = Get-Content -Path $localIgnoreFile |
    ForEach-Object {
        if ($_ -eq $todoFile) {
            return
        }

        return $_
    }

Set-Content -Path $localIgnoreFile -Value $newIgnoreLines

Write-Output "Removing template repository."
Remove-Item -Path $Repository -Recurse -Force

Write-Output "Performing Git garbage collection."
git gc --prune=now
Write-Output ''

Write-Output "Pruning template notes."
git notes prune -v
