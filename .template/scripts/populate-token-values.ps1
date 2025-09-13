<#
.SYNOPSIS
Prompts for population of static token definition values in a specification.

.DESCRIPTION
Iterates through each token definition in the provided specification, prompting
for a value. The resulting specification is finally rewritten back to the file.

.PARAMETER Source
The source template specification to add token values to.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Source
)

if (-not (Test-Path -Path $Source)) {
    throw "The token specification was not found at '$Source'."
}

$tokenSpecification = Get-Content -Path $Source |
    ConvertFrom-Json

$tokenSpecification.static.PSObject.Properties |
    Select-Object -ExpandProperty Name |
    ForEach-Object {
        $tokenSpecification.static.$_.value = Read-Host -Prompt "$_ ($($tokenSpecification.static.$_.description))"
    }

$tokenSpecification |
    ConvertTo-Json |
    Set-Content -Path $Source
