[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [string] $Path,

    [Parameter(Mandatory)]
    [string] $Text,

    [Parameter(Mandatory)]
    [int] $Line
)

$guidInstance = New-Guid

return $guidInstance.Guid
