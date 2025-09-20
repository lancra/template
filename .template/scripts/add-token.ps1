<#
.SYNOPSIS
Adds a new token definition to a source specification.

.DESCRIPTION
Prompts for a key if not provided, and verifies its uniqueness and format. If
valid, prompts are used to set the remaining properties that were not provided.
The token definition is then added to the specification, and the new set of
tokens is sorted alphabetically before writing the new specification back to the
source.

.PARAMETER TokenPath
The source template specification to add a token definition to.

.PARAMETER Kind
The kind of template token to add.

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
    [string] $TokenPath,

    [Parameter(Mandatory)]
    [ValidateSet('Generated', 'Static')]
    [string] $Kind,

    [Parameter()]
    [string] $Key,

    [Parameter()]
    [string] $Description
)

$generatedTokenKind = 'Generated'
$staticTokenKind = 'Static'

if (-not (Test-Path -Path $TokenPath)) {
    throw "The token specification was not found at '$TokenPath'."
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

$tokenSpecification = Get-Content -Path $TokenPath |
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

$tokenDefinition = [pscustomobject]@{
    description = $Description
    kind = $Kind
}
if ($Kind -eq $generatedTokenKind) {
    $generator = Read-PropertyValue -Name 'Generator'

    $generatorRelativePath = "generators/$generator"
    $generatorAbsolutePath = "$PSScriptRoot/$generatorRelativePath" -replace '\\', '/'
    if (-not (Test-Path -Path $generatorAbsolutePath)) {
        throw "The provided generator was not found at '$generatorAbsolutePath'."
    }

    $tokenDefinition |
        Add-Member -MemberType NoteProperty -Name 'generator' -Value "./$generatorRelativePath"
} elseif ($Kind -eq $staticTokenKind) {
    $tokenDefinition |
        Add-Member -MemberType NoteProperty -Name 'value' -Value $Key

    $example = Read-PropertyValue -Name 'Example'

    $tokenDefinition |
        Add-Member -MemberType NoteProperty -Name 'example' -Value $example
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
    Set-Content -Path $TokenPath
