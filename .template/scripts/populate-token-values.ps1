<#
.SYNOPSIS
Prompts for population of static token definition values in a specification.

.DESCRIPTION
Iterates through each token definition in the provided specification, prompting
for a value. The resulting specification is finally rewritten back to the file.

.PARAMETER Specification
The source template specification to add token values to.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Specification
)

if (-not (Test-Path -Path $Specification)) {
    throw "The template specification was not found at '$Specification'."
}

$specificationInstance = Get-Content -Path $Specification |
    ConvertFrom-Json

$specificationInstance.tokens.PSObject.Properties |
    Select-Object -ExpandProperty Name |
    ForEach-Object {
        $token = $specificationInstance.tokens.$_
        if ($token.kind -ne 'static') {
            return
        }

        $examplePrefix = $token.default ? 'default' : 'e.g.'
        $prompt = "${_}:`n$($token.description) ($examplePrefix '$($token.example)')"
        $userInput = ''
        while (-not $userInput) {
            $userInput = Read-Host -Prompt $prompt

            if (-not $userInput) {
                if ($token.default) {
                    $userInput = $token.example
                } else {
                    Write-Output "`e[33mPlease provide a value.`e[39m"
                }
            }
        }

        $specificationInstance.tokens.$_.value = $userInput
        Write-Output ''
    }

$specificationInstance |
    ConvertTo-Json |
    Set-Content -Path $Specification
