[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Group', 'Task')]
    [string] $Kind,

    [Parameter(Mandatory)]
    [string] $Message,

    [Parameter(Mandatory)]
    [scriptblock] $Script
)

$headerLength = 120
$separatorCharacter = switch ($Kind) {
    'Group' { '=' }
    'Task' { '-' }
}

$headerPrefix = [string]::new($separatorCharacter, 4)
$header = "$headerPrefix$Message$([string]::new($separatorCharacter, $headerLength - $Message.Length - $headerPrefix.Length))"
Write-Output $header

& $Script

if ($Kind -eq 'Task') {
    Write-Output ''
}
