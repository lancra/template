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
        $token = $tokenSpecification.tokens.$_
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

        $tokenSpecification.tokens.$_.value = $userInput
        Write-Output ''
    }

$tokenSpecification |
    ConvertTo-Json |
    Set-Content -Path $TokenPath
