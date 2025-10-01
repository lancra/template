<#
.SYNOPSIS
Replaces template tokens in a file's content and name.

.DESCRIPTION
Reads the content of each applicable file, iterating through each line. Using a
regular expression, all tokens are replaced with the value specified in the
source specification. The modified lines are then written back to the target
file. Finally, the file name itself is checked for tokens, and if found, they
are replaced and the file is renamed.

.PARAMETER Specification
The source template specification to replace tokens with.

.PARAMETER File
The file(s) to modify. If this is not provided, all files in the latest commit
are used.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Specification,

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

class TokenMatchFile {
    [string] $Path
    [TokenMatch[]] $Tokens

    TokenMatchFile([string] $path, [TokenMatch[]] $tokens) {
        $this.Path = $path
        $this.Tokens = $tokens
    }
}

class TokenMatch {
    [int] $LineNumber
    [string] $Token
    [int] $StartIndex
    [int] $EndIndex

    TokenMatch([int] $lineNumber, [string] $token, [int] $startIndex, [int] $endIndex) {
        $this.LineNumber = $lineNumber
        $this.Token = $token
        $this.StartIndex = $startIndex
        $this.EndIndex = $endIndex
    }
}

class TokenReplacementResult {
    [string] $Text
    [int] $IndexOffset

    TokenReplacementResult([string] $text, [int] $indexOffset) {
        $this.Text = $text
        $this.IndexOffset = $indexOffset
    }
}

if ($File.Length -eq 0) {
    $File = @(& git diff --name-only --staged)
}

if (-not (Test-Path -Path $Specification)) {
    throw "The template specification was not found at '$Specification'."
}

$specificationInstance = Get-Content -Path $Specification |
    ConvertFrom-Json

$tokenResults = @{}

$specificationInstance.tokens.PSObject.Properties |
    ForEach-Object {
        $kind = [TokenKind]$_.Value.kind
        $text = $kind -eq [TokenKind]::Static ? $_.Value.value : $_.Value.generator
        $result = [TokenResult]::new($text, $kind)
        $tokenResults["__$($_.Name)__"] = $result
    }

$tokenPattern = '__[^\W_]\w*?__'

function Set-Token {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Text,

        [Parameter(Mandatory)]
        [TokenMatch] $TokenMatch,

        [Parameter()]
        [int] $IndexOffset = 0
    )
    process {
        if (-not $tokenResults.ContainsKey($TokenMatch.Token)) {
            Write-Warning "No specification found for token '$($_.Token)'."
            return
        }

        $startIndex = $TokenMatch.StartIndex + $IndexOffset
        $endIndex = $TokenMatch.EndIndex + $IndexOffset

        $prefix = $startIndex -ne 0 ? $Text.Substring(0, $startIndex) : ''
        $tokenValue = $tokenResults[$TokenMatch.Token].GetValue($MatchFile.Path, $Text, $TokenMatch.LineNumber)
        $suffix = $endIndex -ne $Text.Length ? $Text.Substring($endIndex, $Text.Length - $endIndex) : ''

        $newText = $prefix + $tokenValue + $suffix
        $newIndexOffset = $IndexOffset + $tokenValue.Length - $TokenMatch.Token.Length

        return [TokenReplacementResult]::new($newText, $newIndexOffset)
    }
}

function Set-FileToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [TokenMatchFile] $MatchFile
    )
    process {
        $lines = @(Get-Content -Path $MatchFile.Path)
        $replacementIndexOffsets = [int[]]::new($lines.Length)

        $MatchFile |
            Select-Object -ExpandProperty Tokens |
            ForEach-Object {
                $lineIndex = $_.LineNumber - 1
                $line = $lines[$lineIndex]
                $replacementIndexOffset = $replacementIndexOffsets[$lineIndex]

                $result = Set-Token -Text $line -TokenMatch $_ -IndexOffset $replacementIndexOffset

                $lines[$lineIndex] = $result.Text
                $replacementIndexOffsets[$lineIndex] = $replacementIndexOffset + $result.IndexOffset
            }

        $lines |
            Set-Content -Path $MatchFile.Path
    }
}

$tokenMatchFiles = rg --json $tokenPattern $File |
    ForEach-Object { $_ | ConvertFrom-Json } |
    Where-Object -Property 'type' -EQ 'match' |
    Select-Object -ExpandProperty 'data' |
    ForEach-Object {
        $lineMatch = $_
        $_.submatches |
            ForEach-Object {
                [pscustomobject]@{
                    Path = $lineMatch.path.text
                    LineNumber = $lineMatch.line_number
                    Token = $_.match.text
                    StartIndex = $_.start
                    EndIndex = $_.end
                }
            }
    } |
    Sort-Object -Property Path, LineNumber, StartIndex |
    Group-Object -Property Path |
    ForEach-Object {
        $tokens = $_ |
            Select-Object -ExpandProperty Group |
            ForEach-Object {
                [TokenMatch]::new($_.LineNumber, $_.Token, $_.StartIndex, $_.EndIndex)
            }

        [TokenMatchFile]::new($_.Name, $tokens)
    }

$File |
    ForEach-Object {
        $tokenMatchFile = $tokenMatchFiles |
            Where-Object -Property Path -EQ $_
        if ($tokenMatchFile) {
            Set-FileToken -MatchFile $tokenMatchFile
        }

        $pathMatch = $_ |
            Select-String -Pattern $tokenPattern |
            Select-Object -ExpandProperty Matches
        if ($pathMatch) {
            $pathTokenMatch = [TokenMatch]::new(0, $pathMatch.Value, $pathMatch.Index, $pathMatch.Index + $pathMatch.Length)
            $pathResult = Set-Token -Text $_ -TokenMatch $pathTokenMatch
            Move-Item -Path $_ -Destination $pathResult.Text
        }
    }
