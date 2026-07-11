<#
.SYNOPSIS
Prompts for population of static token definition values in a specification.

.DESCRIPTION
Iterates through each token definition in the provided specification, prompting
for a value if it is not provided as a parameter. The resulting specification is
then rewritten back to the file.

.PARAMETER Specification
The source template specification to add token values to.

.PARAMETER Value
The token key-values to population in the target specification.

.PARAMETER NoPrompt
Specifies that a missing token value should trigger an error rather than
prompting for input.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Specification,

    [Parameter()]
    [hashtable] $Value = @{},

    [switch] $NoPrompt
)

if (-not (Test-Path -Path $Specification)) {
    throw "The template specification was not found at '$Specification'."
}

$specificationInstance = Get-Content -Path $Specification |
    ConvertFrom-Json

$missingValueKeys = @()
$specificationInstance.tokens.PSObject.Properties |
    Select-Object -ExpandProperty Name |
    ForEach-Object {
        $token = $specificationInstance.tokens.$_
        if ($token.kind -ne 'static') {
            return
        }

        $examplePrefix = $token.default ? 'default' : 'e.g.'
        $tokenValue = $Value[$_]
        $tokenDefaultValue = $token.default ? $token.example : $null

        $promptRequired = -not $tokenValue
        if ($promptRequired -and $NoPrompt) {
            if ($tokenDefaultValue) {
                $tokenValue = $tokenDefaultValue
            } else {
                $missingValueKeys += $_
                return
            }
        }

        $prompt = "${_}:`n$($token.description) ($examplePrefix '$($token.example)')"
        while (-not $tokenValue) {
            $tokenValue = Read-Host -Prompt $prompt

            if (-not $tokenValue) {
                if ($tokenDefaultValue) {
                    $tokenValue = $tokenDefaultValue
                } else {
                    Write-Output "$($PSStyle.Foreground.Yellow)Please provide a value.$($PSStyle.Reset)"
                }
            }
        }

        $specificationInstance.tokens.$_.value = $tokenValue

        if ($promptRequired -and -not $NoPrompt) {
            Write-Output ''
        }
    }

if ($missingValueKeys.Length -gt 0) {
    Write-Output "$($PSStyle.Foreground.Red)Please provide the missing values below or execute with prompts enabled.$($PSStyle.Reset)"
    $missingValueKeys |
        ForEach-Object {
            Write-Output $_
        }
    exit 1
}

$specificationInstance |
    ConvertTo-Json -Depth 3 |
    Set-Content -Path $Specification
