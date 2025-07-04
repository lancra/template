<#
.SYNOPSIS
Adds the specified license file to the provided directory.

.DESCRIPTION
Retrieves the list of licenses from the GitHub API to verify the provided key.
Then, the specified license body is retrieved and any fields are identified and
replaced via a regular expression. Once the license body is finalized, the
LICENSE file is written to the provided directory.

.PARAMETER Target
The directory to add the license in.

.PARAMETER License
The key of the license to add.

.PARAMETER Author
The author of the repository to be added to applicable licenses.

.PARAMETER Force
Specifies that an existing license file should be overwritten.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $License,

    [Parameter(Mandatory)]
    [string] $Author,

    [Parameter()]
    [string] $Target = $PWD,

    [switch] $Force
)

if ($null -eq (Get-Command -Name gh -ErrorAction SilentlyContinue)) {
    throw 'The GitHub CLI must be installed and available to add a license. ' + `
        'Install it on Windows via `winget install --exact --id GitHub.cli`.'
}

$directory = Get-Item -Path $Target -ErrorAction SilentlyContinue
if ($null -eq $directory) {
    throw "The provided target '$Target' does not exist."
} elseif (-not $directory.PSIsContainer) {
    throw "The provided target is not a directory."
}

$licensePath = Join-Path -Path $Target -ChildPath 'LICENSE'
if ((Test-Path -Path $licensePath) -and -not $Force) {
    throw "Found an existing license at '$licensePath'. Overwrite it by providing the Force parameter."
}

$licenseKeys = & gh api '/licenses' |
    ConvertFrom-Json |
    Select-Object -ExpandProperty key
if (-not ($licenseKeys -icontains $License)) {
    throw "The key '$License' does not represent a valid license. Review available licenses using ``gh api /licenses``."
}

$licenseBody = & gh api "/licenses/$License" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty body

$fields = @{}
$fields['fullname'] = $Author
$fields['name of copyright owner'] = $Author

$year = (Get-Date).Year
$fields['year'] = $year
$fields['yyyy'] = $year

$fieldGroupName = 'field'
$keyGroupName = 'key'
$licenseBody |
    Select-String -AllMatches -Pattern "(?<$fieldGroupName>\[(?<$keyGroupName>.+?)\])" |
    Select-Object -ExpandProperty Matches |
    ForEach-Object {
        $keyGroup = $_.Groups |
            Where-Object -Property Name -EQ $keyGroupName
        $value = $fields[$keyGroup.Value]

        $fieldGroup = $_.Groups |
            Where-Object -Property Name -EQ $fieldGroupName
        $licenseBody = $licenseBody.Replace($fieldGroup.Value, $value)
    }

Set-Content -Path $licensePath -Value $licenseBody
