[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Message,

    [Parameter(Mandatory)]
    [scriptblock] $Script
)

$headerLength = 120
$separatorCharacter = '='

$headerPrefix = [string]::new($separatorCharacter, 4)
$header = "$headerPrefix$Message$([string]::new($separatorCharacter, $headerLength - $Message.Length - $headerPrefix.Length))"
Write-Output $header

& $Script

Write-Output ''
