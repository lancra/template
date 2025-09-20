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

enum TokenKind {
    Generated
    Static
}

class TokenResult {
    [string] $Text
    [TokenKind] $Kind

    TokenResult([string] $text, [TokenKind] $kind) {
        $this.Text = $text
        $this.Kind = $kind
    }

    [string] GetValue([string] $path, [string] $text, [int] $line) {
        if ($this.Kind -eq [TokenKind]::Generated) {
            $value = & "$PSScriptRoot/$($this.Text)" -Path $path -Text $text -Line $line
            return $value
        }

        if ($this.Kind -eq [TokenKind]::Static) {
            return $this.Text
        }

        throw "Unknown token kind $($this.Kind)."
    }
}

if ($File.Length -eq 0) {
    $File = @(& git diff --name-only --staged)
}

if (-not (Test-Path -Path $TokenPath)) {
    throw "The token specification was not found at '$TokenPath'."
}

$tokenSpecification = Get-Content -Path $TokenPath |
    ConvertFrom-Json

$tokenResults = @{}

$tokenSpecification.tokens.PSObject.Properties |
    ForEach-Object {
        $kind = [TokenKind]$_.Value.kind
        $text = $kind -eq [TokenKind]::Static ? $_.Value.value : $_.Value.generator
        $result = [TokenResult]::new($text, $kind)
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
