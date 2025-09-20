<#
.SYNOPSIS
Prompts for population of static token definition values in a specification.

.DESCRIPTION
Iterates through each token definition in the provided specification, prompting
for a value. The resulting specification is finally rewritten back to the file.

.PARAMETER TokenPath
The source template specification to add token values to.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $TokenPath
)

if (-not (Test-Path -Path $TokenPath)) {
    throw "The token specification was not found at '$TokenPath'."
}

$tokenSpecification = Get-Content -Path $TokenPath |
    ConvertFrom-Json

$tokenSpecification.tokens.PSObject.Properties |
    Select-Object -ExpandProperty Name |
    ForEach-Object {
        if ($tokenSpecification.tokens.$_.kind -ne 'static') {
            return
        }

        $tokenSpecification.tokens.$_.value = Read-Host -Prompt "$_ ($($tokenSpecification.tokens.$_.description))"
    }

$tokenSpecification |
    ConvertTo-Json |
    Set-Content -Path $TokenPath
