<#
.SYNOPSIS
Replaces template tokens in a file's content and name.

.DESCRIPTION
Reads the content of each applicable file, iterating through each line. Using a
regular expression, all tokens are replaced with the value specified in the
source specification. The modified lines are then written back to the target
file. Finally, the file name itself is checked for tokens, and if found, they
are replaced and the file is renamed.

.PARAMETER TokenPath
The source template specification to replace tokens with.

.PARAMETER File
The file(s) to modify. If this is not provided, all files in the latest commit
are used.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $TokenPath,

    [Parameter()]
    [string[]] $File
)

enum TokenType {
    Generated
    Static
}

class TokenResult {
    [string] $Text
    [TokenType] $Type

    TokenResult([string] $text, [TokenType] $type) {
        $this.Text = $text
        $this.Type = $type
    }

    [string] GetValue([string] $path, [string] $text, [int] $line) {
        if ($this.Type -eq [TokenType]::Generated) {
            $value = & "$PSScriptRoot/$($this.Text)" -Path $path -Text $text -Line $line
            return $value
        }

        if ($this.Type -eq [TokenType]::Static) {
            return $this.Text
        }

        throw "Unknown token type $($this.Type)."
    }
}

if ($File.Length -eq 0) {
    $File = @(& git show --pretty="" --name-only)
}

if (-not (Test-Path -Path $TokenPath)) {
    throw "The token specification was not found at '$TokenPath'."
}

$tokenSpecification = Get-Content -Path $TokenPath |
    ConvertFrom-Json

$tokenResults = @{}

$tokenSpecification.generated.PSObject.Properties |
    ForEach-Object {
        $result = [TokenResult]::new($_.Value.generator, [TokenType]::Generated)
        $tokenResults["__$($_.Name)__"] = $result
    }

$tokenSpecification.static.PSObject.Properties |
    ForEach-Object {
        $result = [TokenResult]::new($_.Value.value, [TokenType]::Static)
        $tokenResults["__$($_.Name)__"] = $result
    }

$tokenPattern = '__(?=[A-Z])[A-Z_].*(?<!_)__'

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
