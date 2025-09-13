<#
.SYNOPSIS
Adds a new token definition to a source specification.

.DESCRIPTION
Prompts for a key if not provided, and verifies its uniqueness and format. If
valid, prompts are used to set the remaining properties that were not provided.
The token definition is then added to the specification, and the new set of
tokens is sorted alphabetically before writing the new specification back to the
source.

.PARAMETER Source
The source template specification to add a token definition to.

.PARAMETER Key
The unique token key to add. If this is not provided, the user is prompted for
it at run-time.

.PARAMETER Description
The description of the token usage throughout the template. If this is not
provided, the user is prompted for it at run-time.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Source,

    [Parameter()]
    [string] $Key,

    [Parameter()]
    [string] $Description
)

if (-not (Test-Path -Path $Source)) {
    throw "The token specification was not found at '$Source'."
}

function Read-PropertyValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter()]
        [string] $Value
    )
    process {
        if (-not [string]::IsNullOrEmpty($Value)) {
            return $Value
        }

        Read-Host -Prompt $Name
    }
}

$tokenSpecification = Get-Content -Path $Source |
    ConvertFrom-Json

$Key = Read-PropertyValue -Name 'Key' -Value $Key

if (-not ($Key -match '^(?=[A-Z])[A-Z_].*(?<!_)$')) {
    throw "The token key '$Key' is not a valid format. " +
        'Keys can only contain uppercase letters and underscores, and must begin and end with a letter.'
}

$currentKeys = @($tokenSpecification.tokens.PSObject.Properties) |
    Select-Object -ExpandProperty Name
$isDuplicateKey = ($currentKeys |
    Where-Object { $_ -eq $Key } |
    Measure-Object |
    Select-Object -ExpandProperty Count) -ne 0
if ($isDuplicateKey) {
    throw "The '$Key' token is already defined in the specification."
}

$Description = Read-PropertyValue -Name 'Description' -Value $Description

$example = Read-PropertyValue -Name 'Example'

$tokenDefinition = [pscustomobject]@{
    value = $Key
    description = $Description
    example = $example
}

$tokenSpecification.tokens |
    Add-Member -MemberType NoteProperty -Name $Key -Value $tokenDefinition

$newTokenSpecification = [pscustomobject]@{
    '$schema' = $tokenSpecification.'$schema'
    tokens = [pscustomobject]@{}
}

$tokenSpecification.tokens.PSObject.Properties |
    Select-Object -ExpandProperty Name |
    Sort-Object |
    ForEach-Object {
        $newTokenSpecification.tokens |
            Add-Member -MemberType NoteProperty -Name $_ -Value $tokenSpecification.tokens.$_
    }

$newTokenSpecification |
    ConvertTo-Json |
    Set-Content -Path $Source
