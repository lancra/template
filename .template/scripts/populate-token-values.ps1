<#
.SYNOPSIS
Prompts for population of static token definition values in a specification.

.DESCRIPTION
Iterates through each token definition in specification from the provided
repository, prompting for a value if it is not provided as a parameter. The
resulting specification is then rewritten back to the target repository.

.PARAMETER Repository
The path of the template repository.

.PARAMETER Value
The token key-values to population in the target specification.

.PARAMETER NoPrompt
Specifies that a missing token value should trigger an error rather than
prompting for input.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Repository,

    [Parameter()]
    [hashtable] $Value = @{},

    [switch] $NoPrompt
)

$sourceSpecificationPath = "$Repository/.template/specification.json"
if (-not (Test-Path -Path $sourceSpecificationPath)) {
    throw "The template specification was not found at '$sourceSpecificationPath'."
}

$sourceSpecification = Get-Content -Path $sourceSpecificationPath |
    ConvertFrom-Json
$targetSpecification = @{
    executions = $sourceSpecification.executions
    tokens = @{}
}

$missingValueKeys = @()
$sourceSpecification.tokens.PSObject.Properties |
    Select-Object -ExpandProperty Name |
    ForEach-Object {
        $token = $sourceSpecification.tokens.$_
        if ($token.kind -ne 'static') {
            $targetSpecification.tokens.$_ = @{
                kind = $token.kind
                generator = $token.generator
            }

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

        $targetToken = @{
            kind = $token.kind
            value = $tokenValue
        }

        $targetSpecification.tokens.$_ = $targetToken

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

$targetSpecification |
    ConvertTo-Json -Depth 10 |
    Set-Content -Path "$PWD/.template.specification"
