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

function Get-PackageVersion {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Id
    )
    process {
        $packageSearchResult = & dotnet package search $Id --exact-match --source https://api.nuget.org/v3/index.json --format json |
        ConvertFrom-Json
        $packageSourceSearchResult = $packageSearchResult |
            Select-Object -ExpandProperty 'searchResult' |
            Select-Object -First 1
        $package = $packageSourceSearchResult |
            Select-Object -ExpandProperty 'packages' |
            Select-Object -Last 1
        return $package.Version
    }
}

$msBuildExtensions = @('.csproj', '.props')
if ([System.IO.Path]::GetExtension($Path) -in $msBuildExtensions) {
    $element = [xml]$Text
    $packageId = $element.ChildNodes.Include

    return Get-PackageVersion -Id $packageId
}

if ([System.IO.Path]::GetFileName($Path) -eq 'dotnet-tools.json') {
    $previousLineText = Get-Content -Path $Path -TotalCount $Line |
        Select-Object -Last 2 |
        Select-Object -First 1

    $packageGroup = 'package'
    $packageId = $previousLineText |
        Select-String -Pattern "\`"(?<$packageGroup>.+?)\`": {" |
        Select-Object -ExpandProperty Matches |
        Select-Object -ExpandProperty Groups |
        Where-Object -Property Name -EQ $packageGroup |
        Select-Object -ExpandProperty Value

    return Get-PackageVersion -Id $packageId
}

Write-Error "Unable to produce NuGet version from line $Line in ${Path}: '$Text'"
return $Text
