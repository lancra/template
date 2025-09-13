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

class TokenResult {
    [string] $Text

    TokenResult([string] $text) {
        $this.Text = $text
    }

    [string] GetValue([string] $path, [string] $text, [int] $line) {
        return $this.Text
    }
}

if ($File.Length -eq 0) {
    $File = @(& git show --pretty="" --name-only)
}

if (-not (Test-Path -Path $Source)) {
    throw "The token specification was not found at '$Source'."
}

$tokenSpecification = Get-Content -Path $Source |
    ConvertFrom-Json

$tokenResults = @{}


$tokenSpecification.tokens.PSObject.Properties |
    ForEach-Object {
        $result = [TokenResult]::new($_.Value.value)
        $tokenResults["__$($_.Name)__"] = $result
    }

function Set-Tokens {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [string] $Text,

        [Parameter()]
        [int] $Line
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
                if (-not $tokenResults.ContainsKey($_.Value)) {
                    Write-Warning "No specification found for token '$($_.Value)'."
                    return
                }

                $prefix = $newText.Substring(0, $_.Index + $indexDifference)
                $tokenValue = $tokenResults[$_.Value].GetValue($Path, $Text, $Line)
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
        $path = $_
        $lineNumber = 0

        $lines = Get-Content -Path $path |
            ForEach-Object {
                $lineNumber++
                Set-Tokens -Path $path -Text $_ -Line $lineNumber
            }

        Set-Content -Path $path -Value $lines

        $newPath = Set-Tokens -Path $path -Text $path
        if ($newPath -ne $path) {
            Move-Item -Path $_ -Destination $newPath
        }
    }
