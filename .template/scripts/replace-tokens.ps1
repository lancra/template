<#
.SYNOPSIS
Replaces template tokens in a file's content and name.

.DESCRIPTION
Reads the content of each applicable file, iterating through each line. Using a
regular expression, all tokens are replaced with the value specified in the
source specification. The modified lines are then written back to the target
file. Finally, the file name itself is checked for tokens, and if found, they
are replaced and the file is renamed.

.PARAMETER Source
The source template specification to replace tokens with.

.PARAMETER File
The file(s) to modify. If this is not provided, all files in the latest commit
are used.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Source,

    [Parameter()]
    [string[]] $File
)

if (-not (Test-Path -Path $Source)) {
    throw "The token specification was not found at '$Source'."
}

if ($File.Length -eq 0) {
    $File = @(& git show --pretty="" --name-only)
}

$tokenSpecification = Get-Content -Path $Source |
    ConvertFrom-Json |
    Select-Object -ExpandProperty tokens

$tokenValues = @{}
$tokenSpecification.PSObject.Properties |
    ForEach-Object {
        $tokenValues["__$($_.Name)__"] = $_.Value.value
    }

function Set-Tokens {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Text
    )
    begin {
        $tokenPattern = '__(?=[A-Z])[A-Z_]+__'
        $indexDifference = 0
    }
    process {
        $newText = $Text
        $Text |
            Select-String -AllMatches -Pattern $tokenPattern |
            Select-Object -ExpandProperty Matches |
            ForEach-Object {
                if (-not $tokenValues.ContainsKey($_.Value)) {
                    Write-Warning "No specification found for token '$($_.Value)'."
                    return
                }

                $prefix = $newText.Substring(0, $_.Index + $indexDifference)
                $tokenValue = $tokenValues[$_.Value]
                $suffix = $newText.Substring($_.Index + $indexDifference + $_.Length)

                $newText = "$prefix$tokenValue$suffix"
                $indexDifference += ($tokenValue.Length - $_.Value.Length)
            }

        $newText
    }
}

$tokenPattern = '__(?=[A-Z])[A-Z_]+__'
$File |
    ForEach-Object {
        $lines = Get-Content -Path $_ |
            ForEach-Object {
                Set-Tokens -Text $_
            }

        Set-Content -Path $_ -Value $lines

        $newPath = Set-Tokens -Text $_
        if ($newPath -ne $_) {
            Move-Item -Path $_ -Destination $newPath
        }
    }
